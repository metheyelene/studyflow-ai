import { describe, expect, it } from "vitest";

import { chunkText, cleanText, tokenize, wordCount } from "./text";

describe("cleanText", () => {
  it("normalizes CRLF and collapses blank lines", () => {
    const cleaned = cleanText("Line one\r\nLine two\r\n\r\n\r\n\r\nLine three");
    expect(cleaned).toBe("Line one\nLine two\n\nLine three");
  });

  it("removes control characters but keeps tabs, newlines and form feeds", () => {
    const cleaned = cleanText("a\u0000b\u0001c\td\npage1\fpage2");
    expect(cleaned).toBe("abc\td\npage1\fpage2");
  });

  it("trims outer whitespace", () => {
    expect(cleanText("  hello  \n")).toBe("hello");
  });
});

describe("chunkText", () => {
  it("returns [] for empty input", () => {
    expect(chunkText("   ")).toEqual([]);
  });

  it("splits long text into multiple chunks with running indexes", () => {
    const text = Array.from({ length: 40 }, (_, i) => `Paragraph ${i} has some content to pad it out.`).join(
      "\n\n",
    );
    const chunks = chunkText(text, { maxChars: 200, overlapChars: 0 });
    expect(chunks.length).toBeGreaterThan(1);
    chunks.forEach((c, i) => expect(c.chunkIndex).toBe(i));
    expect(chunks[0].charStart).toBe(0);
    expect(chunks[chunks.length - 1].charEnd).toBeLessThanOrEqual(text.length);
  });

  it("respects the maxChars ceiling", () => {
    const text = "word ".repeat(500);
    const chunks = chunkText(text, { maxChars: 100, overlapChars: 0 });
    for (const c of chunks) {
      expect(c.content.length).toBeLessThanOrEqual(100);
    }
  });

  it("adds overlap tails so boundaries keep context", () => {
    const text = Array.from({ length: 20 }, (_, i) => `Sentence block number ${i} with enough words to matter.`).join(
      "\n\n",
    );
    const chunks = chunkText(text, { maxChars: 150, overlapChars: 40 });
    if (chunks.length > 1) {
      const prev = chunks[0].content;
      const next = chunks[1].content;
      // The next chunk begins with a tail drawn from the previous one.
      expect(next.length).toBeLessThan(150);
      expect(prev).toContain(next.slice(0, 20));
    }
  });

  it("attributes page numbers from form-feed markers", () => {
    const page1 = "The first page of content.\n\nMore first page text.";
    const page2 = "The second page of content.";
    const chunks = chunkText(`${page1}\f${page2}`, { maxChars: 60, overlapChars: 0 });
    expect(chunks[0].page).toBe(1);
    expect(chunks[chunks.length - 1].page).toBe(2);
  });

  it("splits over-long single paragraphs by sentence then hard-cuts", () => {
    const long = "This is the first sentence of a very long paragraph. ".repeat(60);
    const chunks = chunkText(long, { maxChars: 120, overlapChars: 0 });
    expect(chunks.length).toBeGreaterThan(1);
    for (const c of chunks) {
      expect(c.content.length).toBeLessThanOrEqual(120);
      expect(c.content.length).toBeGreaterThan(0);
    }
  });

  it("keeps char offsets within the cleaned text bounds", () => {
    const text = "Alpha beta gamma.\n\nDelta epsilon zeta.";
    const chunks = chunkText(text, { maxChars: 100, overlapChars: 0 });
    for (const c of chunks) {
      expect(c.charStart).toBeGreaterThanOrEqual(0);
      expect(c.charEnd).toBeLessThanOrEqual(text.length);
      expect(c.charEnd).toBeGreaterThan(c.charStart);
    }
  });
});

describe("tokenize / wordCount", () => {
  it("tokenizes lowercase word tokens", () => {
    expect(tokenize("The Quick-Brown Fox, 42!")).toEqual(["the", "quick", "brown", "fox", "42"]);
  });

  it("counts words", () => {
    expect(wordCount("one two  three\nfour")).toBe(4);
    expect(wordCount("")).toBe(0);
  });
});
