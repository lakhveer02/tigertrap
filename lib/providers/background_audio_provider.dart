import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundAudioProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _userWantsMusic = true;
  bool _disposed = false;
  static const String _prefKey = 'background_music_enabled';
  late StreamSubscription<PlayerState> _playerStateSubscription;

  BackgroundAudioProvider() {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isPlaying => _isPlaying;

  Future<void> _init() async {
    await _loadPreferences();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.playing != _isPlaying) {
        _isPlaying = state.playing;
        _safeNotify();
      }
    });
    await _setupAudioPlayer();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _userWantsMusic = prefs.getBool(_prefKey) ?? true;
  }

  Future<void> _setupAudioPlayer() async {
    try {
      await _player.setAsset('assets/audio/background_audio.mp3');
      _player.setLoopMode(LoopMode.one);
      if (_userWantsMusic) {
        await _player.play();
      }
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  Future<void> play() async {
    if (_disposed) return;
    try {
      await _player.play();
      _userWantsMusic = true;
      _savePreference(true);
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    try {
      await _player.pause();
      _userWantsMusic = false;
      _savePreference(false);
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  Future<void> toggle() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  Future<void> playGoatTurnAudio() async {
    try {
      await _effectPlayer.setAsset('assets/audio/goat_audio.mp3');
      await _effectPlayer.seek(Duration.zero);
      await _effectPlayer.play();
    } catch (e) {
      debugPrint('Error playing goat turn audio: $e');
    }
  }

  Future<void> playTigerTurnAudio() async {
    try {
      await _effectPlayer.setAsset('assets/audio/tiger_audio.mp3');
      await _effectPlayer.seek(Duration.zero);
      await _effectPlayer.play();
    } catch (e) {
      debugPrint('Error playing tiger turn audio: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        if (_isPlaying) {
          _player.pause();
        }
        break;
      case AppLifecycleState.resumed:
        if (_userWantsMusic) {
          _player.play();
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _playerStateSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _effectPlayer.dispose();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
