import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'podcast_player_interface.dart';
import 'podcast_player_io.dart'
    if (dart.library.js_interop) 'podcast_player_web.dart'
    as impl;

export 'podcast_player_interface.dart' show PodcastPlayer;

/// One player per screen session; overridden in tests with a fake.
final podcastPlayerProvider = Provider<PodcastPlayer>(
  (ref) => impl.createPodcastPlayer(),
);
