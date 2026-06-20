import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  RadioStation? _currentStation;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration? _currentPosition;
  Duration? _totalDuration;

  final StreamController<bool> _playingStateController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _bufferingStateController =
      StreamController<bool>.broadcast();
  final StreamController<Duration?> _positionController =
      StreamController<Duration?>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<RadioStation?> _stationController =
      StreamController<RadioStation?>.broadcast();

  // Public streams for UI to listen to
  Stream<bool> get playingStateStream => _playingStateController.stream;
  Stream<bool> get bufferingStateStream => _bufferingStateController.stream;
  Stream<Duration?> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<RadioStation?> get stationStream => _stationController.stream;

  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration? get currentPosition => _currentPosition;
  Duration? get totalDuration => _totalDuration;

  Future<void> initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp |
              AVAudioSessionCategoryOptions.allowAirPlay,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
    } catch (e) {
      // FIX: Use print instead of debugPrint
      if (kDebugMode) {
        print('Audio session configuration error: $e');
      }
    }

    // Listen for player state changes
    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      _isBuffering = playerState.processingState == ProcessingState.buffering;
      _playingStateController.add(_isPlaying);
      _bufferingStateController.add(_isBuffering);
    });

    // Listen for position updates
    _audioPlayer.positionStream.listen((position) {
      _currentPosition = position;
      _positionController.add(position);
    });

    // Listen for duration updates
    _audioPlayer.durationStream.listen((duration) {
      _totalDuration = duration;
      _durationController.add(duration);
    });

    // Handle errors
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (e) {
        // FIX: Use print instead of debugPrint
        if (kDebugMode) {
          print('Audio error: $e');
        }
      },
    );
  }

  Future<void> playStation(RadioStation station) async {
    try {
      if (_currentStation?.id == station.id && _isPlaying) {
        await pause();
        return;
      }

      _currentStation = station;
      _stationController.add(station);

      _isBuffering = true;
      _bufferingStateController.add(true);

      await _audioPlayer.stop();
      await _audioPlayer.setUrl(station.streamUrl);
      await _audioPlayer.play();

      _isBuffering = false;
      _bufferingStateController.add(false);
    } catch (e) {
      // FIX: Use print instead of debugPrint
      if (kDebugMode) {
        print('Error playing station: $e');
      }
      _isBuffering = false;
      _bufferingStateController.add(false);
      rethrow;
    }
  }

  Future<void> togglePlayback() async {
    if (_currentStation == null) return;

    if (_isPlaying) {
      await pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.idle) {
        await playStation(_currentStation!);
      } else {
        await _audioPlayer.play();
        _isPlaying = true;
        _playingStateController.add(true);
      }
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    _playingStateController.add(false);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _playingStateController.add(false);
    _currentPosition = null;
    _positionController.add(null);
  }

  void dispose() {
    _audioPlayer.dispose();
    _playingStateController.close();
    _bufferingStateController.close();
    _positionController.close();
    _durationController.close();
    _stationController.close();
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class RadioStation {
  final String id;
  final String name;
  final String description;
  final String streamUrl;
  final String logoUrl;
  final String language;
  final String category;
  final String country;
  final Color color;
  final String bitrate;

  RadioStation({
    required this.id,
    required this.name,
    required this.description,
    required this.streamUrl,
    required this.logoUrl,
    required this.language,
    required this.category,
    required this.country,
    required this.color,
    required this.bitrate,
  });
}