import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _currentStreamUrl;

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
      rethrow;
    } on PlayerInterruptedException catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] PlayerInterruptedException: ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerHandler] Unexpected error playing station: $e');
      }
      rethrow;
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
        rethrow;
      }
    }

    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
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
    await _player.dispose();
  }
}
