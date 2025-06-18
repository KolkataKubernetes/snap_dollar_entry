# src/run_pipeline.py
# ------------------------------------------------------------
"""
Parse ABAWD waiver PDFs → CSV using a local Ollama LLM.

Pipeline
1. OCR / text layer extraction (extract_pages.py).
2. Regex-harvest place names ⇒ CANDIDATES list.
3. Build a prompt (prompt.txt) populated with context + candidates.
4. Call Ollama /api/generate (model = llama3.2 by default).
5. Validate / repair JSON, infer missing loc_type, sanitize.
6. Append rows → DataFrame → CSV (dates forward-filled).
"""

import argparse, json, os, re, requests
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd
from extract_pages import page_texts

# ── CLI ------------------------------------------------------
ap = argparse.ArgumentParser()
ap.add_argument("--one", help="Path to a single PDF for a dry-run")
args = ap.parse_args()

# ── ENV / paths ---------------------------------------------
load_dotenv()
ROOT     = Path(os.getenv("WAIVER_ROOT"))          # year folders
OUT_DIR  = Path(os.path.expandvars(os.getenv("DOWNLOADS_DIR")))
MODEL    = os.getenv("MODEL", "llama3.2")

if not ROOT.exists():
    raise RuntimeError(f"WAIVER_ROOT not found: {ROOT}")

state_lut  = json.loads((Path(__file__).parent / "state_lookup.json").read_text())
prompt_raw = (Path(__file__).parent / "prompt.txt").read_text()

# ── Regex helpers -------------------------------------------
county_pat      = re.compile(r"\b([A-Z][a-z]+ County)\b")
reservation_pat = re.compile(r"\b([A-Z][a-z]+ (?:Nation|Reservation))\b")
city_pat        = re.compile(r"\b([A-Z][a-z]+ City)\b")
town_pat        = re.compile(r"\b([A-Z][a-z]+ Town)\b")
agg_pat         = re.compile(r"^(?:\d+|one)\s+(county|counties|city|cities|reservation|areas?)$", re.I)

# ── Prompt + LLM helpers ------------------------------------
def prompt_for(page_txt, year, st_abbr, doc, candidates):
    block = json.dumps(sorted(candidates), ensure_ascii=False)
    return (prompt_raw
            .replace("{{year}}", str(year))
            .replace("{{state_abbr}}", st_abbr)
            .replace("{{state_full}}", state_lut[st_abbr])
            .replace("{{doc_name}}", doc)
            .replace("{{JSON_ENCODED_LIST_OF_NAMES}}", block)
            .replace("{{page_text}}", page_txt))

def query_llm(prompt: str):
    r = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": MODEL, "format": "json",
              "stream": False, "prompt": prompt, "temperature": 0},
        timeout=180
    )
    return json.loads(r.json()["response"])

# --- infer loc_type from name --------------------------------
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

# --- validate / repair JSON ----------------------------------
def fix_if_needed(raw):
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        raise ValueError("Model output not a list")
    
    for itm in raw:
        # ---------- NEW : ensure entire_state key -------------
        if "entire_state" not in itm:
            itm["entire_state"] = 0
        # ------------------------------------------------------

    for itm in raw:
        # normalise loc
        locs = itm.get("loc")
        if locs is None:
            locs = []
        elif not isinstance(locs, list):
            locs = [locs]

        # normalise loc_type
        types = itm.get("loc_type")
        if types is None:
            types = []
        elif not isinstance(types, list):
            types = [types]

        # strip & drop empties
        locs  = [x.strip() for x in locs if x and str(x).strip()]
        types = [t.strip() for t in types if t and str(t).strip()]

        # auto-fill / trim
        if len(types) < len(locs):
            for name in locs[len(types):]:
                types.append(infer_type(name))
        elif len(types) > len(locs):
            types[:] = types[:len(locs)]

        # write back & final check
        itm["loc"] = locs
        itm["loc_type"] = types
        if len(locs) != len(types):
            raise ValueError("loc/loc_type length mismatch after sanitising")

    return raw

# ── Output table --------------------------------------------
HEADERS = ["YEAR","STATE","STATE_ABBREV","ENTIRE_STATE",
           "LOC","LOC_TYPE","DATE_START","DATE_END","SOURCE_DOC"]
rows = []

# ── Main loop -----------------------------------------------
pdf_iter = [Path(args.one)] if args.one else ROOT.rglob("*.pdf")

for pdf in pdf_iter:
    year, st_abbr, *_ = pdf.stem.split("_")
    year, st_abbr = int(year), st_abbr.upper()

    for pg_idx, text in enumerate(page_texts(pdf), 1):
        # harvest candidates from page text
        cands = set(county_pat.findall(text) +
                    reservation_pat.findall(text) +
                    city_pat.findall(text) +
                    town_pat.findall(text))

        prompt = prompt_for(text, year, st_abbr, pdf.stem, cands)

        # ---- NEW: Save the exact prompt for inspection ---------
        prompt_path = OUT_DIR / f"{pdf.stem}_page_{pg_idx:02d}_prompt.txt"
        prompt_path.write_text(prompt)

        # retry once if JSON invalid
        for attempt in range(2):
            try:
                data = fix_if_needed(query_llm(prompt))
                break
            except ValueError as e:
                if attempt == 1:
                    raise
                prompt = ("Your previous answer was invalid "
                          f"({e}).  Return a corrected JSON array ONLY.\n"
                          + prompt)

        # assemble rows
        for item in data:
            d_start = item.get("date_start")
            d_end   = item.get("date_end")

            if item["entire_state"]:
                rows.append([year, state_lut[st_abbr], st_abbr, 1,
                             "", "", d_start, d_end, pdf.stem])
                continue

            for loc, ltype in zip(item["loc"], item["loc_type"]):
                if agg_pat.match(loc.lower()) or loc.lower() in {"arizona", "page"}:
                    continue
                rows.append([year, state_lut[st_abbr], st_abbr, 0,
                             loc, ltype, d_start, d_end, pdf.stem])

# ── Save CSV -------------------------------------------------
out_path = OUT_DIR / "ABAWD_waivers_extracted.csv"
out_path.parent.mkdir(parents=True, exist_ok=True)

df = pd.DataFrame(rows, columns=HEADERS)
df = df.drop_duplicates(subset=["YEAR","STATE_ABBREV","LOC","DATE_START","DATE_END"])
df[["DATE_START","DATE_END"]] = df.groupby("SOURCE_DOC")[["DATE_START","DATE_END"]].ffill()
df.to_csv(out_path, index=False)
print(f"✅  Process complete – saved to {out_path}")
