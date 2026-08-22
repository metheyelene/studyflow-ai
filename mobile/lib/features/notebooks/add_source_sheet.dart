import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'notebook_sources.dart';
import 'notebooks_repository.dart';
import 'source_upload.dart';

/// The "Add source" sheet: how the user brings material into a Study Space.
class AddSourceSheet extends StatefulWidget {
  const AddSourceSheet({
    super.key,
    required this.onUpload,
    required this.onPaste,
    this.onPickFiles,
  });

  final Future<List<NotebookSource>> Function(
    List<UploadFile> files,
    void Function(int done, int total) onProgress,
  )
  onUpload;

  final VoidCallback onPaste;

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
    return [
      for (final f in files)
        UploadFile(name: f.name, bytes: await f.readAsBytes()),
    ];
  }

  Future<void> _chooseFiles() async {
    final picker = widget.onPickFiles ?? _pickFiles;
    final files = await picker();
    if (!mounted || files.isEmpty) return;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
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
          const SwissDivider(thickness: 4),
          const SizedBox(height: SwissSpacing.lg),
          Text(
            'ADD SOURCE',
            style: SwissTypography.section.copyWith(color: fg),
          ),
          const SizedBox(height: SwissSpacing.xs),
          Text(
            'Bring your study material here — StudyFlow AI extracts and indexes it.',
            style: SwissTypography.body.copyWith(color: mutedFg),
          ),
          const SizedBox(height: SwissSpacing.xl),

          // Upload files
          _OptionRow(
            icon: Icons.upload_file,
            title: 'UPLOAD FILES',
            subtitle: 'PDF, Word (DOCX), TXT, Markdown',
            onTap: _uploading ? null : _chooseFiles,
          ),
          const SizedBox(height: SwissSpacing.sm),

          // Paste text
          _OptionRow(
            icon: Icons.content_paste,
            title: 'PASTE TEXT',
            subtitle: 'Copy notes or a transcript straight in',
            onTap: _uploading
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onPaste();
                  },
          ),

          if (_selected.isNotEmpty) ...[
            const SizedBox(height: SwissSpacing.xl),
            for (final file in _selected) ...[
              _SelectedFileTile(
                file: file,
                disabled: _uploading,
                onRemove: () => _remove(file),
              ),
              const SizedBox(height: SwissSpacing.xs),
            ],
          ],

          if (_errors.isNotEmpty) ...[
            const SizedBox(height: SwissSpacing.xs),
            for (final e in _errors.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  e,
                  style: SwissTypography.caption.copyWith(color: SwissColors.red),
                ),
              ),
          ],

          if (_uploadError != null) ...[
            const SizedBox(height: SwissSpacing.xs),
            Text(
              _uploadError!,
              style: SwissTypography.caption.copyWith(color: SwissColors.red),
            ),
          ],

          if (_uploading) ...[
            const SizedBox(height: SwissSpacing.md),
            SwissProgressBar(
              value: _total == 0 ? 0 : _done / _total,
              height: 4,
            ),
            const SizedBox(height: SwissSpacing.xs),
            Text(
              'UPLOADING $_done OF $_total…',
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
          ],

          const SizedBox(height: SwissSpacing.xl),
          SwissButton(
            label: _selected.isEmpty
                ? 'Choose files'
                : _uploading
                ? 'Uploading…'
                : validCount > 0
                ? 'Add $validCount source${validCount == 1 ? '' : 's'}'
                : 'Add sources',
            icon: _selected.isEmpty ? Icons.folder_open : Icons.cloud_upload,
            fullWidth: true,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SwissSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? SwissColors.darkMuted : SwissColors.muted,
          border: Border.all(
            color: isDark ? SwissColors.darkBorder : SwissColors.black,
            width: SwissShapes.borderThin,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              color: fg,
              alignment: Alignment.center,
              child: Icon(icon, color: SwissColors.white, size: 20),
            ),
            const SizedBox(width: SwissSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SwissTypography.subheading.copyWith(
                      color: fg,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.xxs),
                  Text(
                    subtitle,
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: mutedFg, size: 20),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SwissSpacing.md,
        vertical: SwissSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? SwissColors.darkBorder : SwissColors.black,
          width: SwissShapes.borderThin,
        ),
      ),
      child: Row(
        children: [
          Icon(
            fileIconFor(file.name),
            color: fg,
            size: 20,
          ),
          const SizedBox(width: SwissSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name.toUpperCase(),
                  style: SwissTypography.body.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatBytes(file.bytes.length),
                  style: SwissTypography.caption.copyWith(color: mutedFg),
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
