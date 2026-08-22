import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'notebooks_controller.dart';

/// Create-notebook sheet. Saves to the backend (signed-in users).
Future<String?> showCreateNotebookSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateNotebookSheet(),
  );
}

class _CreateNotebookSheet extends ConsumerStatefulWidget {
  const _CreateNotebookSheet();

  @override
  ConsumerState<_CreateNotebookSheet> createState() =>
      _CreateNotebookSheetState();
}

class _CreateNotebookSheetState extends ConsumerState<_CreateNotebookSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _busy) return;
    setState(() => _busy = true);
    final error = await ref
        .read(notebooksControllerProvider.notifier)
        .create(title);
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Container(
        color: isDark ? SwissColors.darkSurface : SwissColors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SwissDivider(thickness: 4),
            const SizedBox(height: SwissSpacing.lg),
            Text(
              'NEW NOTEBOOK',
              style: SwissTypography.section.copyWith(color: fg),
            ),
            const SizedBox(height: SwissSpacing.xs),
            Text(
              'A private space for one subject or unit — paste notes or upload PDFs.',
              style: SwissTypography.body.copyWith(color: mutedFg),
            ),
            const SizedBox(height: SwissSpacing.xl),
            SwissInput(
              controller: _controller,
              label: 'Name',
              hintText: 'e.g. Cell Biology — Unit 3',
              autofocus: true,
            ),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'SAVED TO YOUR ACCOUNT — SYNCED ACROSS DEVICES.',
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
            const SizedBox(height: SwissSpacing.xl),
            SwissButton(
              label: _busy ? 'Creating…' : 'Create notebook',
              icon: Icons.add,
              fullWidth: true,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
