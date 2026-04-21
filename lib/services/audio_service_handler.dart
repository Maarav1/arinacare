import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayerHandler() {
    // Forward audio player events to audio service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Add media item (remove `const` because Uri.parse isn't const)
    mediaItem.add(MediaItem(
      id: 'bbc_world_service',
      title: 'BBC World Service',
      artist: 'BBC',
      album: 'International News',
      artUri: Uri.parse('https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/BBC_World_Service_red.svg/512px-BBC_World_Service_red.svg.png'),
    ));

    // Optional: set the audio source (radio stream or file)
    _init();
  }

  Future<void> _init() async {
    try {
      // replace with your actual stream URL
      await _player.setAudioSource(AudioSource.uri(Uri.parse('https://your-stream-url-here')));
    } catch (e) {
      // handle error (log or update playbackState)
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: const [
        MediaControl.play,
        MediaControl.pause,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
  ProcessingState.idle: AudioProcessingState.idle,
  ProcessingState.loading: AudioProcessingState.loading,
  ProcessingState.buffering: AudioProcessingState.buffering,
  ProcessingState.ready: AudioProcessingState.ready,
  ProcessingState.completed: AudioProcessingState.completed,
}[_player.processingState] ?? AudioProcessingState.idle, // Provide a default
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async => _player.stop();

  @override
  Future<void> seek(Duration position) async => _player.seek(position);
}
