import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import 'notebooks_controller.dart';

/// Create-notebook sheet. Saves to the backend (signed-in users).
Future<String?> showCreateNotebookSheet(BuildContext context) {
  return showGlassSheet<String>(
    context: context,
    builder: (sheetContext) => const _CreateNotebookSheet(),
  );
}

class _CreateNotebookSheet extends ConsumerStatefulWidget {
  const _CreateNotebookSheet();

  @override
  ConsumerState<_CreateNotebookSheet> createState() => _CreateNotebookSheetState();
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
    final error = await ref.read(notebooksControllerProvider.notifier).create(title);
    if (!mounted) return;
    if (error != null) {
      setState(() => _busy = false);
      showGlassToast(context, error, error: true);
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New notebook', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'A private space for one subject or unit — paste notes or upload PDFs, '
            'then ask StudyFlow AI anything about them.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          GlassInput(
            controller: _controller,
            label: 'Name',
            hintText: 'e.g. Cell Biology — Unit 3',
            autofocus: true,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved to your account — synced across your devices.',
            style: TextStyle(color: g.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: _busy ? 'Creating…' : 'Create notebook',
            icon: Icons.add,
            onPressed: _busy ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}
