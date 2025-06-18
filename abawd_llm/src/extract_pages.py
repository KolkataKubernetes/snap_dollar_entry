from pathlib import Path
import pdfplumber #Get PDF data - box locations, etc
import pytesseract #Optical character recognition in Python
from pdf2image import convert_from_path

MIN_CHARS = 30          # threshold for “has text”

def page_texts(pdf_path: Path, dpi=500): #400-450 dpi might help with fonts. 
    """
    Yields plain-text strings, one per page, for *any* PDF.
    """
    txt_map = {}
    ocr_needed = []

    with pdfplumber.open(pdf_path) as pdf: #Opens PDF File using pdfplumber
        for i, page in enumerate(pdf.pages, 1): #loop through each page in the PDF, adjust index for 1 
            txt = (page.extract_text() or "").strip() #See if we can use pdfplumber's extract_text() method
            if len(txt) >= MIN_CHARS: # If there are at least 30 characters on the page, store in txt_map dictionary
                txt_map[i] = txt
            else:
                ocr_needed.append(i) #Otherwise, use OCR library - we'll append to the OCR dictionary

    if ocr_needed: #Check ocr_needed dictionary 
        images = convert_from_path( #Image conversion using pdf2image
            pdf_path, dpi=dpi, #Note that DPI is defaulting to 300
            first_page=min(ocr_needed),
            last_page=max(ocr_needed),
            fmt="png",
            thread_count=4 #Limit to 4 cores 
        )
        for idx, img in zip(range(min(ocr_needed), max(ocr_needed)+1), images): #Pair each page index which its corresponding image
            if idx in ocr_needed: 
                txt_map[idx] = pytesseract.image_to_string(img, lang="eng", config = "--oem 1 --psm 6") #Use OCR

    return [txt_map[i] for i in sorted(txt_map)] #Returns a list of extracted text for all successfully processed pages, sorted by page number. Combined results from Tesseract, pdfplumber

