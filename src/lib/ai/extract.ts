// ─────────────────────────────────────────────────────────────────────
// Source text extraction. Everything here is local and deterministic —
// no AI provider is involved. PDF (pdf-parse) and DOCX (mammoth) are
// lazy-imported so they never enter the client bundle or the cold path
// of unrelated requests. Page markers: PDF pages are joined with \f so
// chunking can attribute citations to page numbers.
// ─────────────────────────────────────────────────────────────────────

export const MAX_SOURCE_BYTES = 25 * 1024 * 1024; // 25 MB
export const MAX_SOURCE_CHARS = 1_500_000; // extraction ceiling (≈ 250k words)

export class SourceExtractionError extends Error {
  constructor(
    message: string,
    public readonly code:
      | "unsupported-format"
      | "too-large"
      | "empty"
      | "malformed"
      | "too-long",
  ) {
    super(message);
    this.name = "SourceExtractionError";
  }
}

export interface ExtractionResult {
  text: string;
  pageCount?: number;
  format: "pasted" | "txt" | "md" | "pdf" | "docx";
}

export const SUPPORTED_FORMATS = [
  ".txt",
  ".md",
  ".markdown",
  ".pdf",
  ".docx",
] as const;

const MIME_HINTS: Array<{ ext: string; mimes: string[] }> = [
  { ext: ".pdf", mimes: ["application/pdf"] },
  { ext: ".docx", mimes: [
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ] },
  { ext: ".txt", mimes: ["text/plain"] },
  { ext: ".md", mimes: ["text/markdown", "text/x-markdown"] },
];

export function formatForFile(filename: string, mimeType?: string): ExtractionResult["format"] | null {
  const lower = filename.toLowerCase();
  const normalize = (ext: string): ExtractionResult["format"] | null => {
    if (ext === ".markdown") return "md";
    const f = ext.slice(1);
    return (["txt", "md", "pdf", "docx"] as const).includes(f as never)
      ? (f as ExtractionResult["format"])
      : null;
  };
  for (const { ext } of MIME_HINTS) {
    if (lower.endsWith(ext)) return normalize(ext);
  }
  if (mimeType) {
    for (const { ext, mimes } of MIME_HINTS) {
      if (mimes.includes(mimeType.toLowerCase())) return normalize(ext);
    }
  }
  return null;
}

/** Validate a file upload before extraction. Throws SourceExtractionError. */
export function validateUpload(filename: string, mimeType: string, sizeBytes: number): void {
  if (sizeBytes === 0) throw new SourceExtractionError("The file is empty.", "empty");
  if (sizeBytes > MAX_SOURCE_BYTES) {
    throw new SourceExtractionError(
      `File is ${(sizeBytes / 1024 / 1024).toFixed(1)} MB — the limit is 25 MB.`,
      "too-large",
    );
  }
  const format = formatForFile(filename, mimeType);
  if (!format) {
    throw new SourceExtractionError(
      `Unsupported format "${filename.split(".").pop() ?? "unknown"}". Supported: ` +
        SUPPORTED_FORMATS.join(", "),
      "unsupported-format",
    );
  }
}

function assertUsable(text: string): string {
  const cleaned = text.trim();
  if (!cleaned) {
    throw new SourceExtractionError(
      "No readable text found in this file (it may be scanned images or empty).",
      "empty",
    );
  }
  if (cleaned.length > MAX_SOURCE_CHARS) {
    throw new SourceExtractionError(
      "This document is too long to index (over ~250,000 words).",
      "too-long",
    );
  }
  return cleaned;
}

/** Extract plain text from an uploaded file. Throws SourceExtractionError. */
export async function extractFile(
  buffer: Buffer,
  filename: string,
  mimeType: string,
): Promise<ExtractionResult> {
  validateUpload(filename, mimeType, buffer.byteLength);
  const format = formatForFile(filename, mimeType) as ExtractionResult["format"];

  switch (format) {
    case "txt":
    case "md": {
      return { text: assertUsable(buffer.toString("utf8")), format };
    }
    case "pdf": {
      const { PDFParse } = await import("pdf-parse");
      const parser = new PDFParse({ data: buffer });
      try {
        const result = await parser.getText();
        // Join pages with form feeds so chunking can attribute page numbers.
        const text = result.pages
          .map((p) => p.text ?? "")
          .join("\f")
          .replace(/\f+/g, "\f");
        return {
          text: assertUsable(text),
          pageCount: result.pages.length,
          format: "pdf",
        };
      } finally {
        await parser.destroy();
      }
    }
    case "docx": {
      const mammoth = await import("mammoth");
      const result = await mammoth.extractRawText({ buffer });
      return { text: assertUsable(result.value), format: "docx" };
    }
    default:
      throw new SourceExtractionError("Unsupported format.", "unsupported-format");
  }
}

/** A pasted-text source needs only size validation. */
export function extractPastedText(text: string): ExtractionResult {
  return { text: assertUsable(text), format: "pasted" };
}
