import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/piece.dart';
import '../constants.dart';
import '../utils/board_utils.dart';
import '../models/board_config.dart';
import '../logic/square_board_logic.dart' as square;
import '../logic/aadu_puli_logic.dart' as aadu;
import '../providers/background_audio_provider.dart';
import 'dart:math';
import 'dart:async';

enum PlayerType { human, computer }

enum GameMode { pvp, pvc }

enum PlayerSide { tiger, goat }

class GameController extends ChangeNotifier {
  List<List<Point>> board = [];
  int placedGoats = 0;
  int capturedGoats = 0;
  bool isGoatMovementPhase = false;
  PieceType currentTurn = PieceType.goat;
  Point? selectedPiece;
  List<Point> validMoves = [];
  String? gameMessage;
  GameMode gameMode = GameMode.pvp;
  PlayerType tigerPlayer = PlayerType.human;
  PlayerType goatPlayer = PlayerType.human;
  PlayerSide playerSide = PlayerSide.tiger;
  Difficulty difficulty = Difficulty.easy;
  BoardType boardType = BoardType.square;
  BoardConfig? boardConfig;
  bool isPaused = false;
  Timer? _computerMoveTimer;
  Duration elapsedTime = Duration.zero;
  Timer? _gameTimer;
  int movesSinceLastUnsafe = 0;
  final int maxUnsafeMovesPer10 = 1;
  Set<String> unsafeMoveHistory = {};

  Set<String> moveHistory = {};

  GameController() {
    resetGame();
  }

  void setBoardType(BoardType type) {
    boardType = type;
    resetGame();
  }

  void resetGame() {
    cancelComputerMoveTimer();
    if (boardType == BoardType.square) {
      board = square.SquareBoardLogic.initializeBoard();
      boardConfig = null;
    } else {
      boardConfig = BoardUtils.getAaduPuliConfig();
      aadu.AaduPuliLogic.initializeBoard(boardConfig!);
      board = [];
    }
    placedGoats = 0;
    capturedGoats = 0;
    isGoatMovementPhase = false;
    currentTurn = PieceType.goat;
    selectedPiece = null;
    validMoves = [];
    gameMessage = null;
    elapsedTime = Duration.zero;
    movesSinceLastUnsafe = 0;
    unsafeMoveHistory.clear();
    notifyListeners();
    if (gameMode == GameMode.pvc) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (isComputerTurn()) {
          scheduleComputerMove();
        }
      });
    }
    _startTimer();
  }

  int get maxGoats => boardType == BoardType.square ? 20 : 15;
  int get requiredCaptures => boardType == BoardType.square ? 5 : 6;

  void handlePointTap(Point point) {
    if (gameMessage != null || isPaused) return;
    if (!_isHumanTurn()) return;
    if (!isGoatMovementPhase && currentTurn == PieceType.goat) {
      _placeGoat(point);
      debugPrint("Placed goat at ${point.x}, ${point.y}");
    } else {
      _handleMovement(point);
      debugPrint(
        "Moved piece from ${selectedPiece?.x}, ${selectedPiece?.y} to ${point.x}, ${point.y}",
      );
    }
    _playTurnAudio();
    _checkWinConditions();

    if (gameMode == GameMode.pvc && gameMessage == null && isComputerTurn()) {
      scheduleComputerMove();
      debugPrint("Computer's turn initiated");
    }
  }

  bool _isHumanTurn() {
    if (gameMode == GameMode.pvp) return true;
    if (currentTurn == PieceType.tiger && tigerPlayer == PlayerType.human)
      return true;
    if (currentTurn == PieceType.goat && goatPlayer == PlayerType.human)
      return true;
    return false;
  }

  bool isComputerTurn() {
    if (gameMode != GameMode.pvc) return false;
    if (currentTurn == PieceType.tiger && tigerPlayer == PlayerType.computer)
      return true;
    if (currentTurn == PieceType.goat && goatPlayer == PlayerType.computer)
      return true;
    return false;
  }

  bool _isComputerTurn() => isComputerTurn();

  void makeComputerMove() {
    if (!_isComputerTurn() || gameMessage != null || isPaused) return;
    if (currentTurn == PieceType.tiger) {
      if (boardType == BoardType.square) {
        _makeSquareComputerMove();
      } else {
        _makeAaduPuliComputerMove();
      }
    } else if (currentTurn == PieceType.goat) {
      _makeGoatComputerMove();
    }
    _playTurnAudio();
    _checkWinConditions();

    if (gameMode == GameMode.pvc && gameMessage == null && isComputerTurn()) {
      scheduleComputerMove(duration: const Duration(milliseconds: 400));
    }
  }

  void _makeSquareComputerMove() {
    final moves = <Map<String, Point>>[];
    for (var row in board) {
      for (var piece in row.where((p) => p.type == currentTurn)) {
        final valid = square.SquareBoardLogic.getValidMoves(piece, board);
        for (var to in valid) {
          moves.add({'from': piece, 'to': to});
        }
      }
    }
    if (moves.isEmpty) return;
    final move = _selectMoveBasedOnDifficulty(moves);
    _executeMove(move['from']!, move['to']!);
    if (currentTurn == PieceType.tiger) {
      currentTurn = PieceType.goat;
      bool allBlocked = _areAllGoatsBlocked();
      if (allBlocked) {
        gameMessage = "Goat's turn is skipped";
        currentTurn = PieceType.tiger;
        notifyListeners();
        return;
      }
    } else {
      currentTurn = PieceType.tiger;
    }
    selectedPiece = null;
    validMoves = [];
    if (gameMessage == "Goat's turn is skipped") gameMessage = null;
    notifyListeners();
  }

  void _makeAaduPuliComputerMove() {
    if (boardConfig == null) return;
    final moves = <Map<String, Point>>[];
    for (final piece in boardConfig!.nodes.where(
      (n) => n.type == currentTurn,
    )) {
      final valid = aadu.AaduPuliLogic.getValidMoves(piece, boardConfig!);
      for (final to in valid) {
        moves.add({'from': piece, 'to': to});
      }
    }
    if (moves.isEmpty) return;

    Map<String, Point> move;
    if (difficulty == Difficulty.easy) {
      move = (moves..shuffle()).first;
    } else if (difficulty == Difficulty.medium) {
      move = moves.firstWhere(
        (m) =>
            aadu.AaduPuliLogic.getValidMoves(m['to']!, boardConfig!).isNotEmpty,
        orElse: () => (moves..shuffle()).first,
      );
    } else {
      if (playerSide == PlayerSide.goat) {
        move = moves.first;
      } else {
        move = _minimaxMove(
          moves,
          2,
          true,
          double.negativeInfinity,
          double.infinity,
        );
      }
    }
    _executeMove(move['from']!, move['to']!);
    if (currentTurn == PieceType.tiger) {
      currentTurn = PieceType.goat;
      bool allBlocked = _areAllGoatsBlocked();
      if (allBlocked) {
        gameMessage = "Goat's turn is skipped";
        currentTurn = PieceType.tiger;
        notifyListeners();
        return;
      }
    } else {
      currentTurn = PieceType.tiger;
    }
    selectedPiece = null;
    validMoves = [];
    if (gameMessage == "Goat's turn is skipped") gameMessage = null;
    notifyListeners();
  }

  void _makeGoatComputerMove() {
    if (!isGoatMovementPhase) {
      _goatPlacementAI();
    } else {
      _goatMovementAI();
    }
    selectedPiece = null;
    validMoves = [];
    notifyListeners();
  }

  void _goatPlacementAI() {
    List<Point> emptyPoints = [];
    if (boardType == BoardType.square) {
      for (var row in board) {
        for (var p in row) {
          if (p.type == PieceType.empty) emptyPoints.add(p);
        }
      }
    } else if (boardConfig != null) {
      for (var p in boardConfig!.nodes) {
        if (p.type == PieceType.empty) emptyPoints.add(p);
      }
    }

    if (emptyPoints.isEmpty) {
      debugPrint("No empty points available for goat placement");
      return;
    }

    Point? bestPlacement;
    double bestScore = double.negativeInfinity;

    for (var point in emptyPoints) {
      if (unsafeMoveHistory.contains('${point.x},${point.y}')) continue;

      bool isSafe = _isGoatPositionSafe(point);

      // Skip unsafe positions in hard mode unless strategically beneficial
      if (difficulty == Difficulty.hard && !isSafe) {
        if (!unsafeMoveHistory.contains('${point.x},${point.y}')) {
          debugPrint("[hard AI] Skipping unsafe position at ${point.x}, ${point.y}");
          unsafeMoveHistory.add('${point.x},${point.y}');
        }
        continue;
      }

      point.type = PieceType.goat; // Simulate placement

      double score = 0;
      score += _calculateOuterWallScore(point) * 600; // +600 for covering outer walls
      score += _calculateBlockScore(point) * 300; // +300 for blocking tiger's exit
      score += _clusterBonus(board, point) * 150; // +150 for contributing to a wall
      score += _reducesTigerMobility(point) ? 200.0 : 0.0; // +200 for reducing tiger mobility
      score -= _tigerCanCaptureAfter(board, point) ? 500.0 : 0.0; // -500 for risking capture

      // Simulate tiger's best response
      double worstTigerScore = double.infinity;
      for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
        var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, board);
        for (var move in tigerMoves) {
          var boardClone = _cloneSquareBoard(board);
          var from = boardClone[tiger.x][tiger.y];
          var to = boardClone[move.x][move.y];
          from.type = PieceType.empty;
          to.type = PieceType.tiger;

          double tigerScore = _evaluateBoardStateForGoats(boardClone);
          worstTigerScore = tigerScore < worstTigerScore ? tigerScore : worstTigerScore;
        }
      }

      score -= worstTigerScore * 0.5; // Penalize based on tiger's best response

      if (score > bestScore) {
        bestScore = score;
        bestPlacement = point;
      }

      point.type = PieceType.empty; // Undo simulation
    }

    if (bestPlacement != null) {
      debugPrint("[hard AI] Placing goat at ${bestPlacement.x}, ${bestPlacement.y} with score $bestScore");
      _placeGoat(bestPlacement);
    } else {
      // Select the safest fallback position
      Point safestPosition = emptyPoints.reduce((a, b) {
        double riskA = _evaluateRisk(a);
        double riskB = _evaluateRisk(b);
        return riskA < riskB ? a : b;
      });
      debugPrint("[hard AI] No valid positions found, placing goat at safest position ${safestPosition.x}, ${safestPosition.y}");
      _placeGoat(safestPosition);
    }
  }

  double _calculateOuterWallScore(Point point) {
    // Prioritize outer wall positions
    if (point.x == 0 || point.x == board.length - 1 || point.y == 0 || point.y == board[0].length - 1) {
      return 1.0; // Outer wall score
    }
    return 0.0;
  }

  void _goatMovementAI() {
    List<Map<String, Point>> allMoves = [];
    for (var row in board) {
      for (var goat in row.where((p) => p.type == PieceType.goat)) {
        var validMoves = square.SquareBoardLogic.getValidMoves(goat, board);
        for (var to in validMoves) {
          if (to.type == PieceType.empty) {
            allMoves.add({'from': goat, 'to': to});
          }
        }
      }
    }

    if (allMoves.isEmpty) {
      debugPrint("[hard AI] No valid moves for goats, skipping turn");
      return;
    }

    Map<String, Point>? bestMove;
    double bestScore = double.negativeInfinity;

    for (final move in allMoves) {
      var boardClone = _cloneSquareBoard(board);
      var from = boardClone[move['from']!.x][move['from']!.y];
      var to = boardClone[move['to']!.x][move['to']!.y];
      from.type = PieceType.empty;
      to.type = PieceType.goat;

      double score = 0;
      score += _reducesTigerMobility(to) ? 300.0 : 0.0; // +300 for reducing tiger mobility
      score += _clusterBonus(boardClone, to) * 150; // +150 for supporting other goats
      score -= _tigerCanCaptureAfter(boardClone, to) ? 500.0 : 0.0; // -500 for risking capture

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    if (bestMove != null) {
      debugPrint("[hard AI] Moving goat from ${bestMove['from']!.x}, ${bestMove['from']!.y} to ${bestMove['to']!.x}, ${bestMove['to']!.y} with score $bestScore");
      _executeMove(bestMove['from']!, bestMove['to']!);
      currentTurn = PieceType.tiger;
    }
  }


  bool _areAdjacent(Point a, Point b) => a.adjacentPoints.contains(b);

  bool _isGoatPositionSafe(Point position) {
    if (boardType == BoardType.square) {
      for (final tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
        if ((position.x - tiger.x).abs() <= 1 && (position.y - tiger.y).abs() <= 1) {
          int dx = position.x - tiger.x;
          int dy = position.y - tiger.y;
          int jumpX = position.x + dx;
          int jumpY = position.y + dy;

          if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
            if (board[jumpX][jumpY].type == PieceType.empty) {
              // Check if blocking the landing point is strategically beneficial
              if (!_isStrategicBlock(position, Point(x: jumpX, y: jumpY))) {
                debugPrint("Position ${position.x}, ${position.y} is unsafe due to tiger at ${tiger.x}, ${tiger.y}");
                return false;
              }
            }
          }
        }
      }
      return true;
    } else {
      return _isGoatPositionSafeForAaduPuli(position);
    }
  }

  bool _isStrategicBlock(Point goatPosition, Point landingPoint) {
    // Evaluate if blocking the landing point is strategically beneficial
    // For example, it might be beneficial if it reduces tiger mobility significantly
    var boardClone = _cloneSquareBoard(board);
    boardClone[goatPosition.x][goatPosition.y].type = PieceType.goat;

    int initialTigerMobility = _calculateTigerMobility(board);
    int reducedTigerMobility = _calculateTigerMobility(boardClone);

    return reducedTigerMobility < initialTigerMobility;
  }

  bool _isGoatPositionSafeForAaduPuli(Point goatPosition) {
    if (boardConfig == null) return true;
    for (final tiger in boardConfig!.nodes.where(
      (n) => n.type == PieceType.tiger,
    )) {
      if (goatPosition.adjacentPoints.contains(tiger)) {
        for (final landing in goatPosition.adjacentPoints) {
          if (landing == tiger || landing.type != PieceType.empty) continue;
          final key = '${tiger.id},${goatPosition.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  bool _isJump(Point from, Point to) {
    return !_areAdjacent(from, to);
  }

  int _randomInt(int max) => Random().nextInt(max);
  Map<String, Point> _selectMoveBasedOnDifficulty(
    List<Map<String, Point>> moves,
  ) {
    final isTiger = currentTurn == PieceType.tiger;
    if (isTiger) {
      switch (difficulty) {
        case Difficulty.easy:
          final captures =
              moves.where((m) => _isJump(m['from']!, m['to']!)).toList();
          if (captures.isNotEmpty) return (captures..shuffle()).first;
          return (moves..shuffle()).first;
        case Difficulty.medium:
          final captures =
              moves.where((m) => _isJump(m['from']!, m['to']!)).toList();
          if (captures.isNotEmpty) return (captures..shuffle()).first;
          final threateningMoves =
              moves
                  .where(
                    (m) => m['to']!.adjacentPoints.any(
                      (adj) =>
                          adj.type == PieceType.goat &&
                          adj.adjacentPoints.any(
                            (adjAdj) => adjAdj.type == PieceType.empty,
                          ),
                    ),
                  )
                  .toList();
          if (threateningMoves.isNotEmpty)
            return (threateningMoves..shuffle()).first;
          return (moves..shuffle()).first;
        case Difficulty.hard:
          return _minimaxMove(
            moves,
            2,
            true,
            double.negativeInfinity,
            double.infinity,
          );
      }
    }
    return moves[_randomInt(moves.length)];
  }

  void _placeGoat(Point point) {
    final maxGoats = boardType == BoardType.square ? 20 : 15;
    if (point.type != PieceType.empty || placedGoats >= maxGoats) {
      debugPrint("Invalid goat placement at ${point.x},${point.y}");
      return;
    }

    if (!_isGoatPositionSafe(point)) {
      debugPrint(
        "Warning: Placing goat in unsafe position at ${point.x},${point.y}",
      );
    }

    point.type = PieceType.goat;
    placedGoats++;
    if (placedGoats < maxGoats) {
      currentTurn = PieceType.tiger;
    } else {
      isGoatMovementPhase = true;
      currentTurn = PieceType.tiger;
    }
    selectedPiece = null;
    validMoves = [];
    notifyListeners();
  }

  void _handleMovement(Point point) {
    if (selectedPiece == null) {
      if (point.type == currentTurn) {
        selectedPiece = point;
        validMoves = _getValidMoves(point);
      }
    } else {
      if (validMoves.contains(point)) {
        _executeMove(selectedPiece!, point);
        if (currentTurn == PieceType.tiger) {
          currentTurn = PieceType.goat;
          bool allBlocked = _areAllGoatsBlocked();
          if (allBlocked) {
            gameMessage = "Goat's turn is skipped";
            currentTurn = PieceType.tiger;
            notifyListeners();
            return;
          }
        } else {
          currentTurn = PieceType.tiger;
        }
      }
      selectedPiece = null;
      validMoves = [];
    }
    if (gameMessage == "Goat's turn is skipped") gameMessage = null;
    notifyListeners();
  }

  List<Point> _getValidMoves(Point piece) {
    if (boardType == BoardType.square) {
      return square.SquareBoardLogic.getValidMoves(piece, board);
    } else if (boardConfig != null) {
      return aadu.AaduPuliLogic.getValidMoves(piece, boardConfig!);
    }
    return [];
  }

  void _executeMove(Point from, Point to) {
    var result =
        boardType == BoardType.square
            ? square.SquareBoardLogic.executeMove(from, to, board)
            : aadu.AaduPuliLogic.executeMove(from, to, boardConfig!);

    if (result == square.MoveResult.capture ||
        result == square.MoveResult.captureWithMoreJumps ||
        result == aadu.MoveResult.capture) {
      capturedGoats++;
      selectedPiece = null;
      validMoves = [];
    } else {
      selectedPiece = null;
      validMoves = [];
    }
    notifyListeners();
  }

  void update(double dt) {}
  void movePiece(Point from, Point to) {
    _movePiece(from, to);
    notifyListeners();
  }

  void setGameMode(
    GameMode mode, {
    PlayerType? tigerControl,
    PlayerType? goatControl,
    PlayerSide? side,
    Difficulty? diff,
  }) {
    gameMode = mode;
    if (mode == GameMode.pvc) {
      if (side == PlayerSide.tiger) {
        tigerPlayer = PlayerType.human;
        goatPlayer = PlayerType.computer;
      } else {
        tigerPlayer = PlayerType.computer;
        goatPlayer = PlayerType.human;
      }
      playerSide = side ?? PlayerSide.tiger;
      difficulty = diff ?? Difficulty.easy;
    } else {
      tigerPlayer = PlayerType.human;
      goatPlayer = PlayerType.human;
      playerSide = PlayerSide.tiger;
      difficulty = Difficulty.easy; 
    }
    debugPrint("Game Mode Set: $gameMode, Difficulty: $difficulty");
  }

  bool get isTigerTurn => currentTurn == PieceType.tiger;
  bool get isGoatTurn => currentTurn == PieceType.goat;
  void _checkWinConditions() {
    bool win = false;
    String? message;
    if (boardType == BoardType.square) {
      if (square.SquareBoardLogic.checkTigerWin(capturedGoats)) {
        win = true;
        message = 'Tigers Win!';
      } else if (square.SquareBoardLogic.checkGoatWin(board)) {
        win = true;
        message = 'Goats Win!';
      }
      if (_areAllTigersBlocked()) {
        _showGameOver('Goats Win! (Tigers Blocked)');
        return;
      }
    } else {
      if (aadu.AaduPuliLogic.checkTigerWin(capturedGoats)) {
        win = true;
        message = 'Tigers Win!';
      } else if (aadu.AaduPuliLogic.checkGoatWin(boardConfig!)) {
        win = true;
        message = 'Goats Win!';
      }
    }
    if (win) {
      _showGameOver(message!);
    }
  }

  void _showGameOver(String message) {
    gameMessage = message;
    notifyListeners();
  }

  void _movePiece(Point from, Point to) {
    final isJump = (to.x - from.x).abs() == 2 || (to.y - from.y).abs() == 2;

    to.type = from.type;
    from.type = PieceType.empty;

    if (isJump) {
      int capturedX = from.x + (to.x - from.x) ~/ 2;
      int capturedY = from.y + (to.y - from.y) ~/ 2;
      if (board[capturedX][capturedY].type == PieceType.goat) {
        board[capturedX][capturedY].type = PieceType.empty;
        capturedGoats++;
      }
    }
  }

  void _playTurnAudio() {
    final context = _findContext();
    if (context == null) return;
    final audio = Provider.of<BackgroundAudioProvider>(context, listen: false);
    if (currentTurn == PieceType.goat) {
      audio.playGoatTurnAudio();
    } else if (currentTurn == PieceType.tiger) {
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

  Map<String, Point> _minimaxMove(
    List<Map<String, Point>> moves,
    int depth,
    bool maximizingPlayer,
    double alpha,
    double beta,
  ) {
    Map<String, Point>? bestMove;
    double bestValue =
        maximizingPlayer ? double.negativeInfinity : double.infinity;

    for (final move in moves) {
      var boardClone =
          boardType == BoardType.square ? _cloneSquareBoard(board) : null;
      var boardConfigClone =
          boardType == BoardType.aaduPuli && boardConfig != null
              ? _cloneAaduPuliConfig(boardConfig!)
              : null;
      int capturedGoatsClone = capturedGoats;
      int placedGoatsClone = placedGoats;
      PieceType currentTurnClone = currentTurn;

      if (boardType == BoardType.square) {
        square.SquareBoardLogic.executeMove(
          move['from']!,
          move['to']!,
          boardClone!,
        );
      } else if (boardType == BoardType.aaduPuli && boardConfigClone != null) {
        aadu.AaduPuliLogic.executeMove(
          move['from']!,
          move['to']!,
          boardConfigClone,
        );
      }
      bool isCapture = !_areAdjacent(move['from']!, move['to']!);
      if (isCapture) capturedGoatsClone++;
      PieceType nextTurn =
          currentTurnClone == PieceType.tiger
              ? PieceType.goat
              : PieceType.tiger;

      double value;
      if (depth == 0) {
        value = _evaluateBoardState(
          boardType == BoardType.square ? boardClone : null,
          boardType == BoardType.aaduPuli ? boardConfigClone : null,
          capturedGoatsClone,
          placedGoatsClone,
          nextTurn,
        );
      } else {
        List<Map<String, Point>> nextMoves = [];
        if (boardType == BoardType.square && boardClone != null) {
          for (var row in boardClone) {
            for (var piece in row.where((p) => p.type == nextTurn)) {
              final valid = square.SquareBoardLogic.getValidMoves(
                piece,
                boardClone,
              );
              for (var to in valid) {
                nextMoves.add({'from': piece, 'to': to});
              }
            }
          }
        } else if (boardType == BoardType.aaduPuli &&
            boardConfigClone != null) {
          for (final piece in boardConfigClone.nodes.where(
            (n) => n.type == nextTurn,
          )) {
            final valid = aadu.AaduPuliLogic.getValidMoves(
              piece,
              boardConfigClone,
            );
            for (final to in valid) {
              nextMoves.add({'from': piece, 'to': to});
            }
          }
        }
        if (nextMoves.isEmpty) {
          value = _evaluateBoardState(
            boardType == BoardType.square ? boardClone : null,
            boardType == BoardType.aaduPuli ? boardConfigClone : null,
            capturedGoatsClone,
            placedGoatsClone,
            nextTurn,
          );
        } else {
          value = _minimaxValue(
            nextMoves,
            depth - 1,
            !maximizingPlayer,
            alpha,
            beta,
            boardClone,
            boardConfigClone,
            capturedGoatsClone,
            placedGoatsClone,
            nextTurn,
          );
        }
      }
      if (maximizingPlayer) {
        if (value > bestValue) {
          bestValue = value;
          bestMove = move;
        }
        alpha = alpha > value ? alpha : value;
        if (beta <= alpha) break;
      } else {
        if (value < bestValue) {
          bestValue = value;
          bestMove = move;
        }
        beta = beta < value ? beta : value;
        if (beta <= alpha) break;
      }
    }
    return bestMove ?? moves.first;
  }

  double _minimaxValue(
    List<Map<String, Point>> moves,
    int depth,
    bool maximizingPlayer,
    double alpha,
    double beta,
    List<List<Point>>? boardClone,
    BoardConfig? boardConfigClone,
    int capturedGoatsClone,
    int placedGoatsClone,
    PieceType currentTurnClone,
  ) {
    double bestValue =
        maximizingPlayer ? double.negativeInfinity : double.infinity;
    for (final move in moves) {
      var bClone =
          boardType == BoardType.square
              ? _cloneSquareBoard(boardClone ?? board)
              : null;
      var bcClone =
          boardType == BoardType.aaduPuli && boardConfigClone != null
              ? _cloneAaduPuliConfig(boardConfigClone)
              : null;
      int cgClone = capturedGoatsClone;
      int pgClone = placedGoatsClone;
      if (boardType == BoardType.square && bClone != null) {
        square.SquareBoardLogic.executeMove(move['from']!, move['to']!, bClone);
      } else if (boardType == BoardType.aaduPuli && bcClone != null) {
        aadu.AaduPuliLogic.executeMove(move['from']!, move['to']!, bcClone);
      }
      bool isCapture = !_areAdjacent(move['from']!, move['to']!);
      if (isCapture) cgClone++;
      PieceType nextTurn =
          currentTurnClone == PieceType.tiger
              ? PieceType.goat
              : PieceType.tiger;
      double value;
      if (depth == 0) {
        value = _evaluateBoardState(
          boardType == BoardType.square ? bClone : null,
          boardType == BoardType.aaduPuli ? bcClone : null,
          cgClone,
          pgClone,
          nextTurn,
        );
      } else {
        List<Map<String, Point>> nextMoves = [];
        if (boardType == BoardType.square && bClone != null) {
          for (var row in bClone) {
            for (var piece in row.where((p) => p.type == nextTurn)) {
              final valid = square.SquareBoardLogic.getValidMoves(
                piece,
                bClone,
              );
              for (var to in valid) {
                nextMoves.add({'from': piece, 'to': to});
              }
            }
          }
        } else if (boardType == BoardType.aaduPuli && bcClone != null) {
          for (final piece in bcClone.nodes.where((n) => n.type == nextTurn)) {
            final valid = aadu.AaduPuliLogic.getValidMoves(piece, bcClone);
            for (final to in valid) {
              nextMoves.add({'from': piece, 'to': to});
            }
          }
        }
        if (nextMoves.isEmpty) {
          value = _evaluateBoardState(
            boardType == BoardType.square ? bClone : null,
            boardType == BoardType.aaduPuli ? bcClone : null,
            cgClone,
            pgClone,
            nextTurn,
          );
        } else {
          value = _minimaxValue(
            nextMoves,
            depth - 1,
            !maximizingPlayer,
            alpha,
            beta,
            bClone,
            bcClone,
            cgClone,
            pgClone,
            nextTurn,
          );
        }
      }
      if (maximizingPlayer) {
        if (value > bestValue) {
          bestValue = value;
        }
        alpha = alpha > value ? alpha : value;
        if (beta <= alpha) break;
      } else {
        if (value < bestValue) {
          bestValue = value;
        }
        beta = beta < value ? beta : value;
        if (beta <= alpha) break;
      }
    }
    return bestValue;
  }

  List<List<Point>> _cloneSquareBoard(List<List<Point>> original) {
    var points = List.generate(
      5,
      (x) => List.generate(5, (y) {
        final p = original[x][y];
        return Point(x: p.x, y: p.y, type: p.type, adjacentPoints: []);
      }),
    );
    for (var x = 0; x < 5; x++) {
      for (var y = 0; y < 5; y++) {
        final p = points[x][y];
        final orig = original[x][y];
        p.adjacentPoints =
            orig.adjacentPoints.map((adj) => points[adj.x][adj.y]).toList();
      }
    }
    return points;
  }

  BoardConfig _cloneAaduPuliConfig(BoardConfig original) {
    final nodes =
        original.nodes
            .map(
              (p) => Point(
                x: p.x,
                y: p.y,
                type: p.type,
                id: p.id,
                position: p.position,
                adjacentPoints: [],
              ),
            )
            .toList();
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].adjacentPoints =
          original.nodes[i].adjacentPoints.map((adj) {
            final idx = original.nodes.indexOf(adj);
            return nodes[idx];
          }).toList();
    }
    return BoardConfig(nodes: nodes, connections: original.connections);
  }

  double _evaluateBoardState(
    List<List<Point>>? boardEval,
    BoardConfig? configEval,
    int capturedGoatsEval,
    int placedGoatsEval,
    PieceType turnEval,
  ) {
    if (boardType == BoardType.square && boardEval != null) {
      int tigersBlocked =
          boardEval
              .expand((row) => row)
              .where(
                (p) =>
                    p.type == PieceType.tiger &&
                    square.SquareBoardLogic.getValidMoves(p, boardEval).isEmpty,
              )
              .length;
      int goatsCaptured = capturedGoatsEval;
      int goatsAdjacentToTiger =
          boardEval
              .expand((row) => row)
              .where(
                (p) =>
                    p.type == PieceType.goat &&
                    p.adjacentPoints.any((adj) => adj.type == PieceType.tiger),
              )
              .length;
      int availableTigerMoves = boardEval
          .expand((row) => row)
          .where((p) => p.type == PieceType.tiger)
          .fold(
            0,
            (sum, tiger) =>
                sum +
                square.SquareBoardLogic.getValidMoves(tiger, boardEval).length,
          );
      if (turnEval == PieceType.goat) {
        return _evaluateGoatState(
          tigersBlocked,
          goatsCaptured,
          goatsAdjacentToTiger,
        ).toDouble();
      } else {
        return _evaluateTigerState(
          goatsCaptured,
          tigersBlocked,
          availableTigerMoves,
        ).toDouble();
      }
    } else if (boardType == BoardType.aaduPuli && configEval != null) {
      int tigersBlocked =
          configEval.nodes
              .where(
                (p) =>
                    p.type == PieceType.tiger &&
                    aadu.AaduPuliLogic.getValidMoves(p, configEval).isEmpty,
              )
              .length;
      int goatsCaptured = capturedGoatsEval;
      int goatsAdjacentToTiger =
          configEval.nodes
              .where(
                (p) =>
                    p.type == PieceType.goat &&
                    p.adjacentPoints.any((adj) => adj.type == PieceType.tiger),
              )
              .length;
      int availableTigerMoves = configEval.nodes
          .where((p) => p.type == PieceType.tiger)
          .fold(
            0,
            (sum, tiger) =>
                sum +
                aadu.AaduPuliLogic.getValidMoves(tiger, configEval).length,
          );
      if (turnEval == PieceType.goat) {
        return _evaluateGoatState(
          tigersBlocked,
          goatsCaptured,
          goatsAdjacentToTiger,
        ).toDouble();
      } else {
        return _evaluateTigerState(
          goatsCaptured,
          tigersBlocked,
          availableTigerMoves,
        ).toDouble();
      }
    }
    return 0.0;
  }

  double _evaluateGoatState(
    int tigersBlocked,
    int goatsCaptured,
    int goatsAdjacentToTiger,
  ) {
    return (tigersBlocked * 5) -
        (goatsCaptured * 3) +
        (goatsAdjacentToTiger * 2);
  }

  double _evaluateTigerState(
    int goatsCaptured,
    int tigersBlocked,
    int availableMoves,
  ) {
    return (goatsCaptured * 5) - (tigersBlocked * 4) + (availableMoves * 2);
  }

  bool _areAllTigersBlocked() {
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      if (square.SquareBoardLogic.getValidMoves(tiger, board).isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  double _evaluateBoardStateForGoats(List<List<Point>> boardState) {
    int tigerMoves = boardState.expand((row) => row)
        .where((p) => p.type == PieceType.tiger)
        .fold(0, (sum, tiger) => sum + square.SquareBoardLogic.getValidMoves(tiger, boardState).length);

    int goatMoves = boardState.expand((row) => row)
        .where((p) => p.type == PieceType.goat)
        .fold(0, (sum, goat) => sum + square.SquareBoardLogic.getValidMoves(goat, boardState).length);

    int wallGoats = boardState[2].where((p) => p.type == PieceType.goat).length;

    int unsafeGoats = boardState.expand((row) => row)
        .where((p) => p.type == PieceType.goat && !_isGoatPositionSafe(p))
        .length;

    double tigerMobilityScore = (20 - tigerMoves) * 10.0; 
    double wallScore = wallGoats * 20.0; 
    double unsafePenalty = unsafeGoats * -50.0; 

    return tigerMobilityScore + wallScore + goatMoves * 1.0 + unsafePenalty;
  }

  Map<String, Point> _chooseHardMove(List<Map<String, Point>> allMoves) {
    double bestScore = double.negativeInfinity;
    Map<String, Point>? bestMove;

    for (final move in allMoves) {
      var boardClone = _cloneSquareBoard(board);
      var from = boardClone[move['from']!.x][move['from']!.y];
      var to = boardClone[move['to']!.x][move['to']!.y];
      from.type = PieceType.empty;
      to.type = PieceType.goat;

      List<Map<String, Point>> tigerMoves = [];
      for (var row in boardClone) {
        for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
          var validMoves = square.SquareBoardLogic.getValidMoves(tiger, boardClone);
          for (var tigerMove in validMoves) {
            tigerMoves.add({'from': tiger, 'to': tigerMove});
          }
        }
      }

      double worstTigerScore = double.infinity;
      for (final tigerMove in tigerMoves) {
        var tigerBoardClone = _cloneSquareBoard(boardClone);
        var tigerFrom = tigerBoardClone[tigerMove['from']!.x][tigerMove['from']!.y];
        var tigerTo = tigerBoardClone[tigerMove['to']!.x][tigerMove['to']!.y];
        tigerFrom.type = PieceType.empty;
        tigerTo.type = PieceType.tiger;

        double score = _evaluateBoardStateForGoats(tigerBoardClone);
        worstTigerScore = score < worstTigerScore ? score : worstTigerScore;
      }

      if (worstTigerScore > bestScore) {
        bestScore = worstTigerScore;
        bestMove = move;
      }
    }

    return bestMove!;
  }

  void cancelComputerMoveTimer() {
    _computerMoveTimer?.cancel();
    _computerMoveTimer = null;
  }

  void scheduleComputerMove({
    Duration duration = const Duration(milliseconds: 500),
  }) {
    if (isPaused || !isComputerTurn() || gameMessage != null) return;
    cancelComputerMoveTimer();
    _computerMoveTimer = Timer(duration, () {
      if (!isPaused) {
        makeComputerMove();
      }
    });
  }

  void pauseGame() {
    if (isPaused) return;
    isPaused = true;
    cancelComputerMoveTimer();
    _pauseTimer();
    notifyListeners();
  }

  void resumeGame() {
    if (!isPaused) return;
    isPaused = false;
    _resumeTimer();
    notifyListeners();
    if (isComputerTurn() && gameMessage == null) {
      scheduleComputerMove();
    }
  }

  @override
  void dispose() {
    cancelComputerMoveTimer();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedTime += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _pauseTimer() {
    _gameTimer?.cancel();
  }

  void _resumeTimer() {
    if (_gameTimer == null || !_gameTimer!.isActive) {
      _startTimer();
    }
  }

  bool _areAllGoatsBlocked() {
    if (boardType == BoardType.square) {
      for (var row in board) {
        for (var goat in row.where((p) => p.type == PieceType.goat)) {
          if (square.SquareBoardLogic.getValidMoves(goat, board).isNotEmpty) {
            return false;
          }
        }
      }
      return true;
    } else if (boardConfig != null) {
      for (var goat in boardConfig!.nodes.where(
        (n) => n.type == PieceType.goat,
      )) {
        if (aadu.AaduPuliLogic.getValidMoves(goat, boardConfig!).isNotEmpty) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  bool _tigerCanCaptureAfter(List<List<Point>> boardState, Point goatPosition) {
    for (var tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, boardState);
      for (var move in tigerMoves) {
        if ((move.x - tiger.x).abs() == 2 || (move.y - tiger.y).abs() == 2) {
          int midX = (tiger.x + move.x) ~/ 2;
          int midY = (tiger.y + move.y) ~/ 2;
          if (midX == goatPosition.x && midY == goatPosition.y) {
            return true; 
          }
        }
      }
    }
    return false;
  }

  int _calculateTigerMobility(List<List<Point>> boardState) {
    int mobility = 0;
    for (var tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      mobility += square.SquareBoardLogic.getValidMoves(tiger, boardState).length;
    }
    return mobility;
  }


  double _clusterBonus(List<List<Point>> boardState, Point goatPosition) {
    return goatPosition.adjacentPoints
        .where((adj) => adj.type == PieceType.goat)
        .length
        .toDouble();
  }


  double _calculateBlockScore(Point goatPosition) {
    double score = 0.0;
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, board);
      for (var move in tigerMoves) {
        if ((move.x - tiger.x).abs() == 2 || (move.y - tiger.y).abs() == 2) {
          int midX = (tiger.x + move.x) ~/ 2;
          int midY = (tiger.y + move.y) ~/ 2;
          if (midX == goatPosition.x && midY == goatPosition.y) {
            score += 10.0;
          }
        }
      }
    }
    return score;
  }

  bool _reducesTigerMobility(Point goatPosition) {
    var boardClone = _cloneSquareBoard(board);

    var simulatedGoat = boardClone[goatPosition.x][goatPosition.y];
    simulatedGoat.type = PieceType.goat;

    int initialMobility = _calculateTigerMobility(board);
    int reducedMobility = _calculateTigerMobility(boardClone);

    return reducedMobility < initialMobility;
  }

  double _evaluateRisk(Point point) {
    double risk = 0.0;
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, board);
      for (var move in tigerMoves) {
        if ((move.x - tiger.x).abs() == 2 || (move.y - tiger.y).abs() == 2) {
          int midX = (tiger.x + move.x) ~/ 2;
          int midY = (tiger.y + move.y) ~/ 2;
          if (midX == point.x && midY == point.y) {
            risk += 100.0; // High risk if the tiger can capture the goat
          }
        }
      }
    }
    return risk;
  }

}