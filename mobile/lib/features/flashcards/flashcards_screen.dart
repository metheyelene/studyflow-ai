import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import '../notebooks/notebooks_controller.dart';
import 'flashcard_models.dart';
import 'flashcards_controller.dart';
import 'flashcards_repository.dart';

/// Deck list for the user's flashcards: empty state, generate-from-notebook
/// flow, and entry into the study session.
class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(flashcardsControllerProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text('Flashcards', style: Theme.of(context).textTheme.titleLarge),
                ),
                GlassBadge(
                  label: decks.valueOrNull == null
                      ? '—'
                      : '${decks.valueOrNull!.decks.length} deck${decks.valueOrNull!.decks.length == 1 ? '' : 's'}',
                  icon: Icons.style_outlined,
                ),
                const SizedBox(width: 10),
                GlassButton(
                  label: 'New deck',
                  icon: Icons.add,
                  size: GlassButtonSize.small,
                  onPressed: () => _openGenerateSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: decks.when(
              loading: () => const _DecksLoading(),
              error: (err, _) => _DecksError(
                message: err is FlashcardsException ? err.message : 'Could not load your decks.',
                onRetry: () => ref.read(flashcardsControllerProvider.notifier).refresh(),
              ),
              data: (state) {
                if (state.decks.isEmpty) {
                  return _EmptyDecks(
                    onGenerate: () => _openGenerateSheet(context, ref),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 96 : 24),
                  itemCount: state.decks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _DeckCard(
                    deck: state.decks[i],
                    onOpen: () => context.push(
                      '${AppRoutes.flashcards}/${state.decks[i].id}',
                    ),
                    onDelete: () => _confirmDelete(context, ref, state.decks[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGenerateSheet(BuildContext context, WidgetRef ref) async {
    final detail = await showGlassSheet<FlashcardDeckDetail>(
      context: context,
      builder: (_) => _GenerateDeckSheet(),
    );
    if (detail == null || !context.mounted) return;
    context.push('${AppRoutes.flashcards}/${detail.deck.id}');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, FlashcardDeck deck) async {
    final confirmed = await showGlassModal<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delete this deck?', style: Theme.of(dialogContext).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '“${deck.title}” and its ${deck.cardCount} cards will be removed. This can\'t be undone.',
            style: TextStyle(color: context.glass.textMuted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GlassButton(
                label: 'Cancel',
                variant: GlassButtonVariant.text,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: GlassButtonVariant.primary,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(flashcardsControllerProvider.notifier).delete(deck.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the deck. Please try again.')),
      );
    }
  }
}

class _DecksLoading extends StatelessWidget {
  const _DecksLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => GlassCard(
        child: Row(
          children: [
            const GlassSkeleton(width: 42, height: 42, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  GlassSkeleton(width: 170, height: 15),
                  SizedBox(height: 8),
                  GlassSkeleton(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecksError extends StatelessWidget {
  const _DecksError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 26, color: g.textMuted),
              const SizedBox(height: 12),
              Text('Could not load your decks', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: g.textMuted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Try again',
                icon: Icons.refresh,
                variant: GlassButtonVariant.glass,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDecks extends StatelessWidget {
  const _EmptyDecks({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 24, 20, context.isPhone ? 110 : 40),
      child: GlassCard(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: g.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.style_outlined, size: 24, color: g.primary),
            ),
            const SizedBox(height: 14),
            Text('No decks yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Generate a deck from a notebook and StudyFlow AI turns your '
              'material into front/back cards — grounded in your sources.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Generate a deck',
              icon: Icons.auto_awesome,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.onOpen, required this.onDelete});

  final FlashcardDeck deck;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.style_outlined, size: 21, color: g.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${deck.cardCount} card${deck.cardCount == 1 ? '' : 's'} · '
                        'updated ${relativeTime(deck.updatedAt, DateTime.now())}',
                        style: TextStyle(color: g.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 20, color: g.textMuted),
                  tooltip: 'Delete deck',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a notebook to generate a deck from. Watches the real
/// notebook list; returns the generated deck via the sheet result.
class _GenerateDeckSheet extends ConsumerStatefulWidget {
  const _GenerateDeckSheet();

  @override
  ConsumerState<_GenerateDeckSheet> createState() => _GenerateDeckSheetState();
}

class _GenerateDeckSheetState extends ConsumerState<_GenerateDeckSheet> {
  String? _busyNotebookId;
  String? _error;

  Future<void> _generate(String notebookId, String notebookTitle) async {
    setState(() {
      _busyNotebookId = notebookId;
      _error = null;
    });
    try {
      final detail = await ref
          .read(flashcardsControllerProvider.notifier)
          .generate(notebookId);
      if (!mounted) return;
      Navigator.of(context).pop(detail);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyNotebookId = null;
        _error = e is FlashcardsException
            ? e.message
            : 'Could not generate that deck. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final notebooks = ref.watch(notebooksControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generate a deck', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'StudyFlow AI reads the notebook\'s sources and builds front/back '
            'cards from the material. Uses one AI action.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (notebooks.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (notebooks.hasError)
            Text(
              'Could not load your notebooks.',
              style: TextStyle(color: g.danger, fontSize: 13),
            )
          else if ((notebooks.valueOrNull ?? const []).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'You don\'t have any notebooks yet. Create one, add a source, '
                'then come back to generate.',
                style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: notebooks.valueOrNull!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final nb = notebooks.valueOrNull![i];
                  final busy = _busyNotebookId == nb.id;
                  return GlassButton(
                    label: busy ? 'Generating…' : nb.title,
                    icon: Icons.auto_awesome,
                    variant: GlassButtonVariant.glass,
                    expand: true,
                    onPressed: busy ? null : () => _generate(nb.id, nb.title),
                  );
                },
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: g.danger, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
