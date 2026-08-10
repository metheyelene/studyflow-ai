import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import 'notebooks_controller.dart';

/// Create-notebook sheet. Honest about the current persistence story:
/// notebooks live on this device until the backend client is wired up.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    ref.read(notebooksProvider.notifier).create(title);
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
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Stored on this device for now — saved to your account once sign-in is wired up.',
            style: TextStyle(color: g.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          GlassButton(label: 'Create notebook', icon: Icons.add, onPressed: _submit, expand: true),
        ],
      ),
    );
  }
}
