// ─────────────────────────────────────────────────────────────────────
// Deterministic, local text processing — the free-first foundation of
// the source-grounded AI pipeline. No AI provider is needed for any of
// this: cleaning, page detection, and chunking run in pure JS and are
// unit-tested. Chunks carry char offsets + page numbers so citations
// can point back into the original material.
// ─────────────────────────────────────────────────────────────────────

export interface TextChunk {
  chunkIndex: number;
  content: string;
  charStart: number;
  charEnd: number;
  /** 1-based page from the source's form-feed markers, when known. */
  page?: number;
}

export const DEFAULT_MAX_CHARS = 1400;
export const DEFAULT_OVERLAP_CHARS = 150;
export const MAX_CHUNKS = 500;

/** Normalize a raw extracted text: line endings, control characters
 *  (keeping \n, \t and \f page markers), trailing spaces, blank lines. */
export function cleanText(raw: string): string {
  return raw
    .replace(/\r\n?/g, "\n")
    // Control chars except \n \t \f (form feed = page marker).
    .replace(/[\u0000-\u0008\u000b\u000e-\u001f\u007f]/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

interface Span {
  start: number;
  end: number;
  text: string;
}

function pageStarts(text: string): Array<{ start: number; page: number }> {
  const map: Array<{ start: number; page: number }> = [];
  let page = 1;
  let searchFrom = 0;
  while (true) {
    map.push({ start: searchFrom, page });
    const idx = text.indexOf("\f", searchFrom);
    if (idx === -1) break;
    searchFrom = idx + 1;
    page += 1;
  }
  return map;
}

function pageForOffset(
  offset: number,
  pages: Array<{ start: number; page: number }>,
): number | undefined {
  let found: number | undefined;
  for (const seg of pages) {
    if (seg.start <= offset) found = seg.page;
    else break;
  }
  return found;
}

/** Split text into paragraph spans (blank-line or page-break
 *  separated; form feeds never become paragraph content). */
function paragraphs(text: string): Span[] {
  const out: Span[] = [];
  const re = /\n\s*\n|\f/g;
  let start = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    const slice = text.slice(start, m.index);
    const content = slice.trim();
    if (content) {
      const leading = slice.search(/\S/);
      out.push({ start: start + leading, end: m.index, text: content });
    }
    start = m.index + m[0].length;
  }
  const tail = text.slice(start).trim();
  if (tail) {
    const leading = text.slice(start).search(/\S/);
    out.push({ start: start + leading, end: text.length, text: tail });
  }
  return out;
}

/** Split a span into sentence spans (naive but adequate for chunking). */
function sentences(span: Span): Span[] {
  const out: Span[] = [];
  const re = /[^.!?\n]+[.!?]+["')\]]*|[^.!?\n]+$/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(span.text))) {
    const content = m[0].trim();
    if (!content) continue;
    const leading = m[0].search(/\S/);
    out.push({
      start: span.start + m.index + leading,
      end: span.start + m.index + m[0].length,
      text: content,
    });
  }
  return out;
}

/** Hard-split an over-long span at word boundaries. */
function hardSplit(text: string, maxChars: number): string[] {
  const words = text.split(/\s+/).filter(Boolean);
  const out: string[] = [];
  let cur = "";
  for (const word of words) {
    if (cur && cur.length + 1 + word.length > maxChars) {
      out.push(cur);
      cur = word;
    } else {
      cur = cur ? `${cur} ${word}` : word;
    }
  }
  if (cur) out.push(cur);
  return out;
}

export interface ChunkOptions {
  maxChars?: number;
  overlapChars?: number;
  maxChunks?: number;
}

/**
 * Chunk cleaned text for retrieval.
 *
 * Strategy: pack paragraphs greedily up to maxChars; split over-long
 * paragraphs by sentence, then hard-split at word boundaries. Each chunk
 * after the first re-includes a short overlap tail from the previous one
 * so retrieval doesn't lose context at boundaries. charStart/charEnd are
 * offsets into the CLEANED text; page is inferred from form-feed markers.
 */
export function chunkText(text: string, opts: ChunkOptions = {}): TextChunk[] {
  const maxChars = opts.maxChars ?? DEFAULT_MAX_CHARS;
  const overlap = opts.overlapChars ?? DEFAULT_OVERLAP_CHARS;
  const maxChunks = opts.maxChunks ?? MAX_CHUNKS;

  const cleaned = cleanText(text);
  if (!cleaned) return [];
  const pages = pageStarts(cleaned);

  const chunks: TextChunk[] = [];
  let buffer: string[] = [];
  let bufferStart = 0;
  let overlapTail: Span | null = null;

  const flush = () => {
    if (buffer.length === 0) return;
    const content = buffer.join("\n");
    chunks.push({
      chunkIndex: chunks.length,
      content,
      charStart: bufferStart,
      charEnd: bufferStart + content.length,
      page: pageForOffset(bufferStart, pages),
    });
    if (overlap > 0 && chunks.length < maxChunks) {
      const tailRaw = content.slice(-overlap);
      const cut = tailRaw.search(/\S/);
      if (cut >= 0) {
        overlapTail = {
          start: bufferStart + content.length - overlap + cut,
          end: bufferStart + content.length,
          text: tailRaw.slice(cut).trim(),
        };
      } else {
        overlapTail = null;
      }
    }
    buffer = [];
  };

  const push = (span: Span) => {
    if (buffer.length === 0) {
      if (overlapTail) {
        buffer = [overlapTail.text];
        bufferStart = overlapTail.start;
        overlapTail = null;
      } else {
        bufferStart = span.start;
      }
    }
    buffer.push(span.text);
  };

  for (const para of paragraphs(cleaned)) {
    if (buffer.length > 0 && buffer.join("\n").length + para.text.length + 1 > maxChars) {
      flush();
    }
    if (para.text.length <= maxChars) {
      push(para);
      continue;
    }
    // Over-long paragraph: split by sentence.
    for (const sent of sentences(para)) {
      if (sent.text.length <= maxChars) {
        if (buffer.length > 0 && buffer.join("\n").length + sent.text.length + 1 > maxChars) {
          flush();
        }
        push(sent);
        continue;
      }
      // Still over-long: hard word-boundary split.
      for (const piece of hardSplit(sent.text, maxChars)) {
        if (buffer.length > 0 && buffer.join("\n").length + piece.length + 1 > maxChars) {
          flush();
        }
        const leading = sent.text.indexOf(piece);
        push({ start: sent.start + leading, end: sent.start + leading + piece.length, text: piece });
      }
    }
  }
  flush();

  return chunks.slice(0, maxChunks);
}

/** Simple tokenizer for scoring: lowercase, split on non-word chars. */
export function tokenize(text: string): string[] {
  return text.toLowerCase().match(/[a-z0-9']+/g) ?? [];
}

export function wordCount(text: string): number {
  return (text.trim().match(/\S+/g) ?? []).length;
}
