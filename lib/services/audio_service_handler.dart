import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _currentStreamUrl;
  String? _currentTitle;
  String? _currentArtist;
  String? _currentImageUrl;

  // Tracks whether the USER wants the radio playing right now. This is the
  // "source of truth" for auto resume decisions — it only changes when the
  // user explicitly presses play, pause, or stop. Interruptions and network
  // drops never touch this flag directly.
  bool _userIntentPlaying = false;

  // Set to true right when an interruption begins if the player was actually
  // playing at that moment, so we know to resume once it ends.
  bool _resumeAfterInterruption = false;

  bool _isRetryingConnection = false;
  int _retryAttempt = 0;

  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _retryTimer;

  AudioPlayerHandler() {
    // Pipe playback events into the audio_service playback state stream
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen for player completion to update state
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
          ),
        );
      }
    });

    // Watches for the stream falling into idle while the user still wants
    // it playing (dropped connection, server timeout, etc.) and kicks off
    // the retry loop automatically.
    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerStateChange,
    );

    _initAudioSession();
    _initConnectivityListener();
  }

  // ─── Audio focus / interruption handling ───────────────────────────────

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _interruptionSubscription = session.interruptionEventStream.listen(
      _handleInterruptionEvent,
    );

    // Fires when headphones are unplugged or a Bluetooth device disconnects.
    // System convention is to pause rather than keep blasting from the
    // speaker unexpectedly, so this one intentionally does NOT auto resume.
    _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
      if (_player.playing) {
        _resumeAfterInterruption = false;
        _player.pause();
        if (kDebugMode) {
          print('[AudioPlayerHandler] Paused: audio route became noisy.');
        }
      }
    });
  }

  void _handleInterruptionEvent(AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Something like a short notification sound wants to duck us
          // instead of stealing focus entirely — lower volume, keep playing.
          _player.setVolume(0.3);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          // A phone call, another app's audio, or similar has taken over.
          _resumeAfterInterruption = _userIntentPlaying && _player.playing;
          if (_player.playing) {
            _player.pause();
            if (kDebugMode) {
              print('[AudioPlayerHandler] Paused for audio interruption.');
            }
          }
          break;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(1.0);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_resumeAfterInterruption && _userIntentPlaying) {
            _resumeAfterInterruption = false;
            if (kDebugMode) {
              print('[AudioPlayerHandler] Interruption ended, resuming.');
            }
            _resumePlaybackSafely();
          }
          break;
      }
    }
  }

  Future<void> _resumePlaybackSafely() async {
    try {
      if (_player.processingState == ProcessingState.idle &&
          _currentStreamUrl != null) {
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(_currentStreamUrl!)),
        );
      }
      await _player.play();
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] Error resuming after interruption: $e');
      }
      _scheduleRetry();
    }
  }

  // ─── Network loss / reconnect handling ─────────────────────────────────

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);

      if (hasConnection) {
        if (_userIntentPlaying &&
            !_player.playing &&
            _currentStreamUrl != null) {
          if (kDebugMode) {
            print('[AudioPlayerHandler] Network back, attempting resume.');
          }
          _retryAttempt = 0;
          _retryTimer?.cancel();
          _attemptReconnect();
        }
      } else {
        if (kDebugMode) {
          print('[AudioPlayerHandler] Network lost.');
        }
        // Nothing forced here — just audio_session/just_audio state
        // eventually reflects the drop and _handlePlayerStateChange or the
        // player's own error path triggers the retry loop below.
      }
    });
  }

  void _handlePlayerStateChange(PlayerState state) {
    final stalled =
        !state.playing && (state.processingState == ProcessingState.idle);

    if (_userIntentPlaying && stalled && !_isRetryingConnection) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (!_userIntentPlaying) return;
    _isRetryingConnection = true;
    _retryTimer?.cancel();
    // Backs off gradually: 2s, 4s, 6s, 8s, 10s, then holds at 15s so it
    // doesn't hammer the stream server while waiting for network to return.
    final delaySeconds = _retryAttempt < 5 ? (_retryAttempt + 1) * 2 : 15;
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      _retryAttempt++;
      _attemptReconnect();
    });
  }

  Future<void> _attemptReconnect() async {
    if (!_userIntentPlaying || _currentStreamUrl == null) {
      _isRetryingConnection = false;
      return;
    }
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(_currentStreamUrl!)),
      );

      // Rebuild the notification/media item using the last known station
      // details so the lock screen doesn't go blank or stale after a
      // reconnect — this is what _currentTitle/_currentArtist/_currentImageUrl
      // are for.
      final Uri? artUri =
          (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
              ? Uri.tryParse(_currentImageUrl!)
              : null;

      mediaItem.add(
        MediaItem(
          id: Uri.encodeComponent(_currentStreamUrl!),
          title:
              (_currentTitle != null && _currentTitle!.isNotEmpty)
                  ? _currentTitle!
                  : 'Unknown Station',
          artist:
              (_currentArtist != null && _currentArtist!.isNotEmpty)
                  ? _currentArtist!
                  : 'Live Radio',
          album: 'ArinaCave Radio',
          artUri: artUri,
          duration: null,
          extras: <String, dynamic>{
            'streamUrl': _currentStreamUrl,
            'isLive': true,
          },
        ),
      );

      await _player.play();
      _isRetryingConnection = false;
      _retryAttempt = 0;
      if (kDebugMode) {
        print('[AudioPlayerHandler] Reconnected to stream successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] Reconnect attempt failed: $e');
      }
      _isRetryingConnection = false;
      if (_userIntentPlaying) {
        _scheduleRetry();
      }
    }
  }

  /// Call this from RadioScreen to load and play a station
  Future<void> playStation(
    String url,
    String title,
    String artist,
    String imageUrl,
  ) async {
    if (url.isEmpty) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] playStation called with empty URL');
      }
      return;
    }

    _currentStreamUrl = url;
    _currentTitle = title;
    _currentArtist = artist;
    _currentImageUrl = imageUrl;
    _userIntentPlaying = true;
    _retryAttempt = 0;
    _isRetryingConnection = false;
    _retryTimer?.cancel();

    // Update the media item so the notification shows correct info
    final Uri? artUri = imageUrl.isNotEmpty ? Uri.tryParse(imageUrl) : null;

    mediaItem.add(
      MediaItem(
        id: Uri.encodeComponent(url),
        title: title.isNotEmpty ? title : 'Unknown Station',
        artist: artist.isNotEmpty ? artist : 'Live Radio',
        album: 'ArinaCave Radio',
        artUri: artUri,
        // Mark as live stream so duration is not shown
        duration: null,
        extras: <String, dynamic>{'streamUrl': url, 'isLive': true},
      ),
    );

    try {
      // Stop any existing playback cleanly before loading new source
      await _player.stop();
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();

      if (kDebugMode) {
        print('[AudioPlayerHandler] Now playing: $title — $url');
      }
    } on PlayerException catch (e) {
      if (kDebugMode) {
        print(
          '[AudioPlayerHandler] PlayerException: ${e.message} (code: ${e.code})',
        );
      }
      _scheduleRetry();
    } on PlayerInterruptedException catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] PlayerInterruptedException: ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] Unexpected error playing station: $e');
      }
      _scheduleRetry();
    }
  }

  /// Transforms a just_audio PlaybackEvent into an audio_service PlaybackState
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex ?? 0,
    );
  }

  /// Maps just_audio ProcessingState to audio_service AudioProcessingState
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      // ignore: unreachable_switch_default
      default:
        return AudioProcessingState.idle;
    }
  }

  // ─── BaseAudioHandler overrides ─────────────────────────────────────────────

  @override
  Future<void> play() async {
    _userIntentPlaying = true;

    if (_currentStreamUrl == null) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] play() called but no stream URL is set.');
      }
      return;
    }

    // If the player is idle (was stopped), reload the stream before playing
    if (_player.processingState == ProcessingState.idle) {
      try {
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(_currentStreamUrl!)),
        );
      } catch (e) {
        if (kDebugMode) {
          print('[AudioPlayerHandler] Error reloading source on play(): $e');
        }
        _scheduleRetry();
        return;
      }
    }

    await _player.play();
  }

  @override
  Future<void> pause() async {
    // This is an explicit user pause, so we must not auto resume from it.
    _userIntentPlaying = false;
    _resumeAfterInterruption = false;
    _retryTimer?.cancel();
    _isRetryingConnection = false;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _userIntentPlaying = false;
    _resumeAfterInterruption = false;
    _retryTimer?.cancel();
    _isRetryingConnection = false;

    await _player.stop();
    // Reset currentStreamUrl tracking so play() knows state is fully stopped
    _currentStreamUrl = null;

    // Explicitly push idle state to notification
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
  }

  /// Dispose internal audio player when handler is no longer needed.
  /// Call this when the app fully terminates, not just navigates away.
  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _player.dispose();
  }
}
