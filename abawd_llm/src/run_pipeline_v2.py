# src/run_pipeline.py
# ------------------------------------------------------------
"""
Extract geography rows from ABAWD waiver PDFs using a table‑first OCR
pipeline + Llama 3.x (Ollama).

Key upgrades in this version
----------------------------
* Uses the **hybrid table extractor** in extract_pages.py (vector → OCR →
  fallback text) so every waiver format is covered.
* Builds **one prompt per PDF** with the new prompt.txt that supports
  header‑based loc_type inference and ignores BAD_TOKENS artefacts.
* Case‑insensitive, two‑word regexes harvest a robust candidate list.

Environment variables
---------------------
    WAIVER_ROOT   – root folder containing year sub‑folders of PDFs
    DOWNLOADS_DIR – where CSV + debug prompts are written (default ./outputs)
    MODEL         – Ollama model name (default "llama3.2")

Usage
-----
    python run_pipeline.py                # walk WAIVER_ROOT recursively
    python run_pipeline.py --one path.pdf # run a single PDF
"""
from __future__ import annotations

import argparse, json, os, re, sys
from pathlib import Path
from typing import List, Sequence

import pandas as pd
import requests
from dotenv import load_dotenv

from extract_pages import page_texts  # ← hybrid extractor

# ─────────────────────────── CLI ────────────────────────────
ap = argparse.ArgumentParser()
ap.add_argument("--one", metavar="PDF", help="Run on a single PDF only")
args = ap.parse_args()

# ─────────────────────── ENV / paths ────────────────────────
load_dotenv()
ROOT     = Path(os.getenv("WAIVER_ROOT", "")).expanduser()
OUT_DIR  = Path(os.path.expandvars(os.getenv("DOWNLOADS_DIR", "./outputs")))
MODEL    = os.getenv("MODEL", "llama3.2")

if not ROOT.exists():
    sys.exit(f"❌ WAIVER_ROOT not found: {ROOT}")

SCRIPT_DIR = Path(__file__).resolve().parent
state_lut   = json.loads((SCRIPT_DIR / "state_lookup.json").read_text())
prompt_raw  = (SCRIPT_DIR / "prompt.txt").read_text()
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ───────────────────── regex helpers ─────────────────────────
county_pat      = re.compile(r"\b([A-Za-z][A-Za-z\s]+? County)\b", re.I)
reservation_pat = re.compile(r"\b([A-Za-z][A-Za-z\s]+? (?:Nation|Reservation))\b", re.I)
city_pat        = re.compile(r"\b([A-Za-z]+\s+[A-Za-z]+\s+City)\b", re.I)  # two‑word City
town_pat        = re.compile(r"\b([A-Za-z]+\s+[A-Za-z]+\s+Town)\b", re.I)  # two‑word Town

agg_pat = re.compile(r"^(?:\d+|one)\s+(county|counties|city|cities|reservation|areas?)$", re.I)

# ────────────────── prompt + LLM helpers ─────────────────────

def prompt_for(doc_text: str, year: int, st: str, doc: str, candidates: Sequence[str]) -> str:
    block = json.dumps(sorted(candidates), ensure_ascii=False)
    return (
        prompt_raw
        .replace("{{year}}", str(year))
        .replace("{{state_abbr}}", st)
        .replace("{{state_full}}", state_lut[st])
        .replace("{{doc_name}}", doc)
        .replace("{{JSON_ENCODED_LIST_OF_NAMES}}", block)
        .replace("{{page_text}}", doc_text)
    )


def query_llm(prompt: str) -> list[dict]:
    r = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": MODEL, "format": "json", "stream": False, "prompt": prompt, "temperature": 0},
        timeout=180,
    )
    r.raise_for_status()
    return json.loads(r.json()["response"])

# ─────────────── sanitise / repair helpers ───────────────────

def infer_type(name: str) -> str:
    n = name.lower()
    if n.endswith(" county"): return "county"
    if n.endswith(" city"):   return "city"
    if n.endswith(" town"):   return "town"
    if "reservation" in n or "nation" in n: return "reservation"
    return "other"


def fix_if_needed(raw):
    if isinstance(raw, dict): raw = [raw]
    if not isinstance(raw, list):
        raise ValueError("Model output not a list/dict")
    for itm in raw:
        itm.setdefault("entire_state", 0)
        itm.setdefault("loc", [])
        itm.setdefault("loc_type", [])
        if not isinstance(itm["loc"], list): itm["loc"] = [itm["loc"]]
        if not isinstance(itm["loc_type"], list): itm["loc_type"] = [itm["loc_type"]]
        locs  = [str(x).strip() for x in itm["loc"] if str(x).strip()]
        types = [str(t).strip() for t in itm["loc_type"] if str(t).strip()]
        if len(types) < len(locs):
            types.extend(infer_type(n) for n in locs[len(types):])
        elif len(types) > len(locs):
            types[:] = types[:len(locs)]
        itm["loc"], itm["loc_type"] = locs, types
        if len(locs) != len(types):
            raise ValueError("loc/loc_type length mismatch")
    return raw

# ───────────────────────── main ──────────────────────────────
HEADERS = ["YEAR","STATE","STATE_ABBREV","ENTIRE_STATE","LOC","LOC_TYPE","DATE_START","DATE_END","SOURCE_DOC"]
rows: List[List[str]] = []

pdf_iter = [Path(args.one)] if args.one else ROOT.rglob("*.pdf")

for pdf in pdf_iter:
    parts = pdf.stem.split("_", 2)
    if len(parts) < 2:
        print(f"⚠️  Unexpected filename: {pdf.name}", file=sys.stderr)
        continue
    year, st = int(parts[0]), parts[1].upper()

    # 1. extract waiver text (table‑first)
    page_strs = page_texts(pdf)
    doc_text  = "\n\n".join(f"[PAGE {i+1}]\n{t}" for i, t in enumerate(page_strs))

    # 2. harvest candidate names
    cands: set[str] = set()
    for pat in (county_pat, reservation_pat, city_pat, town_pat):
        for m in pat.findall(doc_text):
            cands.add(" ".join(w.capitalize() for w in m.split()))
    if not cands:
        print(f"⚠️  No candidates harvested for {pdf.stem}", file=sys.stderr)

    # 3. build + save prompt
    prefix = ""
    if not cands:
        prefix = (
            "NOTE: The list of candidate place names is empty or may be incomplete. "
            "You may extract place names directly from the waiver text.\n\n"
        )
    prompt = prefix + prompt_for(doc_text, year, st, pdf.stem, sorted(cands))
    (OUT_DIR / f"{pdf.stem}_prompt.txt").write_text(prompt)

    # 4. call LLM (retry once on bad JSON)
    for attempt in range(2):
        try:
            data = fix_if_needed(query_llm(prompt))
            break
        except (ValueError, json.JSONDecodeError) as e:
            if attempt == 1: raise
            prompt = ("Your previous answer was invalid (" + str(e) + "). "
                      "Return a corrected JSON array ONLY.\n" + prompt)

    # 5. build rows
    for itm in data:
        d_start, d_end = itm.get("date_start"), itm.get("date_end")
        if itm.get("entire_state", 0):
            rows.append([year, state_lut[st], st, 1, "", "", d_start, d_end, pdf.stem])
            continue
        for loc, ltype in zip(itm["loc"], itm["loc_type"]):
            loc_l = loc.lower()
            if agg_pat.match(loc_l) or loc_l in {"page", state_lut[st].lower()}:
                continue
            rows.append([year, state_lut[st], st, 0, loc, ltype, d_start, d_end, pdf.stem])

# 6. save CSV
if not rows:
    sys.exit("No rows produced – nothing to save.")

df = pd.DataFrame(rows, columns=HEADERS)
df = df.drop_duplicates(subset=["YEAR","STATE_ABBREV","LOC","DATE_START","DATE_END"])
df[["DATE_START","DATE_END"]] = df.groupby("SOURCE_DOC")[["DATE_START","DATE_END"]].ffill()

out_path = OUT_DIR / "ABAWD_waivers_extracted.csv"
df.to_csv(out_path, index=False)
print(f"✅  Process complete – saved to {out_path}")
