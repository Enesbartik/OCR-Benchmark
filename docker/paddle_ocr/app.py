import os
import shutil
import tempfile
import threading
import time
import uuid
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from paddleocr import PaddleOCR


app = FastAPI(
    title="PaddleOCR Service",
    version="1.0.0"
)


# OCR modeli container başlarken sadece bir kere oluşturulur.
ocr = PaddleOCR(
    lang="tr",
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False
)


# PaddleOCR modelini aynı anda sadece bir request kullanabilsin.
ocr_lock = threading.Lock()


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
        "provider": "paddleocr"
    }


@app.post("/ocr")
def run_ocr(file: UploadFile = File(...)):
    request_id = str(uuid.uuid4())[:8]

    filename = file.filename or "document"
    suffix = Path(filename).suffix.lower()

    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Only PDF, PNG, JPG and JPEG files are supported."
        )

    temp_path = None

    request_started_at = time.perf_counter()

    print(
        f"[PADDLE][{request_id}] Request received: {filename}",
        flush=True
    )

    try:
        # Rails'ten gelen dosyayı geçici olarak diske yaz.
        with tempfile.NamedTemporaryFile(
            delete=False,
            suffix=suffix
        ) as temp_file:

            shutil.copyfileobj(
                file.file,
                temp_file
            )

            temp_path = temp_file.name


        print(
            f"[PADDLE][{request_id}] Waiting for OCR lock...",
            flush=True
        )


        # Aynı PaddleOCR instance'ına aynı anda
        # iki inference girmesini engelliyoruz.
        with ocr_lock:

            inference_started_at = time.perf_counter()

            queue_wait_ms = round(
                (
                    inference_started_at -
                    request_started_at
                ) * 1000,
                2
            )

            print(
                f"[PADDLE][{request_id}] OCR started "
                f"(queue wait: {queue_wait_ms} ms)",
                flush=True
            )


            results = ocr.predict(temp_path)


            inference_finished_at = time.perf_counter()


        inference_ms = round(
            (
                inference_finished_at -
                inference_started_at
            ) * 1000,
            2
        )


        pages = []
        all_text = []


        for page_number, result in enumerate(
            results,
            start=1
        ):

            # PaddleOCR Result -> normal Python dictionary
            payload = result.json

            data = payload.get(
                "res",
                payload
            )

            texts = (
                data.get("rec_texts", [])
                or []
            )

            scores = (
                data.get("rec_scores", [])
                or []
            )

            boxes = (
                data.get("rec_boxes", [])
                or []
            )

            lines = []


            for index, text in enumerate(texts):

                confidence = None
                box = None


                if index < len(scores):
                    confidence = float(
                        scores[index]
                    )


                if index < len(boxes):

                    current_box = boxes[index]

                    box = (
                        current_box.tolist()
                        if hasattr(
                            current_box,
                            "tolist"
                        )
                        else current_box
                    )


                lines.append({
                    "text": str(text),
                    "confidence": confidence,
                    "box": box
                })


            page_text = "\n".join(
                line["text"]
                for line in lines
                if line["text"]
            )


            all_text.append(page_text)


            page_index = data.get(
                "page_index"
            )

            if hasattr(
                page_index,
                "item"
            ):
                page_index = (
                    page_index.item()
                )


            pages.append({
                "page": page_number,
                "page_index": page_index,
                "text": page_text,
                "lines": lines
            })


        total_duration_ms = round(
            (
                time.perf_counter() -
                request_started_at
            ) * 1000,
            2
        )


        print(
            f"[PADDLE][{request_id}] Completed "
            f"- inference: {inference_ms} ms "
            f"- total: {total_duration_ms} ms",
            flush=True
        )


        return {
            "provider": "paddleocr",
            "model": "PP-OCRv6-medium",
            "filename": filename,

            "text": "\n\n".join(
                all_text
            ),

            "pages": pages,

            "page_count": len(pages),

            "duration_ms":
                total_duration_ms,

            "inference_ms":
                inference_ms,

            "queue_wait_ms":
                queue_wait_ms
        }


    except Exception as error:

        print(
            f"[PADDLE][{request_id}] ERROR: "
            f"{type(error).__name__}: {error}",
            flush=True
        )

        raise HTTPException(
            status_code=500,
            detail=str(error)
        )


    finally:

        if (
            temp_path
            and os.path.exists(temp_path)
        ):
            os.remove(temp_path)