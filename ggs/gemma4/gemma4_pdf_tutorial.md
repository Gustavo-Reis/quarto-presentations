# Gemma 4 + PDF Context — Practical Tutorial
### HuggingFace `transformers` · Python ≥ 3.11 · CUDA 12.x

---

## 1. The Gemma 4 family at a glance

Gemma 4 was released by Google DeepMind on **April 2, 2026** under Apache 2.0.

| HF model ID | Type | Params | Context | Modalities |
|---|---|---|---|---|
| `google/gemma-4-E2B-it` | Dense + PLE | 2.3 B effective / 5.1 B total | 128 K | Text, Image, Audio |
| `google/gemma-4-E4B-it` | Dense + PLE | 4.5 B effective / 8 B total | 128 K | Text, Image, Audio |
| `google/gemma-4-26B-A4B-it` | MoE (8/128 experts) | 3.8 B active / 25.2 B total | 256 K | Text, Image |
| `google/gemma-4-31B-it` | Dense | 30.7 B | 256 K | Text, Image |

**Key facts (from the official model card):**
- No raw `.pdf` input type exists — feed PDFs either as **extracted text** or as **rasterised page images**.
- The vision tower is explicitly trained for Document/PDF parsing, OCR (multilingual + handwriting), charts, tables, and screen/UI understanding — so the **image path is first-class**, not a fallback.
- Text and images can be **interleaved in any order**. Placing images before text gives slightly better performance per official guidance.
- Native `system` role (new in Gemma 4 — Gemma 3 lacked it).
- Thinking mode: prefix system prompt with `<|think|>` to enable step-by-step reasoning.
- Audio (ASR + speech translation): **E2B/E4B only**.
- Also supports: Function Calling, Video Understanding (frame sequences), 35+ languages.
- Recommended sampling: `temperature=1.0`, `top_p=0.95`, `top_k=64`. Use `do_sample=False` (greedy) for extraction/OCR tasks.

### VRAM budget

| Model | bf16 | 4-bit NF4 | Fits on |
|---|---|---|---|
| E2B | ~10 GB | ~3.5 GB | 8 GB GPU ✓ |
| E4B | ~15 GB | ~5 GB | 8 GB GPU (tight) / 16 GB ✓ |
| 26B A4B | ~50 GB | ~18 GB | 24 GB GPU |
| 31B | ~60 GB | ~20 GB | **32 GB GPU ✓** |

> **RTX 5090 / 32 GB:** use E4B in bf16 (~15 GB) or 31B at 4-bit (~20 GB) for best quality.  
> **8 GB GPU:** use E2B at 4-bit (~3.5 GB) — leaves enough room for KV cache and image tokens.

---

## 2. Installing dependencies

```bash
python -m venv .venv && source .venv/bin/activate

# Transformers — Gemma 4 requires a recent version
pip install -U "transformers>=4.57" accelerate

# 4-bit quantization (skip if you have enough VRAM for bf16)
pip install -U bitsandbytes

# PyTorch — match your CUDA version
pip install -U torch --index-url https://download.pytorch.org/whl/cu124

# Image + audio support
pip install -U torchvision librosa pillow

# PDF rasterisation + text extraction
pip install -U pymupdf pypdf pdfplumber
```

---

## 3. Choosing the right model class

Gemma 4 has **two relevant Auto classes** in `transformers`:

| Class | Use when | Notes |
|---|---|---|
| `AutoModelForCausalLM` | Text-only input | Lighter, faster to load |
| `AutoModelForImageTextToText` | Image + text input | Required for PDF page images |

Both resolve to `Gemma4ForConditionalGeneration` internally. Use the same `AutoProcessor` for both.

> **Do not use** `AutoModelForMultimodalLM` — it is not the correct class for Gemma 4.

---

## 4. Loading the model

### 4.1 — 8 GB GPU (E2B, 4-bit, text-only)

```python
import torch
from transformers import AutoProcessor, AutoModelForCausalLM, BitsAndBytesConfig

MODEL_ID = "google/gemma-4-E2B-it"

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_quant_storage=torch.bfloat16,
)

processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    quantization_config=bnb,
    device_map="cuda:0",          # ⚠️ use "cuda:0", NOT "auto" — see gotchas
    dtype="auto",
    attn_implementation="sdpa",   # or "flash_attention_2" on Ampere+
)

print(f"Footprint : {model.get_memory_footprint()/1e9:.2f} GB")
print(f"VRAM used : {torch.cuda.memory_allocated()/1e9:.2f} GB")
```

### 4.2 — 8 GB GPU (E2B, 4-bit, image input)

Switch to `AutoModelForImageTextToText` — everything else stays the same:

```python
from transformers import AutoProcessor, AutoModelForImageTextToText, BitsAndBytesConfig

processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForImageTextToText.from_pretrained(
    MODEL_ID,
    quantization_config=bnb,
    device_map="cuda:0",
    dtype="auto",
    attn_implementation="sdpa",
)
```

### 4.3 — 32 GB GPU (E4B bf16 — best quality, no quantization)

```python
import torch
from transformers import AutoProcessor, AutoModelForImageTextToText

MODEL_ID = "google/gemma-4-E4B-it"

processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForImageTextToText.from_pretrained(
    MODEL_ID,
    torch_dtype=torch.bfloat16,
    device_map="cuda:0",
    attn_implementation="sdpa",
)

print(f"Footprint : {model.get_memory_footprint()/1e9:.2f} GB")
print(f"VRAM used : {torch.cuda.memory_allocated()/1e9:.2f} GB")
```

### 4.4 — 32 GB GPU (31B at 4-bit — maximum reasoning quality)

```python
MODEL_ID = "google/gemma-4-31B-it"

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_quant_storage=torch.bfloat16,
)

processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForImageTextToText.from_pretrained(
    MODEL_ID,
    quantization_config=bnb,
    device_map="cuda:0",
    dtype="auto",
    attn_implementation="sdpa",
)
```

---

## 5. Feeding PDFs to Gemma 4

Gemma 4 does not accept raw `.pdf` bytes. You have two paths:

| Path | When to use | Libraries |
|---|---|---|
| **Text extraction → text tokens** | Digital PDFs with embedded text | `pymupdf`, `pypdf`, `pdfplumber` |
| **Rasterise pages → images** | Scanned, handwritten, complex layouts, forms, tables, charts | `pymupdf` (fitz) |

> **Handwritten or scanned PDFs:** text extraction returns only page numbers or garbage. Always use the image path. Gemma 4's vision tower is trained specifically for handwriting OCR.

### 5.1 Check if text extraction works

```python
import fitz

def check_pdf_has_text(path: str, min_chars_per_page: int = 50) -> bool:
    """Returns True if the PDF has usable embedded text."""
    with fitz.open(path) as doc:
        for page in doc:
            if len(page.get_text("text").strip()) >= min_chars_per_page:
                return True
    return False

if check_pdf_has_text("document.pdf"):
    print("→ Use text extraction path")
else:
    print("→ Use image path (scanned/handwritten)")
```

### 5.2 Text extraction (digital PDFs)

```python
from pathlib import Path
from typing import Iterable

def extract_text(path) -> list[dict]:
    with fitz.open(path) as doc:
        return [{"source": str(path), "page": i+1, "text": p.get_text("text")}
                for i, p in enumerate(doc)]

def load_corpus(paths: Iterable) -> list[dict]:
    corpus = []
    for p in paths:
        corpus.extend(extract_text(p))
    return corpus

def format_context(chunks: list[dict], max_chars: int = 60_000) -> str:
    out, used = [], 0
    for c in chunks:
        header = f"--- [source: {Path(c['source']).name}, p. {c['page']}] ---\n"
        body = c["text"].strip() + "\n\n"
        if used + len(header) + len(body) > max_chars:
            break
        out.append(header + body)
        used += len(header) + len(body)
    return "".join(out)
```

### 5.3 Image rasterisation (scanned / handwritten PDFs)

```python
from PIL import Image
from io import BytesIO

def pdf_to_images(path: str, dpi: int = 200) -> list[Image.Image]:
    """
    DPI guide:
      150 — fast, acceptable for printed text
      200 — good balance for most documents  ← recommended default
      300 — best for small or dense handwriting
    """
    images = []
    with fitz.open(path) as doc:
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        for page in doc:
            pix = page.get_pixmap(matrix=mat, alpha=False)
            images.append(Image.open(BytesIO(pix.tobytes("png"))))
    return images
```

---

## 6. Querying PDFs — text path

For digital PDFs with embedded text:

```python
SYSTEM = (
    "You are an expert document analyst. "
    "Answer ONLY using the provided <CONTEXT>. "
    "Cite sources as [source: filename, p. N]. "
    "If the answer is not in the context, say 'Not found in the provided documents.'"
)

def ask_text(question: str, corpus: list[dict], enable_thinking: bool = False) -> str:
    context_block = format_context(corpus)
    sys_prompt = ("<|think|>\n" if enable_thinking else "") + SYSTEM
    messages = [
        {"role": "system", "content": sys_prompt},
        {"role": "user",   "content": f"<CONTEXT>\n{context_block}</CONTEXT>\n\nQuestion: {question}\nAnswer:"},
    ]
    text = processor.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=True,
    )
    inputs = processor(text=text, return_tensors="pt").to(model.device)
    input_len = inputs["input_ids"].shape[-1]
    print(f"Prompt tokens: {input_len}")

    with torch.inference_mode():
        out = model.generate(
            **inputs,
            max_new_tokens=2048,
            do_sample=True,
            temperature=1.0, top_p=0.95, top_k=64,
        )

    raw = processor.decode(out[0][input_len:], skip_special_tokens=False)
    return processor.parse_response(raw)["content"]

# Usage
corpus = load_corpus(["./reports/q3_results.pdf", "./reports/q4_results.pdf"])
print(ask_text("What was the revenue in Q3 vs Q4?"))
print(ask_text("Recompute the NPV given the discount rate stated.", enable_thinking=True))
```

---

## 7. Querying PDFs — image path (scanned / handwritten)

Requires `AutoModelForImageTextToText`. Use `do_sample=False` (greedy) for extraction — more deterministic.

### 7.1 Single PDF

```python
def ask_pdf_images(pdf_path: str, question: str, dpi: int = 200) -> str:
    pages = pdf_to_images(pdf_path, dpi=dpi)
    name = Path(pdf_path).name
    print(f"  Rasterised {len(pages)} pages from {name}")

    content = []
    for i, img in enumerate(pages):
        content.append({"type": "text",  "text": f"[Page {i+1}]"})
        content.append({"type": "image", "image": img})
    content.append({"type": "text", "text": question})

    messages = [
        {"role": "system", "content":
            "You are an expert at reading handwritten documents and certificates. "
            "Extract all visible information accurately."},
        {"role": "user", "content": content},
    ]

    inputs = processor.apply_chat_template(
        messages, tokenize=True, return_dict=True,
        return_tensors="pt", add_generation_prompt=True,
    ).to(model.device)

    input_len = inputs["input_ids"].shape[-1]
    print(f"  Prompt tokens: {input_len}")

    with torch.inference_mode():
        out = model.generate(
            **inputs,
            max_new_tokens=2048,
            do_sample=False,   # greedy for OCR/extraction
        )

    return processor.decode(out[0][input_len:], skip_special_tokens=True)

# Usage
result = ask_pdf_images(
    "./certificates/4266 IZARO.pdf",
    "Extract all information from this certificate and return it as JSON."
)
print(result)
```

### 7.2 Cross-referencing multiple PDFs in one prompt (32 GB GPU)

With enough VRAM you can load all documents as images into a single prompt — the model sees everything at once and can reason across documents directly:

```python
def cross_reference_pdfs(pdf_paths: list[str], question: str, dpi: int = 200) -> str:
    content = []

    for pdf_path in pdf_paths:
        name = Path(pdf_path).name
        pages = pdf_to_images(pdf_path, dpi=dpi)
        print(f"  {name}: {len(pages)} pages")

        content.append({"type": "text", "text": f"\n=== Document: {name} ==="})
        for i, img in enumerate(pages):
            content.append({"type": "text",  "text": f"[Page {i+1}]"})
            content.append({"type": "image", "image": img})

    content.append({"type": "text", "text": question})

    messages = [
        {"role": "system", "content":
            "You are an expert at reading handwritten fishing certificates. "
            "You will be shown multiple documents. Read each one carefully and "
            "answer questions by cross-referencing all of them."},
        {"role": "user", "content": content},
    ]

    inputs = processor.apply_chat_template(
        messages, tokenize=True, return_dict=True,
        return_tensors="pt", add_generation_prompt=True,
    ).to(model.device)

    input_len = inputs["input_ids"].shape[-1]
    print(f"Prompt tokens: {input_len}")
    print(f"VRAM after tokenisation: {torch.cuda.memory_allocated()/1e9:.2f} GB")

    with torch.inference_mode():
        out = model.generate(
            **inputs,
            max_new_tokens=4096,
            do_sample=False,
        )

    return processor.decode(out[0][input_len:], skip_special_tokens=True)

# Usage
pdfs = [
    "./certificates/4266 IZARO.pdf",
    "./certificates/4355 PLAYA DE ANZORAS SEY.pdf",
]

result = cross_reference_pdfs(pdfs, """
Analyse all documents and:
1. Extract each document into a JSON object with all readable fields.
2. Cross-reference them: do vessel names, dates, species, quantities and
   certificate numbers match or conflict?
3. List any discrepancies, missing fields, or inconsistencies found.
Return the JSON extractions first, then the cross-reference analysis.
""")
print(result)
```

### 7.3 Two-stage cross-reference (8 GB GPU workaround)

On 8 GB VRAM you can't fit multiple PDFs as images in one prompt. Extract each document individually first, then cross-reference the extracted JSON with text-only inference:

```python
import json

def extract_pdf_to_json(pdf_path: str, dpi: int = 200) -> dict:
    """Stage 1: extract one PDF at a time using the vision model."""
    raw = ask_pdf_images(
        pdf_path,
        "Extract ALL information into a JSON object. Include every readable field: "
        "vessel name, dates, catch species, quantities, fishing zones, signatures, "
        "certificate numbers, etc. Return ONLY valid JSON, no explanation.",
        dpi=dpi,
    )
    try:
        clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        return {"source": pdf_path, "data": json.loads(clean)}
    except json.JSONDecodeError:
        return {"source": pdf_path, "data": raw}   # raw text fallback


def cross_reference_json(extractions: list[dict], question: str) -> str:
    """Stage 2: cross-reference using text-only inference — no images, low VRAM."""
    context = ""
    for e in extractions:
        name = Path(e["source"]).name
        data = json.dumps(e["data"], indent=2) if isinstance(e["data"], dict) else e["data"]
        context += f"\n\n--- Document: {name} ---\n{data}"

    messages = [
        {"role": "system", "content":
            "You are an expert document analyst specialising in fishing certificate compliance. "
            "Answer questions by cross-referencing the structured data provided."},
        {"role": "user", "content": f"<DOCUMENTS>{context}\n</DOCUMENTS>\n\n{question}"},
    ]

    text = processor.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=True,
    )
    inputs = processor(text=text, return_tensors="pt").to(model.device)
    input_len = inputs["input_ids"].shape[-1]
    print(f"Cross-reference prompt tokens: {input_len}")

    with torch.inference_mode():
        out = model.generate(
            **inputs, max_new_tokens=2048,
            do_sample=True, temperature=1.0, top_p=0.95, top_k=64,
        )

    return processor.decode(out[0][input_len:], skip_special_tokens=True)


# Usage
pdfs = [
    "./certificates/4266 IZARO.pdf",
    "./certificates/4355 PLAYA DE ANZORAS SEY.pdf",
]

# Stage 1 — extract each PDF individually
extractions = []
for pdf in pdfs:
    print(f"\nExtracting: {Path(pdf).name} ...")
    result = extract_pdf_to_json(pdf)
    extractions.append(result)
    print(json.dumps(result["data"], indent=2) if isinstance(result["data"], dict) else result["data"])

# Stage 2 — cross-reference (text only, cheap on VRAM)
print("\n=== CROSS-REFERENCE ANALYSIS ===")
answer = cross_reference_json(extractions, """
Compare these documents and answer:
1. Do the vessel names match across documents?
2. Are the fishing dates consistent or overlapping?
3. Do the species and quantities align between certificates?
4. Are there any discrepancies, missing fields, or suspicious inconsistencies?
5. Are the certificate numbers and signatures present and consistent?
""")
print(answer)
```

---

## 8. Strategy by GPU

| Scenario | Model | Class | Path | Approach |
|---|---|---|---|---|
| 8 GB, digital PDF | E2B 4-bit | `AutoModelForCausalLM` | Text extraction | Single prompt |
| 8 GB, scanned/handwritten | E2B 4-bit | `AutoModelForImageTextToText` | Images per PDF | Two-stage cross-ref |
| 32 GB, best quality | E4B bf16 or 31B 4-bit | `AutoModelForImageTextToText` | Images | Single prompt, all docs |

---

## 9. Example questions to try

| Task | Prompt | `do_sample` |
|---|---|---|
| Summary | "Give a 5-bullet executive summary with [source, p.] citations." | `True` |
| JSON extraction | "Extract all information as JSON. Return ONLY valid JSON." | `False` |
| Comparison table | "Compare document A and B on X. Output a Markdown table." | `False` |
| Cross-reference | "Do vessel names and dates match across all documents? List discrepancies." | `False` |
| Compliance check | "Are all required fields present and consistent across certificates?" | `False` |
| Deep reasoning | *(enable_thinking=True)* "Given X and Y, compute Z." | `True` |
| Hallucination probe | "What does the document say about [thing not in it]?" → should say "Not found." | `False` |

---

## 10. Handling large PDFs and many documents

### Token budget awareness

Each page image at DPI 200 uses roughly 560–1120 tokens depending on content density. With a 128 K context (E2B/E4B):

- At 560 tokens/page → ~220 pages max (minus prompt overhead)
- At 1120 tokens/page → ~110 pages max
- Always leave ~4 K tokens headroom for system prompt + question + answer

### RAG for large text corpora

When the text extraction path is used and documents exceed the context window:

```python
# pip install sentence-transformers faiss-cpu
from sentence_transformers import SentenceTransformer
import numpy as np, faiss

def build_rag_index(corpus: list[dict]):
    embedder = SentenceTransformer("BAAI/bge-small-en-v1.5")
    emb = embedder.encode([c["text"] for c in corpus], normalize_embeddings=True)
    index = faiss.IndexFlatIP(emb.shape[1])
    index.add(np.asarray(emb, dtype="float32"))
    return embedder, index

def retrieve(question: str, corpus, embedder, index, k: int = 6) -> list[dict]:
    q = embedder.encode([question], normalize_embeddings=True).astype("float32")
    _, idx = index.search(q, k)
    return [corpus[i] for i in idx[0]]

# Build index once, query many times
embedder, index = build_rag_index(corpus)
relevant = retrieve("What is the total catch weight?", corpus, embedder, index)
print(ask_text("What is the total catch weight?", relevant))
```

---

## 11. Known gotchas

| Issue | Fix |
|---|---|
| `AttributeError: hf_device_map` | Not a reliable attribute on `Gemma4ForConditionalGeneration`. Use `model.get_memory_footprint()` and `torch.cuda.memory_allocated()` instead |
| `ValueError: Some modules dispatched on CPU` | Use `device_map="cuda:0"` instead of `"auto"`. With tight VRAM, `"auto"` tries a CPU+GPU split that bitsandbytes 4-bit rejects |
| Text extraction returns only page numbers | Your PDF is scanned or handwritten — switch to the image path |
| Model IDs are case-sensitive | `google/gemma-4-E2B-it` not `e2b-it` |
| `AutoModelForCausalLM` rejects image inputs | Switch to `AutoModelForImageTextToText` when passing page images |
| Thought blocks degrade multi-turn quality | Never feed `<\|channel\|>thought…<channel\|>` back into history; use `processor.parse_response(raw)["content"]` |
| JSON output wrapped in markdown fences | Strip with `.removeprefix("```json").removeprefix("```").removesuffix("```").strip()` |
| OOM during inference (not loading) | Reduce `max_new_tokens`, lower DPI, or process fewer pages per call |
| Two-stage Stage 2 crashes on vision path | Pass `use_vision=False` to `generate()` in `cross_reference_json()` and `ask_text_pdfs()` — Stage 2 is always text-only |
| System message format in multimodal prompts | When content is a list of blocks, system must also be a list: `[{"type": "text", "text": SYSTEM}]` not a plain string |

---

## 12. Complete reference script — `gemma4_pdf_qa.py`

```python
"""
Gemma 4 PDF QA — complete reference script.
Supports text extraction (digital PDFs) and image path (scanned/handwritten).
Tested on: RTX 5090 32 GB (E4B bf16) and RTX 4060 8 GB (E2B 4-bit).
"""
import gc, json, torch, fitz
from pathlib import Path
from io import BytesIO
from PIL import Image
from transformers import (
    AutoProcessor,
    AutoModelForCausalLM,
    AutoModelForImageTextToText,
    BitsAndBytesConfig,
)

# ── Config ────────────────────────────────────────────────────────────────────
VRAM_GB      = torch.cuda.get_device_properties(0).total_memory / 1e9
USE_IMAGES   = True     # False = text extraction path (digital PDFs only)
DPI          = 200

if VRAM_GB >= 24:
    MODEL_ID     = "google/gemma-4-E4B-it"
    ENABLE_QUANT = False   # run bf16 on 32 GB
else:
    MODEL_ID     = "google/gemma-4-E2B-it"
    ENABLE_QUANT = True    # 4-bit NF4 on 8 GB

print(f"GPU VRAM  : {VRAM_GB:.1f} GB")
print(f"Model     : {MODEL_ID}")
print(f"Quantized : {ENABLE_QUANT}")
print(f"Mode      : {'image' if USE_IMAGES else 'text extraction'}")

# ── Load ──────────────────────────────────────────────────────────────────────
gc.collect(); torch.cuda.empty_cache()

bnb = BitsAndBytesConfig(
    load_in_4bit=True, bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_quant_storage=torch.bfloat16,
) if ENABLE_QUANT else None

processor  = AutoProcessor.from_pretrained(MODEL_ID)
ModelClass = AutoModelForImageTextToText if USE_IMAGES else AutoModelForCausalLM

load_kwargs = dict(
    device_map="cuda:0",   # ⚠️ NOT "auto" — causes ValueError with bitsandbytes
    dtype="auto",
    attn_implementation="sdpa",
)
if ENABLE_QUANT:
    load_kwargs["quantization_config"] = bnb
else:
    load_kwargs["torch_dtype"] = torch.bfloat16

model = ModelClass.from_pretrained(MODEL_ID, **load_kwargs)
print(f"Footprint : {model.get_memory_footprint()/1e9:.2f} GB")
print(f"VRAM used : {torch.cuda.memory_allocated()/1e9:.2f} GB")

# ── PDF helpers ───────────────────────────────────────────────────────────────
def pdf_to_images(path: str, dpi: int = DPI) -> list[Image.Image]:
    pages = []
    with fitz.open(path) as doc:
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        for page in doc:
            pix = page.get_pixmap(matrix=mat, alpha=False)
            pages.append(Image.open(BytesIO(pix.tobytes("png"))))
    return pages

def extract_text(path: str) -> list[dict]:
    with fitz.open(path) as doc:
        return [{"source": path, "page": i+1, "text": p.get_text("text")}
                for i, p in enumerate(doc)]

def format_context(chunks: list[dict], max_chars: int = 60_000) -> str:
    out, used = [], 0
    for c in chunks:
        header = f"--- [source: {Path(c['source']).name}, p. {c['page']}] ---\n"
        body = c["text"].strip() + "\n\n"
        if used + len(header) + len(body) > max_chars: break
        out.append(header + body); used += len(header) + len(body)
    return "".join(out)

# ── Core generate ─────────────────────────────────────────────────────────────
def generate(messages, max_new_tokens=2048, greedy=False, use_vision=True) -> str:
    # use_vision=False forces text path even when USE_IMAGES=True (e.g. Stage 2 cross-ref)
    if USE_IMAGES and use_vision:
        inputs = processor.apply_chat_template(
            messages, tokenize=True, return_dict=True,
            return_tensors="pt", add_generation_prompt=True,
        ).to(model.device)
    else:
        text = processor.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True,
        )
        inputs = processor(text=text, return_tensors="pt").to(model.device)

    input_len = inputs["input_ids"].shape[-1]
    print(f"Prompt tokens: {input_len}")

    gen_kwargs = dict(max_new_tokens=max_new_tokens, do_sample=not greedy)
    if not greedy:
        gen_kwargs.update(temperature=1.0, top_p=0.95, top_k=64)

    with torch.inference_mode():
        out = model.generate(**inputs, **gen_kwargs)

    return processor.decode(out[0][input_len:], skip_special_tokens=True)

# ── High-level helpers ────────────────────────────────────────────────────────
SYSTEM = (
    "You are an expert document analyst. "
    "Answer ONLY using the provided documents. "
    "Cite sources as [source: filename, p. N]. "
    "If the answer is not available, say 'Not found in the provided documents.'"
)

def ask_images(pdf_paths: list[str], question: str) -> str:
    """Single-prompt multi-PDF query via vision tower (32 GB recommended)."""
    content = []
    for path in pdf_paths:
        pages = pdf_to_images(path)
        print(f"  {Path(path).name}: {len(pages)} pages")
        content.append({"type": "text", "text": f"\n=== Document: {Path(path).name} ==="})
        for i, img in enumerate(pages):
            content.append({"type": "text",  "text": f"[Page {i+1}]"})
            content.append({"type": "image", "image": img})
    content.append({"type": "text", "text": question})
    messages = [
        {"role": "system", "content": [{"type": "text", "text": SYSTEM}]},  # list required in multimodal context
        {"role": "user",   "content": content},
    ]
    return generate(messages, max_new_tokens=4096, greedy=True)

def ask_text_pdfs(pdf_paths: list[str], question: str, enable_thinking: bool = False) -> str:
    """Text-extraction-based query (digital PDFs only)."""
    corpus = []
    for p in pdf_paths:
        corpus.extend(extract_text(p))
    sys = ("<|think|>\n" if enable_thinking else "") + SYSTEM
    messages = [
        {"role": "system", "content": sys},
        {"role": "user",   "content":
            f"<CONTEXT>\n{format_context(corpus)}</CONTEXT>\n\nQuestion: {question}\nAnswer:"},
    ]
    return generate(messages, max_new_tokens=2048, greedy=False, use_vision=False)

def extract_pdf_to_json(pdf_path: str) -> dict:
    """Two-stage helper: extract one PDF as JSON via vision (8 GB path)."""
    raw = ask_images([pdf_path],
        "Extract ALL information into a JSON object with every readable field. "
        "Return ONLY valid JSON, no explanation.")
    try:
        clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        return {"source": pdf_path, "data": json.loads(clean)}
    except json.JSONDecodeError:
        return {"source": pdf_path, "data": raw}

def cross_reference_json(extractions: list[dict], question: str) -> str:
    """Two-stage helper: cross-reference extracted JSONs via text-only (8 GB path)."""
    context = ""
    for e in extractions:
        name = Path(e["source"]).name
        data = json.dumps(e["data"], indent=2) if isinstance(e["data"], dict) else e["data"]
        context += f"\n\n--- Document: {name} ---\n{data}"
    messages = [
        {"role": "system", "content": [{"type": "text", "text": SYSTEM}]},  # list required in multimodal context
        {"role": "user", "content": f"<DOCUMENTS>{context}\n</DOCUMENTS>\n\n{question}"},
    ]
    return generate(messages, max_new_tokens=2048, greedy=False, use_vision=False)

# ── Main ──────────────────────────────────────────────────────────────────────
CROSS_REF_QUESTION = """
Analyse all documents:
1. Extract each document into a JSON object with all readable fields.
2. Cross-reference them: do vessel names, dates, species, quantities,
   and certificate numbers match or conflict?
3. List any discrepancies, missing fields, or inconsistencies.
"""

if __name__ == "__main__":
    pdfs = [str(p) for p in Path("./pdfs").glob("*.pdf")]
    if not pdfs:
        print("Drop some PDFs into ./pdfs/ and rerun.")
    elif VRAM_GB >= 24 and USE_IMAGES:
        # 32 GB: single prompt, all docs at once
        print(ask_images(pdfs, CROSS_REF_QUESTION))
    elif USE_IMAGES:
        # 8 GB: two-stage
        extractions = []
        for pdf in pdfs:
            print(f"\nExtracting: {Path(pdf).name}")
            extractions.append(extract_pdf_to_json(pdf))
        print("\n=== CROSS-REFERENCE ===")
        print(cross_reference_json(extractions, CROSS_REF_QUESTION))
    else:
        # Text-only path
        print(ask_text_pdfs(pdfs, CROSS_REF_QUESTION))
```

---

## TL;DR

| Decision | 8 GB GPU | 32 GB GPU |
|---|---|---|
| Model | `gemma-4-E2B-it` | `gemma-4-E4B-it` (bf16) or `gemma-4-31B-it` (4-bit) |
| Quantisation | 4-bit NF4 | None needed (or 4-bit for 31B) |
| Model class (images) | `AutoModelForImageTextToText` | `AutoModelForImageTextToText` |
| Model class (text only) | `AutoModelForCausalLM` | `AutoModelForCausalLM` |
| `device_map` | `"cuda:0"` ← never `"auto"` | `"cuda:0"` |
| Scanned/handwritten PDFs | Two-stage: extract → cross-ref | Single prompt, all docs as images |
| Sampling | `do_sample=False` for OCR/extraction, `True` for QA | Same |
| Thinking mode | `enable_thinking=True` only when reasoning > latency | Same |
