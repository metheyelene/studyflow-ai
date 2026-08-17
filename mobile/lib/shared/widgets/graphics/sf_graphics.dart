/// StudyFlow monochrome motion-graphics system.
///
/// Small, purposeful, black-and-white animated moments: document
/// processing, AI thinking/generating, source retrieval, success and
/// error, sync/save/search, audio waveform, progress ring, mastery,
/// streak, splash, onboarding. Every graphic draws through
/// [SFGraphicPalette] (monochrome in both modes), honors reduced motion
/// via [SFGraphic], and is decorative — the surrounding UI carries the
/// semantic text.
library;

export 'sf_ai_graphics.dart'
    show SFAIGeneratingGraphic, SFAIThinkingGraphic, SFSourceSearchGraphic;
export 'sf_ambient_graphics.dart'
    show
        SFAudioWaveform,
        SFKnowledgeGraphic,
        SFMasteryGraphic,
        SFProgressRingGraphic,
        SFSplashGraphic,
        SFStreakGraphic;
export 'sf_content_graphics.dart'
    show
        SFFlashcardStackGraphic,
        SFNoteOrganizeGraphic,
        SFOnboardingGraphic,
        SFOnboardingStep,
        SFPodcastGraphic,
        SFQuizFramesGraphic,
        SFStudyGuideGraphic;
export 'sf_document_graphics.dart'
    show SFDocumentKind, SFDocumentScanGraphic, SFUploadGraphic;
export 'sf_feedback_graphics.dart'
    show
        SFErrorGraphic,
        SFSavingGraphic,
        SFSearchGraphic,
        SFSuccessGraphic,
        SFSyncGraphic;
export 'sf_graphic_base.dart'
    show kSfDot, kSfLineWeight, SFGraphic, SFGraphicPalette;
