# Source-Grounded AI Engine (NotebookLM-style)

StudyFlow AI's AI system works **primarily from the user's own study material**:
user sources → private knowledge base → retrieval → grounded AI → citations → study transformations.
This is an independent implementation of the product concept — not a copy of any
proprietary product.

## Architecture

```
USER SOURCE (paste / PDF / DOCX / TXT / MD)
   → VALIDATION (type, size, empty/malformed)
   → TEXT EXTRACTION (local, deterministic; PDF page markers preserved)
   → CLEANING (normalize whitespace, strip control chars)
   → CHUNKING (paragraph/sentence-aware, overlapping, char-offset tracked)
   → STORE (source row + chunk rows, source versioned)
   → SEARCHABLE KNOWLEDGE BASE

QUESTION
   → QUERY UNDERSTANDING (mode, source filters)
   → RETRIEVE (keyword scoring + metadata filter; vector scorer is a plug-in seam)
   → RERANK + BUILD CONTEXT (numbered excerpt blocks, untrusted-data fence)
   → GENERATE (provider orchestrator, task-tiered model routing)
   → VALIDATE (structured schemas; drop invalid quiz/flashcard items)
   → CITE (citation markers checked against the context actually sent)
   → RESPONSE (answer + citations + follow-ups)
```

## Provider abstraction

`src/lib/ai/orchestrator.ts` — `AIProviderManager`.

- **Task tiers** (routed by feature, configurable in one place):
  - `simple` → cheapest tier (title, tagging, classification, short summaries)
  - `standard` → default (detailed summaries, flashcards, quizzes, explanations)
  - `complex` → strongest (multi-source synthesis, study planning, comparisons)
- **Free-first priority**: local deterministic processing → free-tier provider →
  paid provider only when necessary and authorized.
- **Failover**: `AI_PROVIDER_ORDER` env (e.g. `openai,anthropic`); on provider
  failure, try the next in order; never surface internal errors to users.
- **No-API fallback**: the app never becomes unusable without a provider key —
  chunking, search, keyword highlighting, document stats, and source linking are
  deterministic and local.

## Retrieval

MVP is a **deterministic lexical scorer** (token-overlap with IDF-ish weighting) —
free, private, offline-testable, and genuinely useful for study material
(definitions, terms, page-level lookups). Metadata filtering (selected sources)
is applied before scoring. The `ScoreChunks` interface is the seam where a
vector scorer (pgvector + embeddings) plugs in later; the spec for that upgrade:

1. `CREATE EXTENSION vector;` add `embedding vector(384|1536)` to `source_chunks`,
   plus an HNSW index.
2. Add an embedding provider (`local` via transformers.js MiniLM — free — or
   `openai` text-embedding-3-small).
3. Add a `vectorScore` function to `retrieval.ts`; blend `score = 0.5·keyword +
   0.5·vector` in `hybridRetrieve`.

## Citations & grounding

- Context is passed to the model as numbered excerpt blocks with `[n]` markers.
- The system prompt enforces: cite only block numbers actually present; never
  invent page numbers, quotations, or source names.
- **Post-generation validation**: every `[n]` in the answer is checked against the
  sent context; markers that don't resolve are stripped and logged.
- **Source-only mode**: prompt-level strictness ("answer only from the excerpts;
  if not found, say so") + citation validation. Claims with no citation in
  source-only mode are flagged in the response metadata.

## Prompt-injection defense

All uploaded source text is **untrusted data**. Chunks are wrapped in a fence
(`<untrusted_source n>...</untrusted_source>`) with explicit instructions that
their content is data, never instructions. System instructions are always
re-asserted after the source block.

## Privacy & authorization

Every query path loads sources with `userId = session.user.id` — notebooks are
isolated per user. No cross-user context is ever mixed. `sourceIds` supplied by
the client are re-checked against the user's own notebook rows (never trusted by
ID alone).

## Cost model

| Item | Approach |
| --- | --- |
| AI actions | Existing master meter (`usage` table, `ai_actions`), atomic server-side |
| Notifications/notebooks | `notebooks` / `sources` lifetime buckets in the `usage` table |
| Request log | `ai_requests` row per call (tokens, latency, estimated cost) |
| Model routing | simple tasks never hit the strongest model |
| Retrieval | top-k context (max ~2,400 tokens), never whole documents |
| Cache | `ai_cache` table keyed by notebook + source versions + question + mode; invalidated when a source version changes |
| Limits | `plans.ts` `maxInputTokensPerGeneration`, free tier 20 AI actions/mo |

## MVP scope (this implementation)

- Notebooks + sources + chunks schema and migration (no vector column yet).
- Extraction: pasted text, TXT, Markdown, PDF (pdf-parse, page markers), DOCX (mammoth).
- Deterministic chunking with offsets; lexical retrieval with source filtering.
- Grounded chat (streaming) with citations, source-only + study modes.
- Actions: summarize (short/detailed/exam), explain (beginner/intermediate/advanced),
  flashcards, quiz, study guide, FAQ, extract, outline, compare, mind map.
- Response cache, metering + request logging wired in.
- Notebook UI (list, detail, sources panel, chat, action results) in the glass design system.

Deliberately deferred (documented, seams exist): semantic embeddings/vector
search, audio overview, admin provider config UI, provider health dashboard.
