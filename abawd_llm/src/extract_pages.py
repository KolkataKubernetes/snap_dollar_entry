# src/extract_pages.py
# ------------------------------------------------------------
"""
Table‑centric extractor for ABAWD waiver PDFs.

Returns **only** the text found inside tables** on each page, because the
geography lists we care about (counties, towns, reservations) always appear in
tabular attachments.

Strategy
========
1. **Vector path first (loss‑less):**
   • Use Camelot‑Py to detect Lattice‑mode tables (ruling lines) and Stream‑mode
     tables (white‑space delimited) on every page.  Camelot gives DataFrames
     whose cells already contain clean strings.
2. **Fallback to pdfplumber** for vector tables Camelot sometimes misses.
3. **Raster fallback:**
   • Render page → PNG (300 dpi).
   • Run Tesseract in TSV mode (`--psm 6`, assume a uniform block of text).
   • Coarsely group the recognised words by (block, line_num) to reconstruct
     each row of the original table.

The function `page_texts(pdf_path)` returns a list of strings, *one per page*.
If a page contains multiple tables, their rows are concatenated with newlines.
If no table is found on a page, an empty string is returned for that index so
that callers keep a one‑to‑one correspondence with PDF pages (helpful for
logging / debugging).

Dependencies
------------
* camelot-py[cv]  (requires ghostscript + opencv)
* pdfplumber
* pdf2image (requires poppler)
* pytesseract  (requires system tesseract‑ocr)

Install:
    pip install camelot-py[cv] pdfplumber pdf2image pytesseract
"""
from __future__ import annotations

from pathlib import Path
from typing import List
import io
import tempfile

import camelot
import pdfplumber
from pdf2image import convert_from_path
import pytesseract
import pandas as pd

# ---------------------------------------------------------------------------
# Helper:  collapse a DataFrame's cells into a printable, row‑separated string
# ---------------------------------------------------------------------------

def _df_to_text(df: pd.DataFrame) -> str:
    rows = []
    for _, row in df.iterrows():
        # Join non‑empty cells by single space to keep geography names intact
        cells = [str(x).strip() for x in row if str(x).strip()]
        if cells:
            rows.append(" ".join(cells))
    return "\n".join(rows)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def page_texts(pdf_path: str | Path) -> List[str]:
    """Return list[str] whose *i*th entry is the table‑text of page *i* (0‑based).

    Empty string means no table (or nothing recognisable) on that page.
    """
    pdf_path = Path(pdf_path)
    num_pages: int | None = None
    out: List[str] = []

    # ---------- Pass 1: Camelot (vector tables) ----------------------------
    try:
        tables = camelot.read_pdf(
            str(pdf_path), pages="all", flavor="lattice", strip_text="\n"
        )
        if not tables:
            tables = camelot.read_pdf(
                str(pdf_path), pages="all", flavor="stream", strip_text="\n"
            )
        for tbl in tables:
            df = tbl.df
            p = tbl.page  # 1‑based page index
            if num_pages is None:
                num_pages = tbl.n  # Camelot sets total pages here
            # ensure list is long enough
            while len(out) < p:
                out.append("")
            out[p - 1] += ("\n" if out[p - 1] else "") + _df_to_text(df)
    except Exception:
        # Camelot can throw on malformed PDFs; ignore → raster fallback
        pass

    # ---------- Pass 2: pdfplumber (vector tables Camelot missed) ----------
    try:
        with pdfplumber.open(str(pdf_path)) as pdf:
            if num_pages is None:
                num_pages = len(pdf.pages)
            for idx, page in enumerate(pdf.pages, 1):
                tbls = page.extract_tables()
                if not tbls:
                    continue
                while len(out) < idx:
                    out.append("")
                for raw_tbl in tbls:
                    df = pd.DataFrame(raw_tbl)
                    out[idx - 1] += ("\n" if out[idx - 1] else "") + _df_to_text(df)
    except Exception:
        pass

    # ---------- ensure we have a placeholder for every page before raster ---
    if num_pages is None:
        # We don't know page count yet; estimate via pdf2image later
        num_pages = 0

    # ---------- Pass 3: raster OCR (only pages still empty) -----------------
    empty_pages = [i for i, txt in enumerate(out) if not txt]
    if empty_pages:
        with tempfile.TemporaryDirectory() as tmp:
            images = convert_from_path(str(pdf_path), dpi=300, output_folder=tmp)
            if num_pages == 0:
                num_pages = len(images)
            # pad list if images > out
            while len(out) < len(images):
                out.append("")
            for i, img in enumerate(images):
                if i not in empty_pages:
                    continue  # skip pages already populated
                tsv = pytesseract.image_to_data(
                    img, lang="eng", output_type=pytesseract.Output.DATAFRAME, config="--psm 6"
                )
                if tsv.empty:
                    continue
                # group by (block, line) to approximate table rows
                rows = []
                for (_b, _p, line), g in tsv.groupby(["block_num", "par_num", "line_num"]):
                    txt = " ".join(str(t).strip() for t in g.text if str(t).strip())
                    if txt:
                        rows.append(txt)
                out[i] = "\n".join(rows)

    # ---------- final padding if some pages had no text at all --------------
    while len(out) < num_pages:
        out.append("")

    return out
