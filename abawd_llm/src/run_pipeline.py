# src/run_pipeline.py
# ------------------------------------------------------------
"""
Parse ABAWD waiver PDFs → CSV using local Llama-3.2 via Ollama.
"""

import argparse, json, os, re, requests
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd
from extract_pages import page_texts

# ── CLI ──────────────────────────────────────────────────────
ap = argparse.ArgumentParser()
ap.add_argument("--one", help="Path to a single PDF for a dry-run", default=None)
args = ap.parse_args()

# ── ENV / paths ──────────────────────────────────────────────
load_dotenv()
ROOT     = Path(os.getenv("WAIVER_ROOT"))                   # where PDFs live
OUT_DIR  = Path(os.path.expandvars(os.getenv("DOWNLOADS_DIR")))
MODEL    = os.getenv("MODEL", "llama3.2")

if not ROOT.exists():
    raise RuntimeError(f"WAIVER_ROOT not found: {ROOT}")

state_lut   = json.loads((Path(__file__).parent / "state_lookup.json").read_text())
prompt_raw  = (Path(__file__).parent / "prompt.txt").read_text()

HEADERS = ["YEAR","STATE","STATE_ABBREV","ENTIRE_STATE",
           "LOC","LOC_TYPE","DATE_START","DATE_END","SOURCE_DOC"]
rows = []

# ── helpers ──────────────────────────────────────────────────
def prompt_for(page_txt, year, st_abbr, doc):
    return (prompt_raw
            .replace("{{year}}", str(year))
            .replace("{{state_abbr}}", st_abbr)
            .replace("{{state_full}}", state_lut[st_abbr])
            .replace("{{doc_name}}", doc)
            .replace("{{page_text}}", page_txt))

def query_llm(prompt):
    r = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": MODEL, "format": "json",
              "stream": False, "prompt": prompt, "temperature": 0},
        timeout=180
    )
    return json.loads(r.json()["response"])

def fix_if_needed(raw):
    """Ensure we have a list of dicts and matching loc / loc_type lengths."""
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        raise ValueError("Model output not a list")
    for itm in raw:
        if len(itm["loc"]) != len(itm["loc_type"]):
            raise ValueError("loc/loc_type length mismatch")
    return raw

agg_pat = re.compile(r"^(?:\d+|one)\s+(county|counties|city|cities|reservation|areas?)$", re.I)

# ── main loop ────────────────────────────────────────────────
pdf_iter = [Path(args.one)] if args.one else ROOT.rglob("*.pdf")

for pdf in pdf_iter:
    year, st_abbr, *_ = pdf.stem.split("_")
    year, st_abbr = int(year), st_abbr.upper()

    for i, page in enumerate(page_texts(pdf)):
        base_prompt = prompt_for(page, year, st_abbr, pdf.stem)
        prompt_path = OUT_DIR / f"{pdf.stem}_page_{i+1:02d}_prompt.txt"
        with open(prompt_path, "w") as f:
            f.write(base_prompt)


        # 2-attempt retry loop
        for attempt in range(2):
            try:
                data = fix_if_needed(query_llm(base_prompt))
                break
            except ValueError as e:
                if attempt == 1:
                    raise
                base_prompt = f"Your previous answer was invalid ({e}). " \
                              "Return a corrected JSON array ONLY.\n" + base_prompt

        for item in data:
            if item["entire_state"]:
                rows.append([year, state_lut[st_abbr], st_abbr, 1,
                             "", "", item["date_start"], item["date_end"], pdf.stem])
                continue

            for loc, ltype in zip(item["loc"], item["loc_type"]):
                if agg_pat.match(loc.lower()):
                    continue          # skip "12 counties" etc.
                rows.append([year, state_lut[st_abbr], st_abbr, 0,
                             loc, ltype, item["date_start"], item["date_end"], pdf.stem])

# ── save ─────────────────────────────────────────────────────
out_path = OUT_DIR / "ABAWD_waivers_extracted.csv"
out_path.parent.mkdir(parents=True, exist_ok=True)
df = pd.DataFrame(rows, columns=HEADERS)
df = df.drop_duplicates(subset=["YEAR","STATE_ABBREV","LOC","DATE_START","DATE_END"])
df[["DATE_START","DATE_END"]] = df.groupby("SOURCE_DOC")[["DATE_START","DATE_END"]].ffill()
df.to_csv(out_path, index=False)
print(f"✅  Process complete – saved to {out_path}")
