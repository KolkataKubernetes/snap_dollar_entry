# src/extract_pages.py
# ------------------------------------------------------------
"""
Hybrid table-first extractor for ABAWD waiver PDFs
=================================================

* **Stage 1 – vector tables (loss-less)**
  Grab any table whose text is embedded in the PDF (Camelot-Py → pdfplumber).
  This is 100 % accurate when it works and avoids OCR noise.

* **Stage 2 – raster tables (OCR)**
  If Stage 1 finds no tables on a page, render that page to an image
  (pdf2image) and run Tesseract to recover text.  Lines belonging to the
  same table row are grouped via (block_num, par_num).

* **Stage 3 – fallback to full text**
  If a page still yields no tables, return the entire text layer so we
  never miss geography lists written as paragraphs.

`page_texts(pdf_path)` returns **one string per page**, favouring table
cells but falling back to full-page text if needed.

Dependencies (conda-forge packages):
    camelot-py[cv] pdfplumber pdf2image pytesseract
System binaries (or conda-forge equivalents):
    ghostscript poppler tesseract-ocr
"""
from __future__ import annotations

import tempfile
from pathlib import Path
from typing import List

import camelot
import pandas as pd
import pdfplumber
import pytesseract
from pdf2image import convert_from_path

# ───────────────────────── config ───────────────────────────
MIN_CELL_CHARS = 2      # ignore OCR snippets shorter than this
DPI_RASTER     = 300    # render resolution for pdf2image

# ────────────────── helpers: vector paths ───────────────────
def _vector_tables_from_page(pdf_path: Path, page_no: int) -> List[pd.DataFrame]:
    """Return DataFrames found by Camelot (lattice → stream) on one page."""
    tables: List[pd.DataFrame] = []
    for flavor in ("lattice", "stream"):            # try precise → fuzzy
        try:
            cams = camelot.read_pdf(str(pdf_path), pages=str(page_no), flavor=flavor)
            tables.extend(t.df for t in cams)
            if tables:
                break
        except Exception:
            # Camelot sometimes errors on odd PDFs; swallow & continue
            pass
    return tables

# ─────────────── helpers: raster-OCR path ───────────────────
def _raster_tables_from_page(pdf_path: Path, page_no: int) -> List[pd.DataFrame]:
    """Render page → image → Tesseract TSV → group by (block, par)."""
    dfs: List[pd.DataFrame] = []
    with tempfile.TemporaryDirectory() as tmp:
        images = convert_from_path(
            str(pdf_path),
            dpi=DPI_RASTER,
             first_page=page_no,
            last_page=page_no,
            output_folder=tmp,
        )
        if not images:
            return dfs
        img = images[0]
        tsv = pytesseract.image_to_data(img, output_type=pytesseract.Output.DATAFRAME)
        if tsv.empty:
            # --- last-ditch fallback: OCR the whole page as one blob ----
            txt_full = pytesseract.image_to_string(img)
            if txt_full.strip():
                dfs.append(pd.DataFrame([[txt_full.strip()]]))
            return dfs


        # group words by table-row proxy
        for (_, _), g in tsv.groupby(["block_num", "par_num"], sort=False):
            words = [w for w in g.text if isinstance(w, str) and w.strip()]
            if not words:
                continue
            txt = " ".join(words)
            if len(txt) < MIN_CELL_CHARS:
                continue
            dfs.append(pd.DataFrame([[txt]]))
    return dfs

# ─────────────────────────  API  ────────────────────────────
def page_texts(pdf_path: Path) -> List[str]:
    """
    Return list where index *i* = text extracted from page *(i+1)*.

    Extraction preference per page:
        1. Vector tables  (Camelot / pdfplumber)
        2. Raster-OCR tables  (Tesseract TSV)
        3. Whole page text  (pdfplumber)
    """
    page_strings: List[str] = []

    with pdfplumber.open(str(pdf_path)) as pdf_obj:
        num_pages = len(pdf_obj.pages)

    for p in range(1, num_pages + 1):        # Camelot is 1-based
        # — Stage 1: vector tables —
        tables = _vector_tables_from_page(pdf_path, p)

        # — Stage 2: raster OCR tables —
        if not tables:
            tables = _raster_tables_from_page(pdf_path, p)

        # emit concatenated table text if found
        if tables:
            cell_texts = []
            for df in tables:
                cell_texts.extend(df.values.ravel().tolist())
            page_strings.append(
                "\n".join(str(c) for c in cell_texts if str(c).strip())
            )
            continue

        # — Stage 3: fallback to full text —
        with pdfplumber.open(str(pdf_path)) as pdf_obj:
            txt = pdf_obj.pages[p - 1].extract_text() or ""
        page_strings.append(txt)

    return page_strings
