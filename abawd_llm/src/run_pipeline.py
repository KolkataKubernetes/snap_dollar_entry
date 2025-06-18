# src/run_pipeline.py
# ------------------------------------------------------------
"""
Parse ABAWD waiver PDFs → CSV using a local Ollama LLM.

• Extract page text  (pdfplumber + Tesseract OCR at high DPI)
• Build a prompt that includes a CANDIDATES list of all place names
  found by regex on that page’s text
• Call Ollama (/api/generate) with the prompt
• Validate / retry once if JSON is malformed
• Collect rows, de-duplicate, forward-fill dates
"""

import argparse, json, os, re, requests
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd
from extract_pages import page_texts   # your OCR helper

# ── CLI ──────────────────────────────────────────────────────
ap = argparse.ArgumentParser()
ap.add_argument("--one", help="Path to a single PDF for a dry-run", default=None)
args = ap.parse_args()

# ── ENV / paths ──────────────────────────────────────────────
load_dotenv()
ROOT     = Path(os.getenv("WAIVER_ROOT"))                   # year folders
OUT_DIR  = Path(os.path.expandvars(os.getenv("DOWNLOADS_DIR")))
MODEL    = os.getenv("MODEL", "llama3.2")

if not ROOT.exists():
    raise RuntimeError(f"WAIVER_ROOT not found: {ROOT}")

state_lut   = json.loads((Path(__file__).parent / "state_lookup.json").read_text())
prompt_raw  = (Path(__file__).parent / "prompt.txt").read_text()

# ── Regex helpers for candidate harvesting ──────────────────
county_pat      = re.compile(r"\b([A-Z][a-z]+ County)\b")
reservation_pat = re.compile(r"\b([A-Z][a-z]+ (?:Nation|Reservation))\b")
city_pat        = re.compile(r"\b([A-Z][a-z]+ City)\b")
town_pat        = re.compile(r"\b([A-Z][a-z]+ Town)\b")

agg_pat = re.compile(r"^(?:\d+|one)\s+(county|counties|city|cities|reservation|areas?)$", re.I)

# ── Prompt + LLM helpers ────────────────────────────────────
def prompt_for(page_txt, year, st_abbr, doc, candidates):
    """Fill the template with context vars and a JSON-encoded CANDIDATES list."""
    candidate_block = json.dumps(sorted(candidates), ensure_ascii=False)
    return (prompt_raw
            .replace("{{year}}", str(year))
            .replace("{{state_abbr}}", st_abbr)
            .replace("{{state_full}}", state_lut[st_abbr])
            .replace("{{doc_name}}", doc)
            .replace("{{JSON_ENCODED_LIST_OF_NAMES}}", candidate_block)
            .replace("{{page_text}}", page_txt))

def query_llm(prompt):
    r = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": MODEL,
            "format": "json",
            "stream": False,
            "prompt": prompt,
            "temperature": 0
        },
        timeout=180
    )
    return json.loads(r.json()["response"])

# --- helper to infer a loc_type from the name ----------------
def infer_type(name: str) -> str:
    n = name.lower()
    if n.endswith(" county"):
        return "county"
    if n.endswith(" city") or ", az" in n or ", ar" in n:   # tweak if needed
        return "city"
    if n.endswith(" town"):
        return "town"
    if "reservation" in n or "nation" in n:
        return "reservation"
    return "other"

# --- patched fix_if_needed ----------------------------------
def fix_if_needed(raw):
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        raise ValueError("Model output not a list")

    for itm in raw:
        locs, types = itm["loc"], itm["loc_type"]
        if len(types) < len(locs):
            # auto-fill the missing types by inference
            for name in locs[len(types):]:
                types.append(infer_type(name))
        if len(locs) != len(types):
            raise ValueError("loc/loc_type length mismatch after autofill")
    return raw

# ── Output table init ───────────────────────────────────────
HEADERS = ["YEAR","STATE","STATE_ABBREV","ENTIRE_STATE",
           "LOC","LOC_TYPE","DATE_START","DATE_END","SOURCE_DOC"]
rows = []

# ── Main loop ────────────────────────────────────────────────
pdf_iter = [Path(args.one)] if args.one else ROOT.rglob("*.pdf")

for pdf in pdf_iter:
    year, st_abbr, *_ = pdf.stem.split("_")
    year, st_abbr = int(year), st_abbr.upper()

    for pg_idx, page_txt in enumerate(page_texts(pdf), 1):
        # Harvest candidate names from *this* page
        candidates = set(county_pat.findall(page_txt) +
                         reservation_pat.findall(page_txt) +
                         city_pat.findall(page_txt) +
                         town_pat.findall(page_txt))

        base_prompt = prompt_for(page_txt, year, st_abbr, pdf.stem, candidates)

        # Optional: save prompt for debugging
        # (Path(OUT_DIR)/f"{pdf.stem}_page_{pg_idx:02d}_prompt.txt").write_text(base_prompt)

        # Retry loop (2 attempts)
        for attempt in range(2):
            try:
                data = fix_if_needed(query_llm(base_prompt))
                break
            except ValueError as e:
                if attempt == 1:
                    raise
                base_prompt = ("Your previous answer was invalid "
                               f"({e}). Return a corrected JSON array ONLY.\n"
                               + base_prompt)

        # Row assembly
        for item in data:
            if item["entire_state"]:
                rows.append([year, state_lut[st_abbr], st_abbr, 1,
                             "", "", item["date_start"], item["date_end"], pdf.stem])
                continue

            for loc, ltype in zip(item["loc"], item["loc_type"]):
                if agg_pat.match(loc.lower()) or loc.lower() in {"arizona", "page"}:
                    continue  # skip aggregates & headers
                rows.append([year, state_lut[st_abbr], st_abbr, 0,
                             loc, ltype, item["date_start"], item["date_end"], pdf.stem])

# ── Save CSV ─────────────────────────────────────────────────
out_path = OUT_DIR / "ABAWD_waivers_extracted.csv"
out_path.parent.mkdir(parents=True, exist_ok=True)

df = pd.DataFrame(rows, columns=HEADERS)
df = df.drop_duplicates(subset=["YEAR","STATE_ABBREV","LOC","DATE_START","DATE_END"])
df[["DATE_START","DATE_END"]] = df.groupby("SOURCE_DOC")[["DATE_START","DATE_END"]].ffill()
df.to_csv(out_path, index=False)
print(f"✅  Process complete – saved to {out_path}")
