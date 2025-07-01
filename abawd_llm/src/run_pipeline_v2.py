# src/run_pipeline.py
# ------------------------------------------------------------
"""
Parse ABAWD waiver PDFs → tidy CSV using a local Ollama‑served Llama 3.x model.

Pipeline
    1. Extract text (or OCR) from each page – see extract_pages.py.
    2. Harvest candidate place‑names via regex → *candidates* list.
       (Now case‑insensitive and robust to ALL‑CAPS.)
    3. Build **one** prompt (prompt.txt) per PDF that embeds *all* pages and the
       candidate list.
       – If the list is empty we prepend instructions that the model may fall
         back to extracting names directly from the waiver text.
    4. POST that prompt to Ollama /api/generate.
    5. Validate / repair JSON, infer missing loc_type, sanitise.
    6. Assemble rows → DataFrame → CSV (dates forward‑filled).

Assumptions
    • PDF filenames start with "<YEAR>_<STATE_ABBR>" – anything after the second
      underscore is treated as part of the doc name.
    • Environment variables:
          WAIVER_ROOT   → folder containing year sub‑folders of PDFs
          DOWNLOADS_DIR → where the CSV + debug prompts are written
          MODEL         → Ollama model name (default "llama3.2")

Usage
    python run_pipeline.py                # walk entire WAIVER_ROOT
    python run_pipeline.py --one path.pdf # process a single file only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import List, Sequence

import pandas as pd
import requests
from dotenv import load_dotenv

from extract_pages import page_texts  # local helper – handles OCR fall‑back

# ─────────────────────────── CLI ────────────────────────────
ap = argparse.ArgumentParser()
ap.add_argument(
    "--one", metavar="PDF", help="Run on a single PDF (for a dry‑run/debug)"
)
args = ap.parse_args()

# ──────────────────────── ENV / paths ───────────────────────
load_dotenv()
ROOT = Path(os.getenv("WAIVER_ROOT", "")).expanduser()
OUT_DIR = Path(os.path.expandvars(os.getenv("DOWNLOADS_DIR", "./outputs")))
MODEL = os.getenv("MODEL", "llama3.2")

if not ROOT.exists():
    sys.exit(f"❌ WAIVER_ROOT not found: {ROOT}")

SCRIPT_DIR = Path(__file__).resolve().parent
state_lut: dict[str, str] = json.loads((SCRIPT_DIR / "state_lookup.json").read_text())
prompt_raw: str = (SCRIPT_DIR / "prompt.txt").read_text()

OUT_DIR.mkdir(parents=True, exist_ok=True)

# ─────────────────── regex patterns for candidates ──────────
# The patterns below are case‑insensitive (re.I) so they match both Title‑Case
# and ALL‑CAPS.  City / Town patterns require *two* words before the designator
# to avoid false hits like "Individual City".
county_pat = re.compile(r"\b([A-Za-z][A-Za-z\s]+? County)\b", re.I)
reservation_pat = re.compile(r"\b([A-Za-z][A-Za-z\s]+? (?:Nation|Reservation))\b", re.I)
city_pat = re.compile(r"\b([A-Za-z]+\s+[A-Za-z]+\s+City)\b", re.I)
town_pat = re.compile(r"\b([A-Za-z]+\s+[A-Za-z]+\s+Town)\b", re.I)

# pattern to drop obvious aggregates or junk
agg_pat = re.compile(r"^(?:\d+|one)\s+(county|counties|city|cities|reservation|areas?)$", re.I)

# ───────────────────── prompt + LLM helpers ─────────────────

def prompt_for(
    doc_text: str,
    year: int,
    st_abbr: str,
    doc: str,
    candidates: Sequence[str],
) -> str:
    """Fill the Jinja‑style prompt template."""
    block = json.dumps(sorted(candidates), ensure_ascii=False)
    return (
        prompt_raw.replace("{{year}}", str(year))
        .replace("{{state_abbr}}", st_abbr)
        .replace("{{state_full}}", state_lut[st_abbr])
        .replace("{{doc_name}}", doc)
        .replace("{{JSON_ENCODED_LIST_OF_NAMES}}", block)
        .replace("{{page_text}}", doc_text)
    )


def query_llm(prompt: str) -> list[dict]:
    """Call Ollama and return the parsed JSON response."""
    r = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": MODEL,
            "format": "json",
            "stream": False,
            "prompt": prompt,
            "temperature": 0,
        },
        timeout=180,
    )
    r.raise_for_status()
    return json.loads(r.json()["response"])


# ─────────────────── JSON normalisation helpers ─────────────

def infer_type(name: str) -> str:
    n = name.lower()
    if n.endswith(" county"):
        return "county"
    if n.endswith(" city"):
        return "city"
    if n.endswith(" town"):
        return "town"
    if "reservation" in n or "nation" in n:
        return "reservation"
    return "other"


def fix_if_needed(raw):
    """Sanitise / repair the model output so downstream code is safe."""
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        raise ValueError("Model output not a list or dict")

    for itm in raw:
        # ensure required keys exist
        itm.setdefault("entire_state", 0)
        itm.setdefault("loc", [])
        itm.setdefault("loc_type", [])

        # normalise to list type
        if not isinstance(itm["loc"], list):
            itm["loc"] = [itm["loc"]]
        if not isinstance(itm["loc_type"], list):
            itm["loc_type"] = [itm["loc_type"]]

        locs = itm["loc"]
        types = itm["loc_type"]

        # ── strip & drop empties ───────────────────────────
        locs = [str(x).strip() for x in locs if str(x).strip()]
        types = [str(t).strip() for t in types if str(t).strip()]

        # ── auto‑fill / trim loc_type -----------------------
        if len(types) < len(locs):
            for name in locs[len(types):]:
                types.append(infer_type(name))
        elif len(types) > len(locs):
            types[:] = types[: len(locs)]

        # ── write back & final sanity check ────────────────
        itm["loc"] = locs
        itm["loc_type"] = types
        if len(locs) != len(types):
            raise ValueError("loc/loc_type length mismatch after sanitising")

    return raw


# ────────────────────────── MAIN ────────────────────────────
HEADERS = [
    "YEAR",
    "STATE",
    "STATE_ABBREV",
    "ENTIRE_STATE",
    "LOC",
    "LOC_TYPE",
    "DATE_START",
    "DATE_END",
    "SOURCE_DOC",
]
rows: List[List[str]] = []

pdf_iter = [Path(args.one)] if args.one else ROOT.rglob("*.pdf")

for pdf in pdf_iter:
    parts = pdf.stem.split("_", 2)  # max 3 parts to keep the rest as doc name
    if len(parts) < 2:
        print(f"⚠️  Unexpected filename format: {pdf.name}", file=sys.stderr)
        continue
    year, st_abbr = int(parts[0]), parts[1].upper()

    # ── 1. text extraction ────────────────────────────────
    page_texts_list = page_texts(pdf)  # OCR happens inside if needed
    doc_text = "\n\n".join(f"[PAGE {i+1}]\n{txt}" for i, txt in enumerate(page_texts_list))

    # ── 2. candidate harvest (case‑insensitive) ───────────
    cands: set[str] = set()
    for pat in (county_pat, reservation_pat, city_pat, town_pat):
        for match in pat.findall(doc_text):
            # Normalise to Title‑Case while preserving inner caps (e.g. "Gila River")
            cands.add(" ".join(word.capitalize() for word in match.split()))

    if not cands:
        print(f"⚠️  No candidates harvested for {pdf.stem}", file=sys.stderr)

    # ── 3. build + save prompt ────────────────────────────
    prompt_intro = ""
    if not cands:
        prompt_intro = (
            "NOTE: The list of candidate place names is empty or may be incomplete. "
            "You may extract place names directly from the waiver text.\n\n"
        )

    prompt = prompt_intro + prompt_for(doc_text, year, st_abbr, pdf.stem, sorted(cands))
    (OUT_DIR / f"{pdf.stem}_prompt.txt").write_text(prompt)

    # ── 4. LLM call with one retry ────────────────────────
    for attempt in range(2):
        try:
            raw = query_llm(prompt)
            data = fix_if_needed(raw)
            break
        except (ValueError, json.JSONDecodeError) as e:
            if attempt == 1:
                raise
            prompt = (
                "Your previous answer was invalid (" + str(e) + "). "
                "Return a corrected JSON array ONLY.\n" + prompt
            )

    # ── 5. assemble rows ─────────────────────────────────
    for item in data:
        d_start = item.get("date_start")
        d_end = item.get("date_end")

        if item.get("entire_state", 0):
            rows.append(
                [year, state_lut[st_abbr], st_abbr, 1, "", "", d_start, d_end, pdf.stem]
            )
            continue

        for loc, ltype in zip(item["loc"], item["loc_type"]):
            loc_lower = loc.lower()
            if agg_pat.match(loc_lower) or loc_lower in {"page", state_lut[st_abbr].lower()}:
                continue  # skip aggregates or false positives
            rows.append(
                [
                    year,
                    state_lut[st_abbr],
                    st_abbr,
                    0,
                    loc,
                    ltype,
                    d_start,
                    d_end,
                    pdf.stem,
                ]
            )

# ──────────────────── 6. write CSV ─────────────────────────
if not rows:
    sys.exit("No rows produced – nothing to save.")

