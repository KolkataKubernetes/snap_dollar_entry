# Import Packages

"""
This script (written by ChatGPT, commented by me)

    Recursively loads PDF waivers from a directory.

    Extracts page-level text, likely using OCR + pdfplumber.

    Prompts a local LLM to extract structured waiver data (locations, dates).

    Parses LLM output into a tabular format.

    Saves the result as a clean, analysis-ready CSV.

"""
import argparse
...
parser = argparse.ArgumentParser()
parser.add_argument("--one", help="Path to a single PDF to test", default=None)
args = parser.parse_args()

import os, json, re, requests, csv
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd 
from extract_pages import page_texts #Custom function that extracts clean text from the PDF

load_dotenv() #load the enivronment variables from a .env file
ROOT = Path(os.getenv("WAIVER_ROOT")) #Root folder with PDFs
OUT_DIR = Path(os.path.expandvars(os.getenv("DOWNLOADS_DIR")))  # ← expand $HOME, where to save output

MODEL = os.getenv("MODEL") #name of the LLM Model to call: SHOULD I REPLACE THIS WITH LLAMA3.2?
STATE_LUT = json.loads((Path(__file__).parent / "state_lookup.json").read_text()) #JSON look-up table
PROMPT_RAW = (Path(__file__).parent / "prompt.txt").read_text()

if ROOT is None or OUT_DIR is None:
    raise RuntimeError("WAIVER_ROOT or DOWNLOADS_DIR not set (check .env)")

HEADERS = ["YEAR","STATE","STATE_ABBREV","ENTIRE_STATE",
           "LOC","LOC_TYPE","DATE_START","DATE_END","SOURCE_DOC"] #Column names for the final CSV

rows = [] #accumulates extracte data for location/state

#Take a page of text and "inject" it into a prompt template - returns the full-formed prompt
def prompt_for(page, year, st_abbr, doc):
    return (PROMPT_RAW 
            #Inject context vars into template
            .replace("{{year}}", str(year))
            .replace("{{state_abbr}}", st_abbr)
            .replace("{{state_full}}", STATE_LUT[st_abbr])
            .replace("{{doc_name}}", doc)
            .replace("{{page_text}}", page))

def query_llm(prompt):
    r = requests.post("http://localhost:11434/api/generate", ##Do I have to generate this? 
        json={"model": MODEL, "format": "json",
              "stream": False, "prompt": prompt, "temperature": 0}, 
        timeout=180)
    return json.loads(r.json()["response"])

#Main loop: PDF Extraction
pdf_iter = [Path(args.one)] if args.one else ROOT.rglob("*.pdf")
for pdf in pdf_iter: #Recursively find all PDFs
    year, st_abbr, *_ = pdf.stem.split("_") #assume each file is named YYYY_AB_mod.pdf
    year, st_abbr = int(year), st_abbr.upper()
    for page in page_texts(pdf): #Invoke the page_texts function, loop through parsed text
        data = query_llm(prompt_for(page, year, st_abbr, pdf.stem)) #Create data output in JSON format
        print("DEBUG raw:", repr(data)[:200])   # shows first 200 chars
            # Normalise / guard
        if isinstance(data, dict):
            data = [data]
        elif isinstance(data, str):
            raise ValueError(f"Model did not return JSON array:\n{data}")
        for item in data: #Now, parse the model output
            if item["entire_state"]: #If the waiver applied to the entire state for that year, record one row with the flag set and empty location fields
                rows.append([year, STATE_LUT[st_abbr], st_abbr, 1, "", "", item["date_start"], item["date_end"], pdf.stem])
                
            else: 
                for loc, ltype in zip(item["loc"], item["loc_type"]):
                    rows.append([year, STATE_LUT[st_abbr], st_abbr, 0, loc, ltype, item["date_start"], item["date_end"], pdf.stem])

df = pd.DataFrame(rows, columns = HEADERS)
out_path = OUT_DIR / "ABAWD_waivers_extracted.csv"
df.to_csv(out_path, index = False)
print(f"Process Complete :Saved to {out_path}")