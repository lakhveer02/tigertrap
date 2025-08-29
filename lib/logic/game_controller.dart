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

class _JumpThreat {
  final Point tiger;
  final Point victim;
  final Point landing;
  const _JumpThreat({required this.tiger, required this.victim, required this.landing});
}

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
  String? lastGoatMoveKey;

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
      // Preserve selection and validity before executing, so logs are accurate
      final Point? fromBefore = selectedPiece;
      final List<Point> validBefore = fromBefore != null ? _getValidMoves(fromBefore) : const [];
      final bool willMove = fromBefore != null && validBefore.contains(point);
      _handleMovement(point);
      if (willMove) {
        debugPrint(
          "Moved piece from ${fromBefore!.x}, ${fromBefore.y} to ${point.x}, ${point.y}",
        );
      }
    }
    // _playTurnAudio();
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
    final PieceType movedSide = currentTurn;
    if (currentTurn == PieceType.tiger) {
      if (boardType == BoardType.square) {
        _makeSquareComputerMove();
      } else {
        _makeAaduPuliComputerMove();
      }
    } else if (currentTurn == PieceType.goat) {
      _makeGoatComputerMove();
    }
    // _playTurnAudio();
    _checkWinConditions();

    // Only schedule another computer move if the turn actually switched
    // to the opponent and that opponent is also controlled by the computer.
    if (gameMode == GameMode.pvc &&
        gameMessage == null &&
        isComputerTurn() &&
        currentTurn != movedSide) {
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
    currentTurn = currentTurn == PieceType.tiger ? PieceType.goat : PieceType.tiger;
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
    currentTurn = currentTurn == PieceType.tiger ? PieceType.goat : PieceType.tiger;
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
    // Collect all empty positions depending on board type
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

    // --- Priority 0: If any placement immediately blocks all tigers, do it (win the game) ---
    if (difficulty == Difficulty.hard) {
      if (boardType == BoardType.square) {
        for (final p in emptyPoints) {
          final clone = _cloneSquareBoard(board);
          clone[p.x][p.y].type = PieceType.goat;
          if (_areAllTigersBlockedOn(clone)) {
            debugPrint("[hard AI] Placement wins the game by blocking all tigers at ${p.x}, ${p.y}");
            _placeGoat(p);
            _checkWinConditions();
            return;
          }
        }
      } else if (boardConfig != null) {
        for (final p in emptyPoints) {
          final cfgClone = _cloneAaduPuliConfig(boardConfig!);
          final cPoint = cfgClone.nodes.firstWhere((n) => n.id == p.id);
          cPoint.type = PieceType.goat;
          if (_areAllTigersBlockedOnConfig(cfgClone)) {
            debugPrint("[hard AI] Placement wins the game by blocking all tigers (Aadu Puli) at ${p.x}, ${p.y}");
            _placeGoat(p);
            _checkWinConditions();
            return;
          }
        }
      }
    }

    // Hard mode priority 1: block imminent tiger jumps by occupying landing squares
    if (difficulty == Difficulty.hard) {
      final threats = _getCurrentJumpThreats();
      // Collect SAFE landing blocks, then choose the best-scoring one
      final List<Point> safeLandingBlocks = [];
      final List<Point> allLandingBlocks = [];
      for (final t in threats) {
        final landing = t.landing;
        if (landing.type != PieceType.empty) continue;
        allLandingBlocks.add(landing);
        if (boardType == BoardType.square) {
          final bClone = _cloneSquareBoard(board);
          final landC = bClone[landing.x][landing.y];
          landC.type = PieceType.goat;
          if (!_tigerCanCaptureAfter(bClone, landC)) {
            safeLandingBlocks.add(landing);
          }
        } else if (boardConfig != null) {
          final cfg = _cloneAaduPuliConfig(boardConfig!);
          final landC = cfg.nodes.firstWhere((n) => n.id == landing.id);
          landC.type = PieceType.goat;
          if (!_tigerCanCaptureAfterConfig(cfg, landC)) {
            safeLandingBlocks.add(landing);
          }
        }
      }
      if (safeLandingBlocks.isNotEmpty) {
        Point? bestSafeBlock;
        double bestBlockScore = double.negativeInfinity;
        if (boardType == BoardType.square) {
          for (final landing in safeLandingBlocks) {
            final bClone = _cloneSquareBoard(board);
            final landC = bClone[landing.x][landing.y];
            landC.type = PieceType.goat;
            double score = 0;
            score += _calculateOuterWallScore(landing) * 600;
            score += _calculateBlockScoreForBoard(bClone, landC) * 300;
            score += _clusterBonus(bClone, landC) * 150;
            final int initialMobility = _calculateTigerMobility(board);
            final int reducedMobility = _calculateTigerMobility(bClone);
            score += (reducedMobility < initialMobility) ? 200.0 : 0.0;
            // Prefer placements that reduce total jump threats
            final int threatsBefore = _countJumpThreatsOn(board);
            final int threatsAfter = _countJumpThreatsOn(bClone);
            score += (threatsBefore - threatsAfter) * 500.0;
            if (score > bestBlockScore) {
              bestBlockScore = score;
              bestSafeBlock = landing;
            }
          }
        } else if (boardConfig != null) {
          for (final landing in safeLandingBlocks) {
            final cfg = _cloneAaduPuliConfig(boardConfig!);
            final landC = cfg.nodes.firstWhere((n) => n.id == landing.id);
            landC.type = PieceType.goat;
            double score = 0;
            score += _clusterBonusConfig(cfg, landC) * 150;
            score += _reducesTigerMobilityConfig(cfg, landC) ? 200.0 : 0.0;
            score += _calculateBlockScoreConfig(cfg, landC) * 300;
            // Prefer placements that reduce total jump threats
            final int threatsBefore = _countJumpThreatsOnConfig(boardConfig!);
            final int threatsAfter = _countJumpThreatsOnConfig(cfg);
            score += (threatsBefore - threatsAfter) * 500.0;
            if (score > bestBlockScore) {
              bestBlockScore = score;
              bestSafeBlock = landing;
            }
          }
        }
        if (bestSafeBlock != null) {
          debugPrint("[hard AI] Blocking tiger jump by placing at ${bestSafeBlock.x}, ${bestSafeBlock.y}");
          _placeGoat(bestSafeBlock);
          return;
        }
      } else if (allLandingBlocks.isNotEmpty) {
        // Fallback: pick the landing block that most reduces imminent jump threats even if unsafe
        Point? bestBlock;
        double bestScore = double.negativeInfinity;
        if (boardType == BoardType.square) {
          final int threatsBefore = _countJumpThreatsOn(board);
          for (final landing in allLandingBlocks) {
            // Avoid repeating previously unsafe fallback placements
            if (unsafeMoveHistory.contains('${landing.x},${landing.y}')) {
              continue;
            }
            final bClone = _cloneSquareBoard(board);
            final landC = bClone[landing.x][landing.y];
            landC.type = PieceType.goat;
            final int threatsAfter = _countJumpThreatsOn(bClone);
            double score = (threatsBefore - threatsAfter) * 1000.0;
            // Strongly prefer edges/corners on unsafe fallback to avoid inner traps
            score += _calculateOuterWallScore(landing) * 800;
            score += _clusterBonus(bClone, landC) * 50;
            if (score > bestScore) {
              bestScore = score;
              bestBlock = landing;
            }
          }
        } else if (boardConfig != null) {
          final int threatsBefore = _countJumpThreatsOnConfig(boardConfig!);
          for (final landing in allLandingBlocks) {
            // Avoid repeating previously unsafe fallback placements
            if (unsafeMoveHistory.contains('${landing.x},${landing.y}')) {
              continue;
            }
            final cfg = _cloneAaduPuliConfig(boardConfig!);
            final landC = cfg.nodes.firstWhere((n) => n.id == landing.id);
            landC.type = PieceType.goat;
            final int threatsAfter = _countJumpThreatsOnConfig(cfg);
            double score = (threatsBefore - threatsAfter) * 1000.0;
            score += _clusterBonusConfig(cfg, landC) * 50;
            if (score > bestScore) {
              bestScore = score;
              bestBlock = landing;
            }
          }
        }
        if (bestBlock != null) {
          debugPrint("[hard AI] Blocking tiger jump by placing (unsafe fallback) at ${bestBlock.x}, ${bestBlock.y}");
          // Record this unsafe fallback position so we do not repeat it
          unsafeMoveHistory.add('${bestBlock.x},${bestBlock.y}');
          _placeGoat(bestBlock);
          return;
        }
      }
      // If there are no landing blocks, continue with other priorities
    }

    // Hard mode priority 1.5: preempt future tiger jumps (after a single tiger step)
    if (difficulty == Difficulty.hard && boardType == BoardType.square) {
      final nextTurnLandingCandidates = _predictNextTurnLandingBlocksSquare();
      if (nextTurnLandingCandidates.isNotEmpty) {
        Point? bestFutureBlock;
        double bestFutureScore = double.negativeInfinity;
        for (final cand in nextTurnLandingCandidates) {
          final bClone = _cloneSquareBoard(board);
          final landC = bClone[cand.x][cand.y];
          landC.type = PieceType.goat;
          // Avoid placements where the new goat is immediately capturable
          if (_tigerCanCaptureAfter(bClone, landC)) {
            continue;
          }
          double score = 0.0;
          // Prefer outer edges slightly less than direct blocks
          score += _calculateOuterWallScore(cand) * 400;
          // Prefer placements that reduce predicted next-turn jump threats
          final int preThreatsBefore = _countNextTurnJumpThreatsOn(board);
          final int preThreatsAfter = _countNextTurnJumpThreatsOn(bClone);
          score += (preThreatsBefore - preThreatsAfter) * 600.0;
          // Minor cluster/connectivity bonuses
          score += _clusterBonus(bClone, landC) * 150;
          final int initialMobility = _calculateTigerMobility(board);
          final int reducedMobility = _calculateTigerMobility(bClone);
          score += (reducedMobility < initialMobility) ? 200.0 : 0.0;
          if (score > bestFutureScore) {
            bestFutureScore = score;
            bestFutureBlock = cand;
          }
        }
        if (bestFutureBlock != null) {
          debugPrint("[hard AI] Preemptively blocking future jump by placing at ${bestFutureBlock.x}, ${bestFutureBlock.y}");
          _placeGoat(bestFutureBlock);
          return;
        }
      }
    }

    // Hard mode priority 2: on square board, strictly cover outer walls before center until edges filled
    if (difficulty == Difficulty.hard && boardType == BoardType.square) {
      final wallEmpties = emptyPoints.where(_isEdgeSquare).toList();
      if (wallEmpties.isNotEmpty) {
        emptyPoints = wallEmpties;
      }
    }

    // Hard mode priority 2.2: deterministic opening sequence to progressively cage tigers
    // Follows a perimeter-first then key-center pattern matching the provided strategy
    if (difficulty == Difficulty.hard && boardType == BoardType.square) {
      final Point? openingPick = _nextOpeningBookPlacementSquare(onlyFrom: emptyPoints);
      if (openingPick != null) {
        debugPrint("[hard AI] Opening sequence: placing at ${openingPick.x}, ${openingPick.y}");
        _placeGoat(openingPick);
        return;
      }
    }

    // Hard mode priority 3: if any placement immediately blocks all tigers, do it
    if (difficulty == Difficulty.hard) {
      if (boardType == BoardType.square) {
        for (final p in emptyPoints) {
          final clone = _cloneSquareBoard(board);
          clone[p.x][p.y].type = PieceType.goat;
          if (_areAllTigersBlockedOn(clone)) {
            debugPrint("[hard AI] Placement traps tigers; placing at ${p.x}, ${p.y}");
            _placeGoat(p);
            return;
          }
        }
      } else if (boardConfig != null) {
        for (final p in emptyPoints) {
          final cfgClone = _cloneAaduPuliConfig(boardConfig!);
          final cPoint = cfgClone.nodes.firstWhere((n) => n.id == p.id);
          cPoint.type = PieceType.goat;
          if (_areAllTigersBlockedOnConfig(cfgClone)) {
            debugPrint("[hard AI] Placement traps tigers (Aadu Puli); placing at ${p.x}, ${p.y}");
            _placeGoat(p);
            return;
          }
        }
      }
    }

    // Choose best placement by board type
    Point? bestPlacement;
    double bestScore = double.negativeInfinity;

    if (boardType == BoardType.square) {
      for (var point in emptyPoints) {
        if (unsafeMoveHistory.contains('${point.x},${point.y}')) continue;
        // Simulate on a cloned board; do not mutate the real board
        final boardClone = _cloneSquareBoard(board);
        final simulated = boardClone[point.x][point.y];
        simulated.type = PieceType.goat;

        // Hard mode: skip clearly unsafe placements
        if (difficulty == Difficulty.hard && _tigerCanCaptureAfter(boardClone, simulated)) {
          continue;
        }

        double score = 0;
        // Stronger emphasis on edges until fully covered
        score += _calculateOuterWallScore(point) * (placedGoats <= 12 ? 1200 : 400);
        score += _calculateBlockScoreForBoard(boardClone, simulated) * 400;
        score += _clusterBonus(boardClone, simulated) * 250;

        // Mobility reduction compared to current board
        final int initialMobility = _calculateTigerMobility(board);
        final int reducedMobility = _calculateTigerMobility(boardClone);
        score += (reducedMobility < initialMobility) ? 350.0 : 0.0;

        // Pessimistic tiger response from this simulated state
        double worstTigerScore = double.infinity;
        for (var tiger in boardClone.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
          var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, boardClone);
          for (var move in tigerMoves) {
            var tigerBoard = _cloneSquareBoard(boardClone);
            var from = tigerBoard[tiger.x][tiger.y];
            var to = tigerBoard[move.x][move.y];
            from.type = PieceType.empty;
            to.type = PieceType.tiger;
            double tigerScore = _evaluateBoardStateForGoats(tigerBoard);
            worstTigerScore = tigerScore < worstTigerScore ? tigerScore : worstTigerScore;
          }
        }
        score -= worstTigerScore * 0.35;

        if (score > bestScore) {
          bestScore = score;
          bestPlacement = point;
        }
      }
    } else if (boardConfig != null) {
      for (var point in emptyPoints) {
        final isSafe = _isGoatPositionSafeForAaduPuli(point);
        if (difficulty == Difficulty.hard && !isSafe) continue;

        // simulate
        final cfgClone = _cloneAaduPuliConfig(boardConfig!);
        final clonePoint = cfgClone.nodes.firstWhere((n) => n.id == point.id);
        clonePoint.type = PieceType.goat;

        double score = 0;
        score += _clusterBonusConfig(cfgClone, clonePoint) * 150;
        score += _reducesTigerMobilityConfig(cfgClone, clonePoint) ? 200.0 : 0.0;
        score += _calculateBlockScoreConfig(cfgClone, clonePoint) * 300;

        if (score > bestScore) {
          bestScore = score;
          bestPlacement = point;
        }
      }
    }

    if (bestPlacement != null) {
      if (!_isGoatPositionSafe(bestPlacement)) {
        debugPrint("[hard AI] WARNING: Chosen placement at ${bestPlacement.x}, ${bestPlacement.y} is unsafe");
      } else {
        debugPrint("[hard AI] Placing goat at ${bestPlacement.x}, ${bestPlacement.y} with score $bestScore");
      }
      _placeGoat(bestPlacement);
      return;
    }

    // Fallback: safest available position
    final safeEmpties = <Point>[];
    if (boardType == BoardType.square) {
      for (final p in emptyPoints) {
        final clone = _cloneSquareBoard(board);
        final c = clone[p.x][p.y];
        c.type = PieceType.goat;
        if (!_tigerCanCaptureAfter(clone, c)) safeEmpties.add(p);
      }
    } else if (boardConfig != null) {
      for (final p in emptyPoints) {
        final cfg = _cloneAaduPuliConfig(boardConfig!);
        final c = cfg.nodes.firstWhere((n) => n.id == p.id);
        c.type = PieceType.goat;
        if (!_tigerCanCaptureAfterConfig(cfg, c)) safeEmpties.add(p);
      }
    }

    final candidates = safeEmpties.isNotEmpty ? safeEmpties : emptyPoints;
    Point safestPosition = candidates.reduce((a, b) {
      double riskA = _evaluateRisk(a);
      double riskB = _evaluateRisk(b);
      return riskA < riskB ? a : b;
    });

    if (!_isGoatPositionSafe(safestPosition)) {
      debugPrint("[hard AI] WARNING: Fallback placement at ${safestPosition.x}, ${safestPosition.y} is unsafe");
    } else {
      debugPrint("[hard AI] No preferred placements; choosing safest position ${safestPosition.x}, ${safestPosition.y}");
    }
    _placeGoat(safestPosition);
  }

  double _calculateOuterWallScore(Point point) {
    // Prioritize outer wall positions
    if (point.x == 0 || point.x == board.length - 1 || point.y == 0 || point.y == board[0].length - 1) {
      return 1.0; // Outer wall score
    }
    return 0.0;
  }

  void _goatMovementAI() {
    // Build all legal goat moves for current board type
    List<Map<String, Point>> allMoves = [];
    if (boardType == BoardType.square) {
      for (var row in board) {
        for (var goat in row.where((p) => p.type == PieceType.goat)) {
          var validMoves = square.SquareBoardLogic.getValidMoves(goat, board);
          for (var to in validMoves) {
            if (to.type == PieceType.empty) allMoves.add({'from': goat, 'to': to});
          }
        }
      }
    } else if (boardConfig != null) {
      for (var goat in boardConfig!.nodes.where((n) => n.type == PieceType.goat)) {
        var valids = aadu.AaduPuliLogic.getValidMoves(goat, boardConfig!);
        for (var to in valids) {
          if (to.type == PieceType.empty) allMoves.add({'from': goat, 'to': to});
        }
      }
    }

    if (allMoves.isEmpty) {
      debugPrint("[hard AI] No valid moves for goats, skipping turn");
      return;
    }

    // --- Hard mode priority 0: If any move immediately blocks all tigers, do it (win the game) ---
    if (difficulty == Difficulty.hard) {
      if (boardType == BoardType.square) {
        for (final move in allMoves) {
          final boardClone = _cloneSquareBoard(board);
          final from = boardClone[move['from']!.x][move['from']!.y];
          final to = boardClone[move['to']!.x][move['to']!.y];
          from.type = PieceType.empty;
          to.type = PieceType.goat;
          if (_areAllTigersBlockedOn(boardClone)) {
            debugPrint("[hard AI] Move wins the game by blocking all tigers: ${move['from']!.x},${move['from']!.y} -> ${move['to']!.x},${move['to']!.y}");
            _executeMove(move['from']!, move['to']!);
            currentTurn = PieceType.tiger;
            _checkWinConditions();
            return;
          }
        }
      } else if (boardConfig != null) {
        for (final move in allMoves) {
          final cfgClone = _cloneAaduPuliConfig(boardConfig!);
          final fromC = cfgClone.nodes.firstWhere((n) => n.id == move['from']!.id);
          final toC = cfgClone.nodes.firstWhere((n) => n.id == move['to']!.id);
          fromC.type = PieceType.empty;
          toC.type = PieceType.goat;
          if (_areAllTigersBlockedOnConfig(cfgClone)) {
            debugPrint("[hard AI] Move wins the game by blocking all tigers (Aadu Puli): ${move['from']!.x},${move['from']!.y} -> ${move['to']!.x},${move['to']!.y}");
            _executeMove(move['from']!, move['to']!);
            currentTurn = PieceType.tiger;
            _checkWinConditions();
            return;
          }
        }
      }
    }

    // --- NEW: Hard mode priority 1: Prefer moves that maximize the number of blocked tigers ---
    if (difficulty == Difficulty.hard && boardType == BoardType.square) {
      int maxBlocked = -1;
      List<Map<String, Point>> bestMoves = [];
      double bestEval = double.negativeInfinity;
      Map<String, Point>? bestMove;

      for (final move in allMoves) {
        final boardClone = _cloneSquareBoard(board);
        final from = boardClone[move['from']!.x][move['from']!.y];
        final to = boardClone[move['to']!.x][move['to']!.y];
        from.type = PieceType.empty;
        to.type = PieceType.goat;
        int blocked = _countBlockedTigersOn(boardClone);
        if (blocked > maxBlocked) {
          maxBlocked = blocked;
          bestMoves = [move];
          bestEval = _evaluateBoardStateForGoats(boardClone);
          bestMove = move;
        } else if (blocked == maxBlocked) {
          double eval = _evaluateBoardStateForGoats(boardClone);
          if (eval > bestEval) {
            bestEval = eval;
            bestMove = move;
          }
          bestMoves.add(move);
        }
      }
      // Only use this priority if it actually increases the number of blocked tigers
      int currentBlocked = _countBlockedTigersOn(board);
      if (maxBlocked > currentBlocked && bestMove != null) {
        debugPrint("[hard AI] Moving goat to maximize blocked tigers: ${bestMove['from']!.x},${bestMove['from']!.y} -> ${bestMove['to']!.x},${bestMove['to']!.y} (blocked: $maxBlocked)");
        _executeMove(bestMove['from']!, bestMove['to']!);
        currentTurn = PieceType.tiger;
        return;
      }
    }

    // Enhanced logic: Prefer safe moves, but if none, pick the least risky move
    Map<String, Point>? safestMove;
    double bestScore = double.negativeInfinity;
    List<Map<String, Point>> safeMoves = [];

    for (final move in allMoves) {
      if (boardType == BoardType.square) {
        final boardClone = _cloneSquareBoard(board);
        final from = boardClone[move['from']!.x][move['from']!.y];
        final to = boardClone[move['to']!.x][move['to']!.y];
        from.type = PieceType.empty;
        to.type = PieceType.goat;

        // Simulate Tiger's next moves
        bool isUnsafe = false;
        for (var tiger in boardClone.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
          var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, boardClone);
          for (var tigerMove in tigerMoves) {
            if ((tigerMove.x - tiger.x).abs() == 2 || (tigerMove.y - tiger.y).abs() == 2) {
              int midX = (tiger.x + tigerMove.x) ~/ 2;
              int midY = (tiger.y + tigerMove.y) ~/ 2;
              if (midX == to.x && midY == to.y) {
                isUnsafe = true;
                break;
              }
            }
          }
          if (isUnsafe) break;
        }

        if (!isUnsafe) {
          safeMoves.add(move);
        }

        // Evaluate the move
        double score = _evaluateBoardStateForGoats(boardClone);
        if (score > bestScore) {
          bestScore = score;
          safestMove = move;
        }
      } else if (boardConfig != null) {
        final cfgClone = _cloneAaduPuliConfig(boardConfig!);
        final fromC = cfgClone.nodes.firstWhere((n) => n.id == move['from']!.id);
        final toC = cfgClone.nodes.firstWhere((n) => n.id == move['to']!.id);
        fromC.type = PieceType.empty;
        toC.type = PieceType.goat;

        // Simulate Tiger's next moves
        bool isUnsafe = false;
        for (var tiger in cfgClone.nodes.where((n) => n.type == PieceType.tiger)) {
          var tigerMoves = aadu.AaduPuliLogic.getValidMoves(tiger, cfgClone);
          for (var tigerMove in tigerMoves) {
            if (aadu.AaduPuliLogic.isJumpTriple('${tiger.id},${toC.id},${tigerMove.id}')) {
              isUnsafe = true;
              break;
            }
          }
          if (isUnsafe) break;
        }

        if (!isUnsafe) {
          safeMoves.add(move);
        }

        // Evaluate the move (for fallback)
        double score = _evaluateBoardStateForGoats(_cloneSquareBoard(board)); // Adjust for Aadu Puli if needed
        if (score > bestScore) {
          bestScore = score;
          safestMove = move;
        }
      }
    }

    Map<String, Point>? chosenMove;
    if (safeMoves.isNotEmpty) {
      // Prefer safe moves
      double bestSafeScore = double.negativeInfinity;
      for (final move in safeMoves) {
        double score;
        if (boardType == BoardType.square) {
          final boardClone = _cloneSquareBoard(board);
          final from = boardClone[move['from']!.x][move['from']!.y];
          final to = boardClone[move['to']!.x][move['to']!.y];
          from.type = PieceType.empty;
          to.type = PieceType.goat;
          score = _evaluateBoardStateForGoats(boardClone);
        } else if (boardConfig != null) {
          score = _evaluateBoardStateForGoats(_cloneSquareBoard(board)); // Adjust for Aadu Puli if needed
        } else {
          score = 0;
        }
        if (score > bestSafeScore) {
          bestSafeScore = score;
          chosenMove = move;
        }
      }
    } else {
      // No safe moves: pick the least risky move (highest board score)
      chosenMove = safestMove;
    }

    if (chosenMove != null) {
      debugPrint("[hard AI] Moving goat from ${chosenMove['from']!.x}, ${chosenMove['from']!.y} to ${chosenMove['to']!.x}, ${chosenMove['to']!.y} (safe: ${safeMoves.isNotEmpty})");
      _executeMove(chosenMove['from']!, chosenMove['to']!);
      currentTurn = PieceType.tiger;
    } else {
      debugPrint("[hard AI] No moves available, skipping turn");
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
    return _isStrategicBlockOn(board, goatPosition, landingPoint);
  }

  bool _isStrategicBlockOn(
    List<List<Point>> boardState,
    Point goatPosition,
    Point landingPoint,
  ) {
    var boardClone = _cloneSquareBoard(boardState);
    boardClone[goatPosition.x][goatPosition.y].type = PieceType.goat;
    int initialTigerMobility = _calculateTigerMobility(boardState);
    int reducedTigerMobility = _calculateTigerMobility(boardClone);
    return reducedTigerMobility < initialTigerMobility;
  }

  bool _isGoatPositionSafeOn(
    List<List<Point>> boardState,
    Point position, {
    bool log = false,
  }) {
    for (final tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      if ((position.x - tiger.x).abs() <= 1 && (position.y - tiger.y).abs() <= 1) {
        int dx = position.x - tiger.x;
        int dy = position.y - tiger.y;
        int jumpX = position.x + dx;
        int jumpY = position.y + dy;
        if (jumpX >= 0 && jumpX < boardState.length && jumpY >= 0 && jumpY < boardState[0].length) {
          if (boardState[jumpX][jumpY].type == PieceType.empty) {
            if (!_isStrategicBlockOn(boardState, position, Point(x: jumpX, y: jumpY))) {
              if (log) {
                debugPrint("Position ${position.x}, ${position.y} is unsafe due to tiger at ${tiger.x}, ${tiger.y}");
              }
              return false;
            }
          }
        }
      }
    }
    return true;
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

    // In hard mode, we already filtered unsafe placements or decided strategically; avoid noisy logs

    point.type = PieceType.goat;
    if (gameMode == GameMode.pvc) {
      final controller = goatPlayer == PlayerType.computer ? 'AI' : 'Human';
      debugPrint("[confirm] Goat placed at ${point.x}, ${point.y} by $controller");
    }
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
        currentTurn = currentTurn == PieceType.tiger ? PieceType.goat : PieceType.tiger;
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
    final moverType = from.type; // capture before mutation
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
    if (gameMode == GameMode.pvc) {
      final isTigerMove = moverType == PieceType.tiger;
      final controller = isTigerMove
          ? (tigerPlayer == PlayerType.computer ? 'AI' : 'Human')
          : (goatPlayer == PlayerType.computer ? 'AI' : 'Human');
      final side = isTigerMove ? 'Tiger' : 'Goat';
      debugPrint('[confirm] $controller $side moved from ${from.x}, ${from.y} to ${to.x}, ${to.y}');
    }
    // Track last goat move to reduce oscillation in hard mode
    if (moverType == PieceType.goat) {
      lastGoatMoveKey = '${from.x},${from.y}->${to.x},${to.y}';
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
        debugPrint("[hard AI] Win detected: All tigers blocked.");
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
      debugPrint("[hard AI] Win detected: $message");
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

  bool _areAllTigersBlockedOn(List<List<Point>> boardState) {
    for (var tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      if (square.SquareBoardLogic.getValidMoves(tiger, boardState).isNotEmpty) return false;
    }
    return true;
  }

  double _evaluateBoardStateForGoats(List<List<Point>> boardState) {
    // Terms per spec (square board):
    // blockedTigers, tigerMobility, unsafeGoats, goatConnectivity, goatsNearEdges, goatsCaptured
    final int blockedTigers = _countBlockedTigersOn(boardState);
    final int tigerMobility = _calculateTigerMobility(boardState);
    final int unsafeGoats = _countUnsafeGoatsOn(boardState);
    final int goatsNearEdges = _countGoatsNearEdgesOn(boardState);
    final int goatsCapturedNow = capturedGoats; // controller state

    // Connectivity: count adjacent goat pairs (each pair counted once)
    final int goatConnectivity = _goatConnectivityOn(boardState);

    // Dynamic weights: early placement favors edges more; later favor connectivity
    final bool inPlacementPhase = !isGoatMovementPhase;
    final bool earlyPlacement = inPlacementPhase && placedGoats <= 12;
    final double edgesWeight = earlyPlacement ? 20.0 : 6.0;
    final double connectivityWeight = inPlacementPhase && !earlyPlacement ? 10.0 : 8.0;

    // Weighted score (higher is better for goats)
    final double score =
        500.0 * blockedTigers +
        (-12.0) * tigerMobility +
        (-200.0) * unsafeGoats +
        connectivityWeight * goatConnectivity +
        edgesWeight * goatsNearEdges +
        (-80.0) * goatsCapturedNow;

    return score;
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
    // Delegate to board-aware version using the current board
    return _calculateBlockScoreForBoard(board, goatPosition);
  }

  double _calculateBlockScoreForBoard(List<List<Point>> boardState, Point goatPosition) {
    // Reward occupying landing cells of potential tiger jumps (which blocks captures)
    // Penalize occupying the middle cell of a potential jump (which enables capture)
    double score = 0.0;
    for (var tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, boardState);
      for (var move in tigerMoves) {
        if ((move.x - tiger.x).abs() == 2 || (move.y - tiger.y).abs() == 2) {
          // Jump move: middle cell and landing cell
          int midX = (tiger.x + move.x) ~/ 2;
          int midY = (tiger.y + move.y) ~/ 2;
          int landingX = move.x;
          int landingY = move.y;

          // Block by standing on the landing cell
          if (landingX == goatPosition.x && landingY == goatPosition.y) {
            score += 10.0;
          }

          // Discourage standing on the middle cell (enables capture)
          if (midX == goatPosition.x && midY == goatPosition.y) {
            score -= 10.0;
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

  // ===== Square board evaluation helpers per hard-mode spec =====
  int _countBlockedTigersOn(List<List<Point>> boardState) {
    int blocked = 0;
    for (final tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      if (square.SquareBoardLogic.getValidMoves(tiger, boardState).isEmpty) blocked++;
    }
    return blocked;
  }

  // Return predicted landing squares where a tiger could perform a jump after a single legal step (no jump) this turn
  List<Point> _predictNextTurnLandingBlocksSquare() {
    final Set<String> seen = {};
    final List<Point> result = [];
    for (final tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      final moves = square.SquareBoardLogic.getValidMoves(tiger, board);
      for (final dest in moves) {
        // consider only non-jump tiger steps
        if ((dest.x - tiger.x).abs() == 2 || (dest.y - tiger.y).abs() == 2) continue;
        final tb = _cloneSquareBoard(board);
        final tf = tb[tiger.x][tiger.y];
        final tt = tb[dest.x][dest.y];
        tf.type = PieceType.empty;
        tt.type = PieceType.tiger;
        final futureThreats = _getCurrentJumpThreatsOn(tb);
               for (final thr in futureThreats) {
          final lx = thr.landing.x;
          final ly = thr.landing.y;
          if (board[lx][ly].type != PieceType.empty) continue;
          final key = '$lx,$ly';
          if (seen.add(key)) {
            result.add(board[lx][ly]);
          }
        }
      }
    }
    return result;
  }

  // Count current-turn jump threats for the square board
  int _countNextTurnJumpThreatsOn(List<List<Point>> boardState) {
    int total = 0;
    for (final tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      final moves = square.SquareBoardLogic.getValidMoves(tiger, boardState);
      for (final dest in moves) {
        // only non-jump steps
        if ((dest.x - tiger.x).abs() == 2 || (dest.y - tiger.y).abs() == 2) continue;
        final tb = _cloneSquareBoard(boardState);
        final tf = tb[tiger.x][tiger.y];
        final tt = tb[dest.x][dest.y];
        tf.type = PieceType.empty;
        tt.type = PieceType.tiger;
        total += _countJumpThreatsOn(tb);
      }
    }
    return total;
  }

  // Build current jump threats for an arbitrary square board state
  List<_JumpThreat> _getCurrentJumpThreatsOn(List<List<Point>> boardState) {
    final threats = <_JumpThreat>[];
    for (final tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      for (final adj in tiger.adjacentPoints) {
        if (adj.type != PieceType.goat) continue;
        final dx = adj.x - tiger.x;
        final dy = adj.y - tiger.y;
        final lx = adj.x + dx;
        final ly = adj.y + dy;
        if (lx >= 0 && lx < 5 && ly >= 0 && ly < 5) {
          final landing = boardState[lx][ly];
          if (landing.type == PieceType.empty && adj.adjacentPoints.contains(landing)) {
            threats.add(_JumpThreat(tiger: tiger, victim: adj, landing: landing));
          }
        }
      }
    }
    return threats;
  }

  int _countUnsafeGoatsOn(List<List<Point>> boardState) {
    int count = 0;
    for (final goat in boardState.expand((row) => row).where((p) => p.type == PieceType.goat)) {
      if (!_isGoatPositionSafeOn(boardState, goat, log: false)) count++;
    }
    return count;
  }

  int _countGoatsNearEdgesOn(List<List<Point>> boardState) {
    int count = 0;
    final int maxX = boardState.length - 1;
    final int maxY = boardState[0].length - 1;
    for (final p in boardState.expand((row) => row)) {
      if (p.type != PieceType.goat) continue;
      if (p.x == 0 || p.x == maxX || p.y == 0 || p.y == maxY) count++;
    }
    return count;
  }

  int _goatConnectivityOn(List<List<Point>> boardState) {
    int connections = 0;
    final seen = <String>{};
    for (final goat in boardState.expand((row) => row).where((p) => p.type == PieceType.goat)) {
      for (final adj in goat.adjacentPoints) {
        if (adj.type != PieceType.goat) continue;
        final a = '${goat.x},${goat.y}';
        final b = '${adj.x},${adj.y}';
        final key = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
        if (seen.add(key)) connections++;
      }
    }
    return connections;
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

  // ===== Hard mode helper utilities =====
  List<_JumpThreat> _getCurrentJumpThreats() {
    final threats = <_JumpThreat>[];
    if (boardType == BoardType.square) {
      for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
        for (final adj in tiger.adjacentPoints) {
          if (adj.type != PieceType.goat) continue;
          final dx = adj.x - tiger.x;
          final dy = adj.y - tiger.y;
          final lx = adj.x + dx;
          final ly = adj.y + dy;
          if (lx >= 0 && lx < 5 && ly >= 0 && ly < 5) {
            final landing = board[lx][ly];
            if (landing.type == PieceType.empty && adj.adjacentPoints.contains(landing)) {
              threats.add(_JumpThreat(tiger: tiger, victim: adj, landing: landing));
            }
          }
        }
      }
    } else if (boardConfig != null) {
      for (final tiger in boardConfig!.nodes.where((n) => n.type == PieceType.tiger)) {
        for (final goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
          for (final landing in goat.adjacentPoints) {
            if (landing == tiger || landing.type != PieceType.empty) continue;
            final key = '${tiger.id},${goat.id},${landing.id}';
            if (aadu.AaduPuliLogic.isJumpTriple(key)) {
              threats.add(_JumpThreat(tiger: tiger, victim: goat, landing: landing));
            }
          }
        }
      }
    }
    return threats;
  }

  // Count current jump threats on a given square board state
  int _countJumpThreatsOn(List<List<Point>> boardState) {
    int total = 0;
    for (final tiger in boardState.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      for (final adj in tiger.adjacentPoints) {
        if (adj.type != PieceType.goat) continue;
        final dx = adj.x - tiger.x;
        final dy = adj.y - tiger.y;
        final lx = adj.x + dx;
        final ly = adj.y + dy;
        if (lx >= 0 && lx < 5 && ly >= 0 && ly < 5) {
          final landing = boardState[lx][ly];
          if (landing.type == PieceType.empty && adj.adjacentPoints.contains(landing)) {
            total++;
          }
        }
      }
    }
    return total;
  }

  // Count current jump threats on a given Aadu Puli board config
  int _countJumpThreatsOnConfig(BoardConfig cfg) {
    int total = 0;
    for (final tiger in cfg.nodes.where((n) => n.type == PieceType.tiger)) {
      for (final goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
        for (final landing in goat.adjacentPoints) {
          if (landing == tiger || landing.type != PieceType.empty) continue;
          final key = '${tiger.id},${goat.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key)) {
            total++;
          }
        }
      }
    }
    return total;
  }

  bool _isEdgeSquare(Point p) {
    return p.x == 0 || p.x == 4 || p.y == 0 || p.y == 4;
  }

  // ===== Hard-mode opening book for square board goats =====
  // Returns the next preferred opening placement if it's empty and safe
  Point? _nextOpeningBookPlacementSquare({required List<Point> onlyFrom}) {
    // Opening order designed to match the requested blocking sequence
    // Perimeter (excluding tiger corners) -> then center/near-center pattern
    final List<List<int>> order = [
      // Top edge (skip corners because tigers start there)
      [0, 2], [0, 1], [0, 3],
      // Left edge (middle to tighten corner)
      [2, 0], [1, 0], [3, 0],
      // Right edge
      [2, 4], [1, 4], [3, 4],
      // Bottom edge (skip corners)
      [4, 1], [4, 2], [4, 3],
      // Interior key points
      [2, 2], [3, 1], [1, 1], [2, 1], [3, 2], [1, 3], [3, 3],
    ];

    // Build a quick lookup of allowed candidates based on the caller's filtered list
    final Set<String> allowed = onlyFrom.map((p) => '${p.x},${p.y}').toSet();

    for (final xy in order) {
      final int x = xy[0];
      final int y = xy[1];
      if (!allowed.contains('$x,$y')) continue; // respect current filtering rules
      final Point p = board[x][y];
      if (p.type != PieceType.empty) continue;
      // Safety check: do not deliberately feed a capture
      final bool safe = _isGoatPositionSafeOn(board, p, log: false);
      if (!safe) continue;
      return p;
    }
    return null;
  }

  List<Map<String, Point>> _filterAntiOscillation(List<Map<String, Point>> moves) {
    if (lastGoatMoveKey == null || moves.length <= 1) return moves;
    // Reverse of last move becomes from==last.to and to==last.from
    final parts = lastGoatMoveKey!.split('->');
    if (parts.length != 2) return moves;
    final fromStr = parts[0];
    final toStr = parts[1];
    final fromParts = fromStr.split(',');
    final toParts = toStr.split(',');
    if (fromParts.length != 2 || toParts.length != 2) return moves;
    final lastFromX = int.tryParse(fromParts[0]);
    final lastFromY = int.tryParse(fromParts[1]);
    final lastToX = int.tryParse(toParts[0]);
    final lastToY = int.tryParse(toParts[1]);
    if (lastFromX == null || lastFromY == null || lastToX == null || lastToY == null) return moves;
    final filtered = moves.where((m) => !(m['from']!.x == lastToX && m['from']!.y == lastToY && m['to']!.x == lastFromX && m['to']!.y == lastFromY)).toList();
    return filtered.isNotEmpty ? filtered : moves;
  }

  double _clusterBonusConfig(BoardConfig cfg, Point goatPosition) {
    return goatPosition.adjacentPoints.where((adj) => adj.type == PieceType.goat).length.toDouble();
  }

  int _calculateTigerMobilityConfig(BoardConfig cfg) {
    int mobility = 0;
    for (final tiger in cfg.nodes.where((n) => n.type == PieceType.tiger)) {
      mobility += aadu.AaduPuliLogic.getValidMoves(tiger, cfg).length;
    }
    return mobility;
  }

  bool _reducesTigerMobilityConfig(BoardConfig cfg, Point goatPosition) {
    final initial = boardConfig != null ? _calculateTigerMobilityConfig(boardConfig!) : _calculateTigerMobilityConfig(cfg);
    final reduced = _calculateTigerMobilityConfig(cfg);
    return reduced < initial;
  }

  double _calculateBlockScoreConfig(BoardConfig cfg, Point goatPosition) {
    double score = 0.0;
    for (final tiger in cfg.nodes.where((n) => n.type == PieceType.tiger)) {
      for (final goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
        for (final landing in goat.adjacentPoints) {
          if (landing == tiger || landing.type != PieceType.empty) continue;
          final key = '${tiger.id},${goat.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key) && landing.id == goatPosition.id) {
            score += 10.0;
          }
        }
      }
    }
    return score;
  }

  bool _tigerCanCaptureAfterConfig(BoardConfig cfg, Point goatPosition) {
    for (final tiger in cfg.nodes.where((n) => n.type == PieceType.tiger)) {
      for (final landing in goatPosition.adjacentPoints) {
        if (landing == tiger || landing.type != PieceType.empty) continue;
        final key = '${tiger.id},${goatPosition.id},${landing.id}';
        if (aadu.AaduPuliLogic.isJumpTriple(key)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _areAllTigersBlockedOnConfig(BoardConfig cfg) {
    for (final tiger in cfg.nodes.where((n) => n.type == PieceType.tiger)) {
      if (aadu.AaduPuliLogic.getValidMoves(tiger, cfg).isNotEmpty) return false;
    }
    return true;
  }
}