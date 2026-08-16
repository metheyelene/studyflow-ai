import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A file the user has selected for upload. Mirrors the backend's accepted
/// set exactly — TXT/MD/PDF/DOCX — so the app never claims a format the
/// API cannot process.
class UploadFile {
  const UploadFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot).toLowerCase();
  }
}

/// The backend's source-size limit (`MAX_SOURCE_BYTES` in src/lib/ai/extract.ts).
const int kMaxSourceBytes = 25 * 1024 * 1024;

/// Formats the backend can actually extract (same whitelist as
/// `SUPPORTED_FORMATS` in src/lib/ai/extract.ts).
const Set<String> kSupportedSourceExtensions = {
  '.txt',
  '.md',
  '.markdown',
  '.pdf',
  '.docx',
};

/// Client-side gate that mirrors the backend's `validateUpload`: extension
/// whitelist, empty file, and the 25 MB ceiling. The API is still the real
/// gate — this just stops obvious failures before any bytes leave the phone.
/// Returns a friendly message, or null when the file is fine.
String? validateUploadFile(UploadFile file) {
  if (file.bytes.isEmpty) {
    return '“${file.name}” is empty.';
  }
  if (file.bytes.length > kMaxSourceBytes) {
    return '“${file.name}” is ${formatBytes(file.bytes.length)} — the limit is 25 MB.';
  }
  if (!kSupportedSourceExtensions.contains(file.extension)) {
    return '“${file.name}” is not supported. StudyFlow accepts PDF, Word (DOCX), TXT, and Markdown.';
  }
  return null;
}

/// Natural size labels — 1.2 MB, 24.8 MB, 1.1 GB — never raw bytes.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

/// A polished vector icon per file kind — never emoji. Unknown kinds fall
/// back to a neutral document glyph.
IconData fileIconFor(String name) {
  final ext = name.contains('.')
      ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => Icons.picture_as_pdf,
    'doc' || 'docx' => Icons.description,
    'ppt' || 'pptx' => Icons.slideshow,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart,
    'png' || 'jpg' || 'jpeg' || 'webp' || 'heic' => Icons.image,
    'txt' || 'md' || 'markdown' || 'rtf' => Icons.notes,
    _ => Icons.insert_drive_file,
  };
}

/// The accent color used to tint the file glyph per kind. Monochrome:
/// file type is communicated by iconography and a gray brightness ladder
/// (never hue) — PDF the lightest, text the darkest.
Color fileIconColorFor(String name, Color fallback) {
  final ext = name.contains('.')
      ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => const Color(0xFFE0E0E0),
    'doc' || 'docx' => const Color(0xFF9E9E9E),
    'ppt' || 'pptx' => const Color(0xFFBDBDBD),
    'xls' || 'xlsx' || 'csv' => const Color(0xFF7A7A7A),
    'png' || 'jpg' || 'jpeg' || 'webp' || 'heic' => const Color(0xFFD6D6D6),
    'txt' || 'md' || 'markdown' || 'rtf' => const Color(0xFF4A4A4A),
    _ => fallback,
  };
}
