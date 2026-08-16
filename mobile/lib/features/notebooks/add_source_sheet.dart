import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import 'notebook_sources.dart';
import 'notebooks_repository.dart';
import 'source_upload.dart';

/// The "Add source" glass sheet: how the user brings material into a Study
/// Space. Only genuinely implemented options are shown — uploading files
/// (native picker) and pasting text.
///
/// [onPickFiles] is injectable so tests can drive the flow without the
/// platform plugin; the production default opens the native file picker.
class AddSourceSheet extends StatefulWidget {
  const AddSourceSheet({
    super.key,
    required this.onUpload,
    required this.onPaste,
    this.onPickFiles,
  });

  /// Uploads the selected files to the backend. [onProgress] receives
  /// (filesDone, totalFiles) as each upload completes.
  final Future<List<NotebookSource>> Function(
    List<UploadFile> files,
    void Function(int done, int total) onProgress,
  )
  onUpload;

  /// Called when the user chooses Paste text; the sheet closes and the
  /// host opens the paste sheet.
  final VoidCallback onPaste;

  /// Opens the native file picker. Defaults to [FilePicker]; tests inject
  /// a fake.
  final Future<List<UploadFile>> Function()? onPickFiles;

  @override
  State<AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends State<AddSourceSheet> {
  final List<UploadFile> _selected = [];
  final List<String> _errors = [];

  bool _uploading = false;
  int _done = 0;
  int _total = 0;
  String? _uploadError;

  Future<List<UploadFile>> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt', 'md', 'markdown'],
    );
    // Cancellation returns an empty list; bytes load on demand per file so
    // memory stays flat even when several large files are selected.
    return [
      for (final f in files)
        UploadFile(name: f.name, bytes: await f.readAsBytes()),
    ];
  }

  Future<void> _chooseFiles() async {
    final picker = widget.onPickFiles ?? _pickFiles;
    final files = await picker();
    if (!mounted || files.isEmpty) return;

    // Client-side gate mirrors the backend: whitelist, empty file, 25 MB.
    final errors = <String>[];
    for (final f in files) {
      final problem = validateUploadFile(f);
      if (problem != null) errors.add(problem);
    }
    setState(() {
      _selected.addAll(files);
      _errors
        ..clear()
        ..addAll(errors);
      _uploadError = null;
    });
  }

  void _remove(UploadFile file) {
    setState(() {
      _selected.remove(file);
      _errors.clear();
      _uploadError = null;
    });
  }

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _done = 0;
      _total = _selected.length;
      _uploadError = null;
    });
    try {
      await widget.onUpload(_selected, (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e is NotebooksException
            ? e.message
            : 'Could not upload those files. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final validCount = _selected.length - _errors.length;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add source', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Bring your study material here — StudyFlow AI extracts it, '
            'indexes it, and grounds every answer, flashcard, and quiz in it.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Upload files — the primary path.
          _OptionRow(
            icon: Icons.upload_file,
            title: 'Upload files',
            subtitle: 'PDF, Word (DOCX), TXT, Markdown — pick several at once',
            onTap: _uploading ? null : _chooseFiles,
          ),
          const SizedBox(height: 10),

          // Paste text — closes this sheet and hands over to the paste flow.
          _OptionRow(
            icon: Icons.content_paste,
            title: 'Paste text',
            subtitle: 'Copy notes or a transcript straight in',
            onTap: _uploading
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onPaste();
                  },
          ),

          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final file in _selected) ...[
              _SelectedFileTile(
                file: file,
                disabled: _uploading,
                onRemove: () => _remove(file),
              ),
              const SizedBox(height: 8),
            ],
          ],

          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final e in _errors.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(e, style: TextStyle(color: g.danger, fontSize: 13)),
              ),
          ],

          if (_uploadError != null) ...[
            const SizedBox(height: 4),
            Text(
              _uploadError!,
              style: TextStyle(color: g.danger, fontSize: 13),
            ),
          ],

          if (_uploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
                minHeight: 6,
                backgroundColor: g.textMuted.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Uploading $_done of $_total…',
              style: TextStyle(color: g.textMuted, fontSize: 12),
            ),
          ],

          const SizedBox(height: 16),
          GlassButton(
            label: _selected.isEmpty
                ? 'Choose files'
                : _uploading
                ? 'Uploading…'
                : validCount > 0
                ? 'Add $validCount source${validCount == 1 ? '' : 's'}'
                : 'Add sources',
            icon: _selected.isEmpty ? Icons.folder_open : Icons.cloud_upload,
            expand: true,
            onPressed: _uploading || _selected.isEmpty || validCount == 0
                ? null
                : _upload,
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: GlassTone.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: g.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: g.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: g.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: g.textMuted.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFileTile extends StatelessWidget {
  const _SelectedFileTile({
    required this.file,
    required this.disabled,
    required this.onRemove,
  });

  final UploadFile file;
  final bool disabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: GlassTone.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            fileIconFor(file.name),
            color: fileIconColorFor(file.name, g.primary),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatBytes(file.bytes.length),
                  style: TextStyle(color: g.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: disabled ? null : onRemove,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
