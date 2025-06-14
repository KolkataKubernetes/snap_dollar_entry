# Import Packages

import os, json, re, requests, csv
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd 
from extract_pages import page_texts #Custom function that extracts clean text from the PDF

load_dotenv() #load the enivronment variables from a .env file
ROOT = Path(os.getenv("WAIVER_ROOT")) #Root folder with PDFs
OUT_DIR = Path(os.getenv("DOWNLOADS_DIR")) #Where to save output
MODEL = os.getenv("MODEL") #name of the LLM Model to call: SHOULD I REPLACE THIS WITH LLAMA3.2?
STATE_LUT = json.loads(Path("state_lookup.json").read_text()) #JSON look-up table
PROMPT_RAW = Path("src/prompt.txt").read_text()

HEADERS = ["YEAR","STATE","STATE_ABBREV","ENTIRE_STATE",
           "LOC","LOC_TYPE","DATE_START","DATE_END","SOURCE_DOC"] #Column names for the final CSV

rows = [] #accumulates extracte data for location/state

#Take a page of text and "inject" it into a prompt template - returns the full-formed prompt
def prompt_for(page, year, st_abbr, doc):
    return (PROMPT_RAW ##?? Ask GPT to explain this further
            .replace("{{year}}", str(year))
            .replace("{{state_abbr}}", st_abbr)
            .replace("{{state_full}}", STATE_LUT[st_abbr])
            .replace("{{doc_name}}", doc)
            .replace("{{doc_name}}", doc))

def query_llm(prompt):
    r = requests.post("http://localhost:11434/api/generate",
        json={"model": MODEL, "format": "json",
              "stream": False, "prompt": prompt, "temperature": 0}, 
        timeout=180)
    return json.loads(r.json()["response"])