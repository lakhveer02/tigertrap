import 'package:flutter/material.dart';
import 'package:tiger_trap/logic/aadu_puli_logic.dart';
import 'package:tiger_trap/models/piece.dart';
import 'package:tiger_trap/models/board_config.dart';
import 'package:provider/provider.dart';
import '../../providers/background_audio_provider.dart';
import '../../logic/game_controller.dart';

class AaduPuliProvider extends ChangeNotifier {
  late BoardConfig _config;
  int _placedGoats = 0;
  int _capturedGoats = 0;
  bool _isGoatMovementPhase = false;
  PieceType _currentTurn = PieceType.tiger;
  Point? _selectedPiece;
  List<Point> _validMoves = [];
  String? _gameMessage;
  GameController? _gameController;

  BoardConfig get config => _config;
  int get placedGoats => _placedGoats;
  int get capturedGoats => _capturedGoats;
  bool get isGoatMovementPhase => _isGoatMovementPhase;
  PieceType get currentTurn => _currentTurn;
  Point? get selectedPiece => _selectedPiece;
  List<Point> get validMoves => _validMoves;
  String? get gameMessage => _gameMessage;

  AaduPuliProvider(BoardConfig config) {
    _config = config;
    _initializeBoard();
  }

  void setGameController(GameController controller) {
    _gameController = controller;
  }

  void _initializeBoard() {
    AaduPuliLogic.initializeBoard(_config);
    _placedGoats = 0;
    _capturedGoats = 0;
    _isGoatMovementPhase = false;
    _currentTurn = PieceType.goat;
    _selectedPiece = null;
    _validMoves = [];
    _gameMessage = null;
    notifyListeners();
  }

  void handleTap(Point point) {
    if (_gameMessage != null || (_gameController?.isPaused ?? false)) return;

    if (!_isGoatMovementPhase && _currentTurn == PieceType.goat) {
      _placeGoat(point);
      _playTurnAudio();
    } else {
      _handleMovement(point);
      _playTurnAudio();
    }
    _checkWinConditions();
    notifyListeners();
  }

  void _placeGoat(Point point) {
    if (point.type != PieceType.empty || _placedGoats >= 15) return;

    point.type = PieceType.goat;
    _placedGoats++;

    if (_placedGoats >= 15) _isGoatMovementPhase = true;
    _currentTurn = PieceType.tiger;
    _calculateValidMoves();
    notifyListeners();
  }

  void _handleMovement(Point point) {
    if (_selectedPiece == null) {
      if (point.type == _currentTurn) {
        _selectedPiece = point;
        _calculateValidMoves();
      }
    } else {
      final didContinue = _executeMove(_selectedPiece!, point);
      if (!didContinue) {
        _selectedPiece = null;
        _validMoves = [];
        _playTurnAudio();
      }
    }
  }

  void _calculateValidMoves() {
    _validMoves = [];
    if (_selectedPiece == null) return;
    _validMoves = AaduPuliLogic.getValidMoves(_selectedPiece!, _config);
  }

  void _checkWinConditions() {
    if (_gameMessage != null) return; 

    if (AaduPuliLogic.checkTigerWin(_capturedGoats)) {
      _gameMessage = 'Tigers Win!';
    } else if (AaduPuliLogic.checkGoatWin(_config)) {
      _gameMessage = 'Goats Win!';
    }

    notifyListeners();
  }

  bool _executeMove(Point from, Point to) {
    final result = AaduPuliLogic.executeMove(from, to, _config);
    if (result == MoveResult.invalid) return false;

    if (result == MoveResult.capture) {
      _capturedGoats++;
      _currentTurn = from.type == PieceType.tiger ? PieceType.goat : PieceType.tiger;
      _selectedPiece = null;
      _validMoves = [];
      notifyListeners();
      return false;
    }

    _currentTurn = from.type == PieceType.tiger ? PieceType.goat : PieceType.tiger;
    _selectedPiece = null;
    _validMoves = [];
    notifyListeners();
    return false;
  }

  void resetGame() {
    _initializeBoard();
    notifyListeners();
  }

  void makeComputerMove() {
    if (_gameController != null && _gameMessage == null && _currentTurn == PieceType.tiger) {
      _gameController!.makeComputerMove();
    }
  }

  void _playTurnAudio() {
    final context = _findContext();
    if (context == null) return;
    final audio = Provider.of<BackgroundAudioProvider>(context, listen: false);
    if (_currentTurn == PieceType.goat) {
      audio.playGoatTurnAudio();
    } else if (_currentTurn == PieceType.tiger) {
      audio.playTigerTurnAudio();
    }
  }

  BuildContext? _findContext() {
    try {
      return WidgetsBinding.instance.focusManager.primaryFocus?.context;
    } catch (_) {
      return null;
    }
  }
}
