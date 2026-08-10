// ─────────────────────────────────────────────────────────────────────
// Retrieval for the source-grounded pipeline.
//
// MVP scoring is deterministic lexical (token overlap with IDF-ish
// weighting) — free, private, offline-testable. `scoreChunks` is the
// seam where a vector scorer (pgvector + embeddings) plugs in later:
// implement VectorScorer, then `hybridRetrieve` blends the two scores.
// See docs/source-grounded-ai.md → Retrieval.
// ─────────────────────────────────────────────────────────────────────
import { tokenize } from "./text";

export interface RetrievableChunk {
  id: string;
  sourceId: string;
  notebookId: string;
  content: string;
  chunkIndex: number;
  page?: number | null;
  /** Human label for citations, e.g. the source title. */
  sourceTitle: string;
}

export interface RetrievalOptions {
  /** Limit results. */
  topK?: number;
  /** Only retrieve from these source ids (empty = all of the notebook). */
  sourceIds?: string[];
  /** Min token-overlap a chunk must have with the query. */
  minOverlap?: number;
}

export interface ScoredChunk extends RetrievableChunk {
  score: number;
  /** Which terms from the query matched (for highlighting). */
  matchedTerms: string[];
}

/** Optional vector-scoring seam (pgvector + embeddings — not in MVP). */
export interface VectorScorer {
  score(queryTerms: string[], chunks: RetrievableChunk[]): Promise<Map<string, number>>;
}

let vectorScorer: VectorScorer | null = null;

/** Register an optional vector scorer (called once at startup if enabled). */
export function setVectorScorer(scorer: VectorScorer | null): void {
  vectorScorer = scorer;
}

/** IDF-ish weight: terms appearing in many chunks are less informative. */
function idfWeights(chunks: RetrievableChunk[]): Map<string, number> {
  const df = new Map<string, number>();
  for (const c of chunks) {
    for (const t of new Set(tokenize(c.content))) df.set(t, (df.get(t) ?? 0) + 1);
  }
  const n = chunks.length || 1;
  const weights = new Map<string, number>();
  for (const [term, count] of df) {
    // log((n+1)/(df+1)) + 1 — standard smooth IDF, keeps common words > 0.
    weights.set(term, Math.log((n + 1) / (count + 1)) + 1);
  }
  return weights;
}

function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

/**
 * Lexical scoring: query tokens × chunk tokens, IDF-weighted, plus a
 * small phrase-order bonus. Pure and deterministic — unit-tested.
 */
export function scoreChunks(
  query: string,
  chunks: RetrievableChunk[],
  opts: RetrievalOptions = {},
): ScoredChunk[] {
  const topK = opts.topK ?? 8;
  const minOverlap = opts.minOverlap ?? 1;
  const weights = idfWeights(chunks);
  const queryTerms = tokenize(query);
  if (queryTerms.length === 0) return [];

  const sourceFilter = opts.sourceIds && opts.sourceIds.length > 0 ? new Set(opts.sourceIds) : null;

  const scored: ScoredChunk[] = [];
  for (const chunk of chunks) {
    if (sourceFilter && !sourceFilter.has(chunk.sourceId)) continue;

    const chunkTerms = tokenize(chunk.content);
    const counts = new Map<string, number>();
    for (const t of chunkTerms) counts.set(t, (counts.get(t) ?? 0) + 1);

    let score = 0;
    let overlap = 0;
    const matched = new Set<string>();
    for (const term of queryTerms) {
      const count = counts.get(term) ?? 0;
      if (count > 0) {
        overlap += 1;
        matched.add(term);
        score += (weights.get(term) ?? 1) * Math.log1p(count);
      }
    }
    if (overlap < minOverlap) continue;

    // Phrase bonus: if the raw query appears in the chunk, boost.
    const raw = query.toLowerCase();
    if (chunk.content.toLowerCase().includes(raw)) score *= 1.6;

    // Length normalization: slight preference for denser chunks.
    score /= Math.sqrt(chunk.content.length / 100 + 1);

    scored.push({ ...chunk, score, matchedTerms: [...matched] });
  }

  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, topK);
}

/**
 * Hybrid retrieval: lexical score, optionally blended with a vector
 * scorer when one is registered. Returns chunks with a 0–1 normalized
 * score (higher = more relevant).
 */
export async function hybridRetrieve(
  query: string,
  chunks: RetrievableChunk[],
  opts: RetrievalOptions = {},
): Promise<ScoredChunk[]> {
  const lexical = scoreChunks(query, chunks, { ...opts, topK: Math.max(opts.topK ?? 8, 12) });
  if (!vectorScorer || lexical.length === 0) return lexical.slice(0, opts.topK ?? 8);

  const vectorScores = await vectorScorer.score(tokenize(query), lexical);
  const maxLex = Math.max(...lexical.map((c) => c.score), 1e-9);
  const maxVec = Math.max(...[...vectorScores.values()], 1e-9);

  const blended = lexical.map((c) => {
    const normLex = c.score / maxLex;
    const normVec = (vectorScores.get(c.id) ?? 0) / maxVec;
    return { ...c, score: 0.5 * normLex + 0.5 * normVec };
  });
  blended.sort((a, b) => b.score - a.score);
  return blended.slice(0, opts.topK ?? 8);
}

/** Deterministic lexical similarity between two texts (0–1) — used by
 *  the cache-eviction and citation checks. */
export function lexicalSimilarity(a: string, b: string): number {
  const ta = tokenize(a);
  const tb = tokenize(b);
  if (ta.length === 0 || tb.length === 0) return 0;
  const setB = new Set(tb);
  const hits = ta.filter((t) => setB.has(t)).length;
  const va = new Set(ta);
  const vB = new Set(tb);
  const inter = [...va].filter((t) => vB.has(t)).length;
  return (hits / ta.length + (2 * inter) / (va.size + vB.size)) / 2;
}

export { cosineSimilarity };
