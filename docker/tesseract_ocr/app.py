import os
import shutil
import tempfile
import time
from pathlib import Path

import pytesseract

from fastapi import FastAPI, File, HTTPException, UploadFile
from pdf2image import convert_from_path
from PIL import Image
from pytesseract import Output


app = FastAPI(
    title="Tesseract OCR Service",
    version="1.0.0"
)


ALLOWED_EXTENSIONS = {
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg"
}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "provider": "tesseract"
    }


def image_to_result(image, page_number):
    data = pytesseract.image_to_data(
        image,
        lang="tur+eng",
        output_type=Output.DICT,
        config="--oem 1 --psm 6"
    )

    lines = []
    text_parts = []

    count = len(data["text"])

    for index in range(count):
        text = data["text"][index].strip()

        if not text:
            continue

        try:
            confidence = float(data["conf"][index])
        except (ValueError, TypeError):
            confidence = None

        left = int(data["left"][index])
        top = int(data["top"][index])
        width = int(data["width"][index])
        height = int(data["height"][index])

        box = [
            left,
            top,
            left + width,
            top + height
        ]

        lines.append({
            "text": text,
            "confidence": confidence,
            "box": box
        })

        text_parts.append(text)

    page_text = " ".join(text_parts)

    return {
        "page": page_number,
        "text": page_text,
        "lines": lines
    }


@app.post("/ocr")
def run_ocr(file: UploadFile = File(...)):
    filename = file.filename or "document"
    suffix = Path(filename).suffix.lower()

    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Only PDF, PNG, JPG and JPEG files are supported."
        )

    temp_path = None

    try:
        with tempfile.NamedTemporaryFile(
            delete=False,
            suffix=suffix
        ) as temp_file:

            shutil.copyfileobj(
                file.file,
                temp_file
            )

            temp_path = temp_file.name


        started_at = time.perf_counter()

        pages = []


        if suffix == ".pdf":

            images = convert_from_path(
                temp_path,
                dpi=200
            )

            for page_number, image in enumerate(
                images,
                start=1
            ):
                pages.append(
                    image_to_result(
                        image,
                        page_number
                    )
                )

        else:

            image = Image.open(temp_path)

            pages.append(
                image_to_result(
                    image,
                    1
                )
            )


        duration_ms = round(
            (
                time.perf_counter()
                - started_at
            ) * 1000,
            2
        )


        full_text = "\n\n".join(
            page["text"]
            for page in pages
        )


        return {
            "provider": "tesseract",
            "model": "Tesseract 5",
            "filename": filename,
            "text": full_text,
            "pages": pages,
            "page_count": len(pages),
            "duration_ms": duration_ms
        }


    except Exception as error:

        raise HTTPException(
            status_code=500,
            detail=str(error)
        )


    finally:

        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)