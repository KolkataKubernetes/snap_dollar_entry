# snap_dollar_entry
Virtually all of this script was written by ChatGPT.
snap_dollar_entry
├─0_data #Contains FNS_Responses, which year subfolders, under which we have the PDFs of interest.
├─abawd_llm
    ├─ .env                  # keeps paths & API knobs
    ├─ src/
    │   ├─ extract_pages.py  # text-layer + OCR helper
    │   ├─ prompt.txt        # LLM template
    │   └─ run_pipeline.py   # main driver → CSV
    │   └─ state_lookup.json # { "AK": "Alaska", … }
    