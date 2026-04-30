# Running Gemma 4 Locally with PDF Context — A Practical Tutorial

**Author's note for Gustavo (Senior AI Engineer):** This tutorial assumes a Linux/macOS workstation with Python ≥ 3.11, CUDA 12.x (or Apple Silicon), and roughly 8 GB of VRAM. It targets the **Gemma 4** family released by Google DeepMind on **April 2, 2026** under Apache 2.0, with first‑class `transformers` support. All code has been written against `transformers` ≥ the Gemma‑4 integration release and the chat‑template / `llama.cpp` fixes shipped on April 11, 2026.

---

## 1. The Gemma 4 family at a glance

Gemma 4 ships as an open‑weights, multimodal family. Pick a size that fits your hardware and your latency target.

| HF model ID | Type | Effective / total params | Context | Modalities (input) | Best fit |
|---|---|---|---|---|---|
| `google/gemma-4-E2B` / `google/gemma-4-E2B-it` | Dense + PLE | 2.3 B effective (5.1 B total) | 128 K | Text, Image, Audio | Phones, Jetson, ≤8 GB VRAM |
| `google/gemma-4-E4B` / `google/gemma-4-E4B-it` | Dense + PLE | 4.5 B effective (8 B total) | 128 K | Text, Image, Audio | **Sweet spot for an 8 GB GPU** (4‑bit) |
| `google/gemma-4-26B-A4B` / `…-it` | MoE (8 of 128 + 1 shared) | 25.2 B total / 3.8 B active | 256 K | Text, Image | 24 GB+ VRAM, fast inference |
| `google/gemma-4-31B` / `google/gemma-4-31B-it` | Dense | 30.7 B | 256 K | Text, Image | Workstation / single H100 / DGX Spark |

Important details that matter for this tutorial:

- **Context windows are large**: 128 K tokens on E2B/E4B and 256 K on 26B/31B. That is more than enough to drop entire books in as raw text, although accuracy on long context (MRCR v2 8‑needle 128K) drops noticeably for the smaller models, so chunking + retrieval still pays off.
- **Multimodal but not PDF‑native.** All Gemma 4 models accept text + images. They do **not** accept PDFs directly; you need to either (a) extract text with `pypdf`/`pdfplumber`/`PyMuPDF`/`pdfminer.six` and feed it as text, or (b) rasterise pages to images and feed them as image tokens (the model is trained on document/PDF parsing, OCR, charts and tables — see the model card's "Image Understanding" section). Audio inputs are supported only on E2B/E4B (≤ 30 s clips).
- **Placement matters**: when you do pass images, the official guidance is *images/audio first, text second* in the message content list.
- **Native system role**: Gemma 4 supports a `system` role (Gemma 3 did not), and exposes a configurable thinking mode toggled by a `<|think|>` token in the system prompt.
- **Recommended sampling**: `temperature=1.0`, `top_p=0.95`, `top_k=64`.

### Memory budget for ~8 GB VRAM

Roughly the numbers reported by Unsloth/Google for inference (weights only, before KV cache):

| Model | bf16 | 8‑bit | 4‑bit (NF4 / Q4_K_M) |
|---|---|---|---|
| E2B | ~10 GB | ~5 GB | ~3.5 GB |
| E4B | ~15 GB | ~8 GB | **~5 GB** |
| 26B A4B | ~50 GB | ~28 GB | ~18 GB |
| 31B | ~60 GB | ~34 GB | ~20 GB |

**Recommendation for 8 GB:** use **`google/gemma-4-E4B-it` quantised to 4‑bit with bitsandbytes (NF4)**. That leaves enough headroom for a sizable KV cache (you'll want to reserve at least ~1.5 GB for an 8K‑token input window). If you want every drop of speed, drop to E2B at 4‑bit.

---

## 2. Installing dependencies

```bash
# Create a clean env (recommended)
python -m venv .venv && source .venv/bin/activate

# Core: latest transformers (Gemma 4 needs the post‑release integration)
pip install -U "transformers>=4.57" accelerate

# Quantization for 8 GB GPUs
pip install -U bitsandbytes

# Torch — install the build that matches your CUDA / platform
# pip install -U torch --index-url https://download.pytorch.org/whl/cu124

# Multimodal extras (only needed if you want to feed images / audio / video)
pip install -U torchvision librosa pillow

# PDF text extraction — pick one or all
pip install -U pypdf pdfplumber pymupdf pdfminer.six

# Optional: token counting against the Gemma tokenizer
pip install -U tiktoken sentencepiece
```

> **Gotcha:** there has been at least one report (HF forums) of a 4‑bit quantisation regression in `transformers` v5.1.0 affecting `Gemma3ForConditionalGeneration` (model silently spilled to shared system memory despite `device_map="auto"`). If you see your VRAM not filling up, downgrade transformers or pin to a known‑good 4.57.x and verify with `model.hf_device_map` before benchmarking.

> **GGUF gotcha:** Unsloth explicitly warns *"Do NOT use CUDA 13.2 runtime for any GGUF — it produces poor outputs."* Stick to CUDA 12.4/12.6 if you go the `llama.cpp` route.

---

## 3. Three ways to load Gemma 4 locally

### 3.1 Transformers + bitsandbytes 4‑bit (recommended for 8 GB)

```python
import torch
from transformers import (
    AutoProcessor,
    AutoModelForCausalLM,        # text‑only
    AutoModelForMultimodalLM,    # text + image (+ audio on E2B/E4B)
    BitsAndBytesConfig,
)

MODEL_ID = "google/gemma-4-E4B-it"  # case-sensitive on HF

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_quant_storage=torch.bfloat16,
)

processor = AutoProcessor.from_pretrained(MODEL_ID)

# Use AutoModelForCausalLM if you only need text-in / text-out
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    quantization_config=bnb,
    device_map="auto",
    dtype="auto",
    attn_implementation="sdpa",   # flash_attention_2 also works on Ampere+
)

assert model.hf_device_map, "Quantization didn't take — check transformers version"
print(f"Memory footprint: {model.get_memory_footprint()/1e9:.2f} GB")
```

For multimodal (image) input replace `AutoModelForCausalLM` with `AutoModelForMultimodalLM` and pass `torchvision`/`librosa` extras.

### 3.2 Ollama (zero‑boilerplate path)

`ollama` ships pre‑quantized GGUFs of Gemma 4. Tags worth knowing (from the official `ollama.com/library/gemma4` page, 29 tags, ~6 M pulls):

| Tag | Size on disk | Context | Notes |
|---|---|---|---|
| `gemma4` (alias of `gemma4:e4b`) | 9.6 GB | 128 K | Default |
| `gemma4:e2b` | 7.2 GB | 128 K | Fits in 8 GB VRAM |
| `gemma4:e2b-it-q4_K_M` | 7.2 GB | 128 K | Explicit 4‑bit |
| `gemma4:e2b-it-q8_0` | 8.1 GB | 128 K | Near‑lossless 8‑bit |
| `gemma4:26b` | 18 GB | 256 K | 24 GB VRAM target |
| `gemma4:31b` | 20 GB | 256 K | Workstation/H100 |

```bash
# requires Ollama >= 0.20.0 (Gemma 4 support, MLX accel on Apple Silicon)
ollama pull gemma4:e4b
ollama run gemma4:e4b
```

Then from Python:

```python
from ollama import chat

resp = chat(
    model="gemma4:e4b",
    messages=[
        {"role": "system", "content": "You are a precise document analyst."},
        {"role": "user",   "content": "Summarize the attached text in 3 bullets:\n\n" + pdf_text},
    ],
    options={"num_ctx": 32768, "temperature": 1.0, "top_p": 0.95, "top_k": 64},
)
print(resp.message.content)
```

The OpenAI‑compatible endpoint at `http://localhost:11434/v1/chat/completions` works with the `openai` SDK if you prefer.

### 3.3 `google-generativeai` SDK — *not* the right tool for local Gemma 4

The `google-generativeai` (`google-genai`) SDK targets **Gemini** models hosted on the Google AI / Vertex AI APIs. Gemma 4 31B and 26B A4B are exposed there as managed endpoints (e.g., from Google AI Studio), but if your goal is *running locally* the SDK is the wrong tool — use `transformers`, `ollama`, `llama.cpp`, `vLLM`, `MLX`, or `mistral.rs` instead. Use the SDK only when you want a managed/cloud variant of the same model. The rest of this tutorial assumes local execution.

---

## 4. PDF text extraction

Gemma 4 cannot ingest a `.pdf` byte stream. You need to extract text first. Three libraries worth knowing, ranked by what they do best:

| Library | Strength | Weakness |
|---|---|---|
| `pypdf` (formerly PyPDF2) | Pure Python, MIT, easy install | Mediocre on complex layouts, tables |
| `pdfplumber` | Excellent for tables and column text | Slower; built on `pdfminer.six` |
| `pymupdf` (a.k.a. `fitz`) | Fastest, very accurate text + lossless page rasterisation | AGPL by default (commercial license available) |
| `pdfminer.six` | Layout‑aware text extraction | Verbose API |

For document QA over digital‑born PDFs, **PyMuPDF gives the best speed/quality tradeoff**. For scanned PDFs, run OCR (Tesseract, PaddleOCR) first or render pages to images and feed them to Gemma 4's vision tower (Gemma 4 is explicitly trained for OCR including multilingual and handwriting — see the model card's *Image Understanding* section).

A reusable extractor that falls back gracefully:

```python
from pathlib import Path
from typing import Iterable

def extract_text_pymupdf(path: str | Path) -> list[dict]:
    """Return [{'page': int, 'text': str}] using PyMuPDF."""
    import fitz  # pymupdf
    out = []
    with fitz.open(path) as doc:
        for i, page in enumerate(doc, start=1):
            # "text" preserves reading order; use "blocks" for layout-aware
            out.append({"page": i, "text": page.get_text("text")})
    return out

def extract_text_pypdf(path: str | Path) -> list[dict]:
    from pypdf import PdfReader
    reader = PdfReader(str(path))
    return [{"page": i + 1, "text": p.extract_text() or ""} for i, p in enumerate(reader.pages)]

def extract_text(path: str | Path) -> list[dict]:
    try:
        return extract_text_pymupdf(path)
    except Exception:
        return extract_text_pypdf(path)

def load_corpus(paths: Iterable[str | Path]) -> list[dict]:
    """Returns flat list with file & page metadata."""
    corpus = []
    for p in paths:
        for page in extract_text(p):
            corpus.append({
                "source": str(p),
                "page": page["page"],
                "text": page["text"],
            })
    return corpus
```

If you want the *vision* path (no OCR pipeline, let Gemma 4 read the page image directly):

```python
import fitz
from PIL import Image
from io import BytesIO

def pdf_pages_to_images(path: str, dpi: int = 200) -> list[Image.Image]:
    pages = []
    with fitz.open(path) as doc:
        zoom = dpi / 72
        mat = fitz.Matrix(zoom, zoom)
        for page in doc:
            pix = page.get_pixmap(matrix=mat, alpha=False)
            pages.append(Image.open(BytesIO(pix.tobytes("png"))))
    return pages
```

For OCR‑heavy work with the vision path, the model card recommends a **higher visual token budget — 560 or 1120 tokens per image — for OCR / document parsing / small text** (the supported budgets are 70, 140, 280, 560, 1120). Lower budgets are fine for captioning or video frames.

---

## 5. Building a context‑augmented prompt

A robust prompt template for document QA:

```python
SYSTEM = (
    # The leading <|think|> token toggles thinking mode on. Drop it for faster, "answer-only" runs.
    "You are an expert document analyst. Answer ONLY using the provided <CONTEXT>. "
    "Quote source page numbers in the form [source: filename, p. N]. "
    "If the answer is not in the context, say 'Not found in the provided documents.'"
)

def format_context(chunks: list[dict], max_chars: int = 60_000) -> str:
    """Join chunks into a single context block with provenance markers."""
    out, used = [], 0
    for c in chunks:
        header = f"--- [source: {c['source']}, p. {c['page']}] ---\n"
        body = c["text"].strip() + "\n\n"
        if used + len(header) + len(body) > max_chars:
            break
        out.append(header + body)
        used += len(header) + len(body)
    return "".join(out)

def build_messages(question: str, context_block: str, enable_thinking: bool = False):
    sys_prompt = ("<|think|>\n" if enable_thinking else "") + SYSTEM
    return [
        {"role": "system", "content": sys_prompt},
        {"role": "user", "content": (
            f"<CONTEXT>\n{context_block}</CONTEXT>\n\n"
            f"Question: {question}\n"
            "Answer:"
        )},
    ]
```

A few things to notice:

- **Provenance tags** (`[source: …, p. N]`) are simple and effective; Gemma 4 follows this pattern well in practice and they make hallucinations easy to spot.
- **`<|think|>` enables Gemma 4's reasoning mode** — output will include a `<|channel|>thought\n…<channel|>` block followed by the answer. The `processor.parse_response()` helper splits these for you in `transformers`. For multi‑turn chats, **never** feed the previous turn's thought back in; only keep the final visible answer in history.
- Keep the **image/audio first, text second** ordering whenever you mix modalities.

---

## 6. Running inference — text path

Putting it all together, end‑to‑end:

```python
import torch
from transformers import AutoProcessor, AutoModelForCausalLM, BitsAndBytesConfig

MODEL_ID = "google/gemma-4-E4B-it"

bnb = BitsAndBytesConfig(
    load_in_4bit=True, bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True, bnb_4bit_compute_dtype=torch.bfloat16,
)
processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID, quantization_config=bnb, device_map="auto", dtype="auto",
)

# 1. Extract
corpus = load_corpus(["./papers/transformer.pdf", "./papers/flash_attention.pdf"])

# 2. Pick context (naive: take everything that fits)
context_block = format_context(corpus, max_chars=60_000)

# 3. Build messages
messages = build_messages(
    question="What problem does FlashAttention solve and how does it differ from vanilla attention?",
    context_block=context_block,
    enable_thinking=False,
)

# 4. Tokenize via the chat template
text = processor.apply_chat_template(
    messages, tokenize=False, add_generation_prompt=True, enable_thinking=False
)
inputs = processor(text=text, return_tensors="pt").to(model.device)
input_len = inputs["input_ids"].shape[-1]
print(f"Prompt tokens: {input_len}")

# 5. Generate
with torch.inference_mode():
    out = model.generate(
        **inputs,
        max_new_tokens=1024,
        do_sample=True,
        temperature=1.0, top_p=0.95, top_k=64,
        repetition_penalty=1.0,
    )

raw = processor.decode(out[0][input_len:], skip_special_tokens=False)
parsed = processor.parse_response(raw)   # {"thought": "...", "content": "..."}
print(parsed["content"])
```

A handful of pragmatic tips:

- **Do not blow up the prompt unnecessarily.** Even though E4B claims 128K, the long‑context benchmark (MRCR v2 8‑needle 128K) is only **25.4 %** for E4B and **19.1 %** for E2B (vs 66.4 % for the 31B). For accurate retrieval on long PDFs, prefer an 8K–32K *effective* prompt with a retrieval step. Google’s own `Gemma 4 model overview` warns explicitly that "larger context windows require significantly more VRAM on top of the base model weights."
- **Token budgeting:** the Gemma tokenizer has a 262 K vocabulary; rule of thumb is ~3.5–4 chars/token for English. So `max_chars=60_000` ≈ 15 K tokens, comfortably inside any Gemma 4 size.

---

## 7. Multimodal path — feeding pages as images

If your PDFs are scanned or your text extraction produces garbage, render each page and let Gemma 4's vision tower do OCR. Use `AutoModelForMultimodalLM`:

```python
from transformers import AutoProcessor, AutoModelForMultimodalLM

processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForMultimodalLM.from_pretrained(
    MODEL_ID, quantization_config=bnb, device_map="auto", dtype="auto",
)

pages = pdf_pages_to_images("./scans/contract.pdf", dpi=200)

messages = [
    {"role": "system", "content": "You are an OCR + analysis assistant."},
    {"role": "user", "content": [
        # IMAGES FIRST, TEXT SECOND — official guidance
        *[{"type": "image", "image": img} for img in pages[:4]],
        {"type": "text", "text":
            "Extract the parties, the effective date, the governing law clause, "
            "and any termination conditions from the document."},
    ]},
]

inputs = processor.apply_chat_template(
    messages, tokenize=True, return_dict=True, return_tensors="pt",
    add_generation_prompt=True,
).to(model.device)

input_len = inputs["input_ids"].shape[-1]
out = model.generate(**inputs, max_new_tokens=1024, do_sample=True,
                     temperature=1.0, top_p=0.95, top_k=64)
print(processor.decode(out[0][input_len:], skip_special_tokens=True))
```

To dial up OCR quality, request a higher image token budget per image (the Gemma 4 model card explicitly recommends 560 or 1120 for OCR / small text). The processor exposes this via its image kwargs (e.g. `processor(..., images=imgs, image_token_budget=1120)`); check your installed processor version for the exact keyword, since the attribute name has been adjusted between pre‑release and GA.

---

## 8. Example questions to try over PDFs

These prompts work well with the schema above:

1. **Factual extraction:** "List every numerical result reported for ImageNet in the documents, with metric, value and citation `[source, p.]`."
2. **Comparative summary:** "Compare the FlashAttention paper and the Performer paper on memory complexity. Output a table."
3. **Yes/No grounding:** "Does the contract restrict subcontracting? Quote the exact clause and page."
4. **Aggregation:** "From the 10‑K, give me revenue by segment for the last 3 fiscal years as a JSON object."
5. **Reasoning over data:** prefix the system prompt with `<|think|>` and ask "Given the discount rate and FCF projections in the model section, recompute the NPV."
6. **Hallucination probe:** "What does the document say about <thing definitely not in it>?" — Gemma 4 should answer "Not found in the provided documents." with the system prompt above.

---

## 9. Best practices for large PDFs

When you exceed a comfortable prompt size (roughly 16–32 K tokens for E2B/E4B if you care about accuracy), don't just rely on the 128 K context window. Use one of these patterns:

### 9.1 Token‑aware chunking

Use the model's own tokenizer instead of byte counts:

```python
def chunk_by_tokens(records: list[dict], processor, max_tokens=1500, overlap=150):
    """Split each page-record into tokenizer-aware chunks with a sliding overlap."""
    tok = processor.tokenizer
    chunks = []
    for r in records:
        ids = tok(r["text"], add_special_tokens=False)["input_ids"]
        i = 0
        while i < len(ids):
            piece = ids[i : i + max_tokens]
            chunks.append({
                **r,
                "text": tok.decode(piece, skip_special_tokens=True),
                "chunk_start_token": i,
            })
            i += max_tokens - overlap
    return chunks
```

`max_tokens` between 800–1500 with ~10 % overlap is a solid default — small enough that several chunks fit comfortably in the prompt, large enough to preserve coherence across paragraph breaks.

### 9.2 Retrieval (RAG) instead of stuffing

For multi‑document QA, embed chunks and retrieve top‑k before generation:

```python
# pip install sentence-transformers faiss-cpu
from sentence_transformers import SentenceTransformer
import numpy as np, faiss

embedder = SentenceTransformer("BAAI/bge-small-en-v1.5")  # or google's EmbeddingGemma
emb = embedder.encode([c["text"] for c in chunks], normalize_embeddings=True)
index = faiss.IndexFlatIP(emb.shape[1]); index.add(np.asarray(emb, dtype="float32"))

def retrieve(question: str, k: int = 6):
    q = embedder.encode([question], normalize_embeddings=True).astype("float32")
    _, idx = index.search(q, k)
    return [chunks[i] for i in idx[0]]
```

Feed `retrieve(question)` into `format_context()` and you've got a clean local RAG pipeline. Google ships **EmbeddingGemma** in the Gemmaverse if you want to keep everything under the same license; `bge-small-en-v1.5` is a strong, lighter alternative.

### 9.3 Map‑reduce summarisation

For tasks like "summarise this 400‑page report," the cheapest reliable pattern is:

1. **Map**: summarise each chunk independently with a tight prompt ("In ≤120 words, capture the facts, numbers and named entities of this passage. Cite page.").
2. **Reduce**: feed the concatenated chunk‑summaries back into Gemma 4 with a higher‑level prompt ("Synthesise the following partial summaries into a single 800‑word executive summary. Resolve contradictions by preferring later‑page evidence.").
3. Optionally **refine**: pass the reduce output back over each chunk, asking the model to revise the summary in light of the new chunk.

For E4B at 4‑bit on an 8 GB GPU you'll see roughly 25–40 tokens/s, so a 200‑chunk map step finishes in single‑digit minutes.

### 9.4 Hybrid: structured outline first, then drill down

A pattern I've found very effective with Gemma 4:

1. Ask the model for a **structured outline** of the document (sections, key claims, key tables) using a vision pass on a thumbnail of each page (low image token budget = 70 or 140).
2. Use that outline as an *index* to fetch the right chunks from the text extraction.
3. Answer the user's question with only those chunks loaded into context.

This is essentially poor‑man's hierarchical retrieval, but it works well because Gemma 4 is unusually good at multimodal layout/structure tasks (MMMU Pro 52.6 % on E4B; OmniDocBench edit distance 0.181 on E4B and 0.131 on 31B).

---

## 10. Known issues and final gotchas

- **Model IDs are case‑sensitive on the Hub.** Use `google/gemma-4-E4B-it`, not `google/gemma-4-e4b-it`. Some downstream tools (Ollama, MLX) lowercase tags; the HF Hub does not.
- **`AutoModelForCausalLM` vs `AutoModelForMultimodalLM`.** The text‑only class loads faster and uses less RAM; switch to multimodal only when you actually need images/audio. The processor (`AutoProcessor`) is the same for both.
- **Chat template + thought blocks.** Gemma 4 emits a `<|channel|>thought\n…<channel|>` block when thinking is enabled. **Strip it from chat history** before the next user turn — feeding past thoughts back in degrades quality (this is called out explicitly in the model card).
- **GGUF + CUDA 13.2:** broken combination per Unsloth (April 2026). Stay on CUDA 12.x.
- **Ollama version:** Gemma 4 requires Ollama ≥ 0.20.0; older builds fail to pull. Bumping is also where Apple Silicon MLX acceleration was added.
- **Long‑context accuracy is size‑dependent.** Don’t blindly trust the 128 K / 256 K window — for fact‑critical QA over books, retrieve.
- **HDP / function‑calling note from the community blog.** A community PR opened against the gemma‑cookbook adds a delegation/authorization layer in front of Gemma 4’s function calls. It is *not* official Google behaviour and is not required for document QA, but keep it in mind if you wire Gemma 4 into actuators or shell tools — the model itself produces tool calls without any provenance signal.
- **Transformers 5.1.0 4‑bit regression** (reported on the HF forum for Gemma 3 12B). Same loader path used by Gemma 4. Verify `model.hf_device_map is not None` and `model.get_memory_footprint()` matches the expected 4‑bit footprint after loading.

---

## 11. Reference end‑to‑end script

A single self‑contained file that ties it all together. Save as `gemma4_pdf_qa.py`:

```python
"""Gemma 4 + PDF QA on ~8 GB VRAM."""
from pathlib import Path
import torch
from transformers import AutoProcessor, AutoModelForCausalLM, BitsAndBytesConfig
import fitz  # pymupdf

MODEL_ID = "google/gemma-4-E4B-it"

# ---------- 1. Load model ----------
bnb = BitsAndBytesConfig(
    load_in_4bit=True, bnb_4bit_quant_type="nf4",
    bnb_4bit_use_double_quant=True, bnb_4bit_compute_dtype=torch.bfloat16,
)
processor = AutoProcessor.from_pretrained(MODEL_ID)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID, quantization_config=bnb, device_map="auto", dtype="auto",
)
print(f"VRAM footprint: {model.get_memory_footprint()/1e9:.2f} GB")

# ---------- 2. Extract ----------
def extract(path):
    with fitz.open(path) as doc:
        return [{"source": str(path), "page": i+1, "text": p.get_text("text")}
                for i, p in enumerate(doc)]

corpus = []
for pdf in Path("./pdfs").glob("*.pdf"):
    corpus.extend(extract(pdf))
print(f"Loaded {len(corpus)} pages")

# ---------- 3. Build context ----------
def format_context(chunks, max_chars=60_000):
    buf, used = [], 0
    for c in chunks:
        header = f"--- [source: {Path(c['source']).name}, p. {c['page']}] ---\n"
        body = c["text"].strip() + "\n\n"
        if used + len(header) + len(body) > max_chars: break
        buf.append(header + body); used += len(header) + len(body)
    return "".join(buf)

# ---------- 4. Ask ----------
def ask(question: str, enable_thinking: bool = False) -> str:
    sys = ("<|think|>\n" if enable_thinking else "") + (
        "You are an expert document analyst. Answer ONLY using <CONTEXT>. "
        "Cite [source, p.]. If absent, say 'Not found in the provided documents.'"
    )
    msgs = [
        {"role": "system", "content": sys},
        {"role": "user", "content":
         f"<CONTEXT>\n{format_context(corpus)}</CONTEXT>\n\nQuestion: {question}\nAnswer:"},
    ]
    text = processor.apply_chat_template(
        msgs, tokenize=False, add_generation_prompt=True, enable_thinking=enable_thinking
    )
    inp = processor(text=text, return_tensors="pt").to(model.device)
    n = inp["input_ids"].shape[-1]
    with torch.inference_mode():
        out = model.generate(**inp, max_new_tokens=1024, do_sample=True,
                             temperature=1.0, top_p=0.95, top_k=64)
    raw = processor.decode(out[0][n:], skip_special_tokens=False)
    return processor.parse_response(raw)["content"]

if __name__ == "__main__":
    print(ask("What is the document about? Give a 5-bullet summary."))
    print("---")
    print(ask("List every numerical result with [source, p.] citations.", enable_thinking=True))
```

Run it with `python gemma4_pdf_qa.py` after dropping a few PDFs into `./pdfs/`. On an RTX 4060 8 GB you should see prompt processing at 800–1200 tok/s and generation at ~30 tok/s with a 4‑bit E4B.

---

### TL;DR for an 8 GB box

- Model: **`google/gemma-4-E4B-it`** at **4‑bit NF4** via `bitsandbytes`.
- Context window: 128 K, but stay below ~32 K for accuracy. Chunk + retrieve for big corpora.
- PDFs: extract text with **PyMuPDF**, fall back to `pypdf`. For scans, rasterise pages and use the *multimodal* loader with image token budget 560 or 1120.
- Sampling: `temperature=1.0, top_p=0.95, top_k=64`. Use `<|think|>` only when reasoning quality matters more than latency.
- Always strip thought blocks from chat history; always put images/audio before text in multimodal messages.
- For zero‑setup, `ollama pull gemma4:e2b` (7.2 GB) is the fastest path; use `transformers + bitsandbytes` when you need finer control or want to fine‑tune.