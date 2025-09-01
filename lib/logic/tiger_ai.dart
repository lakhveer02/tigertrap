import 'dart:math';
import '../models/piece.dart';
import '../models/board_config.dart';
import '../logic/square_board_logic.dart' as square;
import '../logic/aadu_puli_logic.dart' as aadu;
import '../constants.dart';

class TigerAI {
  static Map<String, Point> moveTiger(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    Difficulty difficulty,
  ) {
    switch (difficulty) {
      case Difficulty.easy:
        return _easyMovement(board, boardConfig, boardType);
      case Difficulty.medium:
        return _mediumMovement(board, boardConfig, boardType);
      case Difficulty.hard:
        return _hardMovement(board, boardConfig, boardType);
    }
  }

  // ===== EASY MODE =====
  static Map<String, Point> _easyMovement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = _getAllTigerMoves(board, boardConfig, boardType);
    if (allMoves.isEmpty) {
      throw Exception("No valid moves for tigers");
    }

    // Priority 1: Random capture if available
    List<Map<String, Point>> captureMoves = _getCaptureMoves(allMoves, board, boardConfig, boardType);
    if (captureMoves.isNotEmpty) {
      return captureMoves[Random().nextInt(captureMoves.length)];
    }

    // Priority 2: Random legal move
    return allMoves[Random().nextInt(allMoves.length)];
  }

  // ===== MEDIUM MODE =====
  static Map<String, Point> _mediumMovement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = _getAllTigerMoves(board, boardConfig, boardType);
    if (allMoves.isEmpty) {
      throw Exception("No valid moves for tigers");
    }

    // Priority 1: Always take capture if possible
    List<Map<String, Point>> captureMoves = _getCaptureMoves(allMoves, board, boardConfig, boardType);
    if (captureMoves.isNotEmpty) {
      return captureMoves[Random().nextInt(captureMoves.length)];
    }

    // Priority 2: Move closer to goats to increase pressure
    List<Map<String, Point>> threateningMoves = _getThreateningMoves(allMoves, board, boardConfig, boardType);
    if (threateningMoves.isNotEmpty) {
      return threateningMoves[Random().nextInt(threateningMoves.length)];
    }

    // Priority 3: Avoid getting stuck near corners
    List<Map<String, Point>> safeMoves = _getSafeMoves(allMoves, board, boardConfig, boardType);
    if (safeMoves.isNotEmpty) {
      return safeMoves[Random().nextInt(safeMoves.length)];
    }

    // Fallback: random move
    return allMoves[Random().nextInt(allMoves.length)];
  }

  // ===== HARD MODE =====
  static Map<String, Point> _hardMovement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = _getAllTigerMoves(board, boardConfig, boardType);
    if (allMoves.isEmpty) {
      throw Exception("No valid moves for tigers");
    }

    // Priority 1: Always take the best capture (evaluates which move keeps mobility high)
    List<Map<String, Point>> captureMoves = _getCaptureMoves(allMoves, board, boardConfig, boardType);
    if (captureMoves.isNotEmpty) {
      return _findBestCapture(captureMoves, board, boardConfig, boardType);
    }

    // Priority 2: Predict goat blocking 2-3 moves ahead (minimax/heuristics)
    Map<String, Point>? minimaxMove = _findMinimaxMove(allMoves, board, boardConfig, boardType);
    if (minimaxMove != null) {
      return minimaxMove;
    }

    // Priority 3: Move to the center when possible to maximize options
    Map<String, Point>? centerMove = _findCenterMove(allMoves, board, boardConfig, boardType);
    if (centerMove != null) {
      return centerMove;
    }

    // Fallback: best heuristic move
    return _findBestHeuristicMove(allMoves, board, boardConfig, boardType);
  }

  // ===== HELPER METHODS =====
  static List<Map<String, Point>> _getAllTigerMoves(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = [];
    if (boardType == BoardType.square) {
      for (var row in board) {
        for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
          var validMoves = square.SquareBoardLogic.getValidMoves(tiger, board);
          for (var to in validMoves) {
            allMoves.add({'from': tiger, 'to': to});
          }
        }
      }
    } else if (boardConfig != null) {
      for (var tiger in boardConfig!.nodes.where((n) => n.type == PieceType.tiger)) {
        var valids = aadu.AaduPuliLogic.getValidMoves(tiger, boardConfig!);
        for (var to in valids) {
          allMoves.add({'from': tiger, 'to': to});
        }
      }
    }
    return allMoves;
  }

  static List<Map<String, Point>> _getCaptureMoves(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    return moves.where((move) {
      return _isCaptureMove(move, board, boardConfig, boardType);
    }).toList();
  }

  static List<Map<String, Point>> _getThreateningMoves(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    return moves.where((move) {
      return _isThreateningMove(move, board, boardConfig, boardType);
    }).toList();
  }

  static List<Map<String, Point>> _getSafeMoves(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    return moves.where((move) {
      return _isSafeMove(move, board, boardConfig, boardType);
    }).toList();
  }

  static Map<String, Point> _findBestCapture(
    List<Map<String, Point>> captureMoves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    Map<String, Point> bestCapture = captureMoves.first;
    double bestScore = double.negativeInfinity;

    for (Map<String, Point> move in captureMoves) {
      double score = _evaluateCaptureMove(move, board, boardConfig, boardType);
      if (score > bestScore) {
        bestScore = score;
        bestCapture = move;
      }
    }

    return bestCapture;
  }

  static Map<String, Point>? _findMinimaxMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    Map<String, Point>? bestMove;
    double bestScore = double.negativeInfinity;

    for (Map<String, Point> move in moves) {
      double score = _evaluateMoveMinimax(move, board, boardConfig, boardType, 2, true);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  static Map<String, Point>? _findCenterMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    // Find moves that move tigers toward the center
    for (Map<String, Point> move in moves) {
      if (_movesTowardCenter(move, board, boardConfig, boardType)) {
        return move;
      }
    }
    return null;
  }

  static Map<String, Point> _findBestHeuristicMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    Map<String, Point> bestMove = moves.first;
    double bestScore = double.negativeInfinity;

    for (Map<String, Point> move in moves) {
      double score = _evaluateMoveHeuristic(move, board, boardConfig, boardType);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  // ===== EVALUATION METHODS =====
  static bool _isCaptureMove(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    if (boardType == BoardType.square) {
      return _isSquareCaptureMove(move, board);
    } else {
      return _isAaduPuliCaptureMove(move, boardConfig!);
    }
  }

  static bool _isThreateningMove(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    if (boardType == BoardType.square) {
      return _isSquareThreateningMove(move, board);
    } else {
      return _isAaduPuliThreateningMove(move, boardConfig!);
    }
  }

  static bool _isSafeMove(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    if (boardType == BoardType.square) {
      return _isSquareSafeMove(move, board);
    } else {
      return _isAaduPuliSafeMove(move, boardConfig!);
    }
  }

  static double _evaluateCaptureMove(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    if (boardType == BoardType.square) {
      return _evaluateSquareCaptureMove(move, board);
    } else {
      return _evaluateAaduPuliCaptureMove(move, boardConfig!);
    }
  }

  static double _evaluateMoveMinimax(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    int depth,
    bool maximizing,
  ) {
    if (boardType == BoardType.square) {
      return _evaluateSquareMinimax(move, board, depth, maximizing);
    } else {
      return _evaluateAaduPuliMinimax(move, boardConfig!, depth, maximizing);
    }
  }

  static bool _movesTowardCenter(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    if (boardType == BoardType.square) {
      return _movesTowardSquareCenter(move, board);
    } else {
      return _movesTowardAaduPuliCenter(move, boardConfig!);
    }
  }

  static double _evaluateMoveHeuristic(
    Map<String, Point> move,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    if (boardType == BoardType.square) {
      return _evaluateSquareHeuristic(move, board);
    } else {
      return _evaluateAaduPuliHeuristic(move, boardConfig!);
    }
  }

  // ===== BOARD-SPECIFIC IMPLEMENTATIONS =====
  // Square board implementations
  static bool _isSquareCaptureMove(Map<String, Point> move, List<List<Point>> board) {
    Point from = move['from']!;
    Point to = move['to']!;
    return (to.x - from.x).abs() == 2 || (to.y - from.y).abs() == 2;
  }

  static bool _isSquareThreateningMove(Map<String, Point> move, List<List<Point>> board) {
    Point to = move['to']!;
    // Check if this move puts the tiger adjacent to goats
    return to.adjacentPoints.any((adj) => adj.type == PieceType.goat);
  }

  static bool _isSquareSafeMove(Map<String, Point> move, List<List<Point>> board) {
    Point to = move['to']!;
    // Avoid corners and edges where tigers can get trapped
    int maxX = board.length - 1;
    int maxY = board[0].length - 1;
    
    // Corners are dangerous
    if ((to.x == 0 && to.y == 0) || (to.x == 0 && to.y == maxY) ||
        (to.x == maxX && to.y == 0) || (to.x == maxX && to.y == maxY)) {
      return false;
    }
    
    // Edges can be dangerous if too many adjacent positions are occupied
    if (to.x == 0 || to.x == maxX || to.y == 0 || to.y == maxY) {
      int occupiedAdjacent = to.adjacentPoints.where((adj) => adj.type != PieceType.empty).length;
      return occupiedAdjacent < 3; // Safe if less than 3 adjacent positions are occupied
    }
    
    return true;
  }

  static double _evaluateSquareCaptureMove(Map<String, Point> move, List<List<Point>> board) {
    Point to = move['to']!;
    double score = 100.0; // Base capture score
    
    // Bonus for maintaining mobility after capture
    int mobilityAfterCapture = _calculateTigerMobilityAfterMove(move, board);
    score += mobilityAfterCapture * 10.0;
    
    // Bonus for capturing goats that are part of a cluster
    int adjacentGoats = to.adjacentPoints.where((adj) => adj.type == PieceType.goat).length;
    score += adjacentGoats * 5.0;
    
    // Bonus for capturing goats near edges (harder to replace)
    if (_isNearEdge(to, board)) {
      score += 20.0;
    }
    
    return score;
  }

  static double _evaluateSquareMinimax(Map<String, Point> move, List<List<Point>> board, int depth, bool maximizing) {
    Point to = move['to']!;
    double score = 0.0;
    
    // Mobility bonus
    score += _calculateTigerMobilityAfterMove(move, board) * 20.0;
    
    // Threat bonus
    if (_isSquareThreateningMove(move, board)) {
      score += 50.0;
    }
    
    // Safety bonus
    if (_isSquareSafeMove(move, board)) {
      score += 30.0;
    }
    
    // Center bonus
    if (_movesTowardSquareCenter(move, board)) {
      score += 25.0;
    }
    
    // Capture bonus
    if (_isSquareCaptureMove(move, board)) {
      score += 100.0;
    }
    
    return maximizing ? score : -score;
  }

  static bool _movesTowardSquareCenter(Map<String, Point> move, List<List<Point>> board) {
    Point from = move['from']!;
    Point to = move['to']!;
    
    int centerX = board.length ~/ 2;
    int centerY = board[0].length ~/ 2;
    
    double fromDistance = ((from.x - centerX) * (from.x - centerX) + 
                          (from.y - centerY) * (from.y - centerY)).toDouble();
    double toDistance = ((to.x - centerX) * (to.x - centerX) + 
                        (to.y - centerY) * (to.y - centerY)).toDouble();
    
    return toDistance < fromDistance;
  }

  static double _evaluateSquareHeuristic(Map<String, Point> move, List<List<Point>> board) {
    Point to = move['to']!;
    double score = 0.0;
    
    // Capture bonus
    if (_isSquareCaptureMove(move, board)) {
      score += 200.0;
    }
    
    // Mobility bonus
    score += _calculateTigerMobilityAfterMove(move, board) * 30.0;
    
    // Threat bonus
    if (_isSquareThreateningMove(move, board)) {
      score += 80.0;
    }
    
    // Safety bonus
    if (_isSquareSafeMove(move, board)) {
      score += 50.0;
    }
    
    // Center bonus
    if (_movesTowardSquareCenter(move, board)) {
      score += 40.0;
    }
    
    // Penalty for moving away from goats
    score -= _calculateDistanceFromGoats(to, board) * 5.0;
    
    return score;
  }

  // Aadu Puli board implementations
  static bool _isAaduPuliCaptureMove(Map<String, Point> move, BoardConfig boardConfig) {
    Point from = move['from']!;
    Point to = move['to']!;
    
    // Check if this is a jump move (capture)
    for (var goat in from.adjacentPoints.where((p) => p.type == PieceType.goat)) {
      for (var landing in goat.adjacentPoints) {
        if (landing == from || landing.type != PieceType.empty) continue;
        String key = '${from.id},${goat.id},${landing.id}';
        if (aadu.AaduPuliLogic.isJumpTriple(key) && landing.id == to.id) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isAaduPuliThreateningMove(Map<String, Point> move, BoardConfig boardConfig) {
    Point to = move['to']!;
    // Check if this move puts the tiger adjacent to goats
    return to.adjacentPoints.any((adj) => adj.type == PieceType.goat);
  }

  static bool _isAaduPuliSafeMove(Map<String, Point> move, BoardConfig boardConfig) {
    Point to = move['to']!;
    // Check if this position has good mobility and isn't easily trapped
    int emptyAdjacent = to.adjacentPoints.where((adj) => adj.type == PieceType.empty).length;
    return emptyAdjacent >= 2; // Safe if at least 2 adjacent positions are empty
  }

  static double _evaluateAaduPuliCaptureMove(Map<String, Point> move, BoardConfig boardConfig) {
    Point to = move['to']!;
    double score = 100.0; // Base capture score
    
    // Bonus for maintaining mobility after capture
    int mobilityAfterCapture = _calculateTigerMobilityAfterMoveConfig(move, boardConfig);
    score += mobilityAfterCapture * 10.0;
    
    // Bonus for capturing goats that are part of a cluster
    int adjacentGoats = to.adjacentPoints.where((adj) => adj.type == PieceType.goat).length;
    score += adjacentGoats * 5.0;
    
    return score;
  }

  static double _evaluateAaduPuliMinimax(Map<String, Point> move, BoardConfig boardConfig, int depth, bool maximizing) {
    Point to = move['to']!;
    double score = 0.0;
    
    // Mobility bonus
    score += _calculateTigerMobilityAfterMoveConfig(move, boardConfig) * 20.0;
    
    // Threat bonus
    if (_isAaduPuliThreateningMove(move, boardConfig)) {
      score += 50.0;
    }
    
    // Safety bonus
    if (_isAaduPuliSafeMove(move, boardConfig)) {
      score += 30.0;
    }
    
    // Center bonus
    if (_movesTowardAaduPuliCenter(move, boardConfig)) {
      score += 25.0;
    }
    
    // Capture bonus
    if (_isAaduPuliCaptureMove(move, boardConfig)) {
      score += 100.0;
    }
    
    return maximizing ? score : -score;
  }

  static bool _movesTowardAaduPuliCenter(Map<String, Point> move, BoardConfig boardConfig) {
    Point to = move['to']!;
    // For Aadu Puli, consider positions with more connections as "center"
    int connections = to.adjacentPoints.length;
    return connections >= 4; // Positions with 4+ connections are considered central
  }

  static double _evaluateAaduPuliHeuristic(Map<String, Point> move, BoardConfig boardConfig) {
    Point to = move['to']!;
    double score = 0.0;
    
    // Capture bonus
    if (_isAaduPuliCaptureMove(move, boardConfig)) {
      score += 200.0;
    }
    
    // Mobility bonus
    score += _calculateTigerMobilityAfterMoveConfig(move, boardConfig) * 30.0;
    
    // Threat bonus
    if (_isAaduPuliThreateningMove(move, boardConfig)) {
      score += 80.0;
    }
    
    // Safety bonus
    if (_isAaduPuliSafeMove(move, boardConfig)) {
      score += 50.0;
    }
    
    // Center bonus
    if (_movesTowardAaduPuliCenter(move, boardConfig)) {
      score += 40.0;
    }
    
    // Penalty for moving away from goats
    score -= _calculateDistanceFromGoatsConfig(to, boardConfig) * 5.0;
    
    return score;
  }

  // ===== UTILITY METHODS =====
  static int _calculateTigerMobilityAfterMove(Map<String, Point> move, List<List<Point>> board) {
    // Simulate the move and calculate tiger mobility
    var boardClone = _cloneSquareBoard(board);
    Point from = boardClone[move['from']!.x][move['from']!.y];
    Point to = boardClone[move['to']!.x][move['to']!.y];
    
    to.type = from.type;
    from.type = PieceType.empty;
    
    int mobility = 0;
    for (var row in boardClone) {
      for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
        mobility += square.SquareBoardLogic.getValidMoves(tiger, boardClone).length;
      }
    }
    return mobility;
  }

  static int _calculateTigerMobilityAfterMoveConfig(Map<String, Point> move, BoardConfig boardConfig) {
    // Simulate the move and calculate tiger mobility
    var configClone = _cloneAaduPuliConfig(boardConfig);
    Point from = configClone.nodes.firstWhere((n) => n.id == move['from']!.id);
    Point to = configClone.nodes.firstWhere((n) => n.id == move['to']!.id);
    
    to.type = from.type;
    from.type = PieceType.empty;
    
    int mobility = 0;
    for (var tiger in configClone.nodes.where((n) => n.type == PieceType.tiger)) {
      mobility += aadu.AaduPuliLogic.getValidMoves(tiger, configClone).length;
    }
    return mobility;
  }

  static bool _isNearEdge(Point point, List<List<Point>> board) {
    int maxX = board.length - 1;
    int maxY = board[0].length - 1;
    return point.x == 0 || point.x == maxX || point.y == 0 || point.y == maxY;
  }

  static double _calculateDistanceFromGoats(Point point, List<List<Point>> board) {
    double totalDistance = 0.0;
    int goatCount = 0;
    
    for (var row in board) {
      for (var p in row) {
        if (p.type == PieceType.goat) {
          double distance = ((point.x - p.x) * (point.x - p.x) + 
                           (point.y - p.y) * (point.y - p.y)).toDouble();
          totalDistance += distance;
          goatCount++;
        }
      }
    }
    
    return goatCount > 0 ? totalDistance / goatCount : 0.0;
  }

  static double _calculateDistanceFromGoatsConfig(Point point, BoardConfig boardConfig) {
    double totalDistance = 0.0;
    int goatCount = 0;
    
    for (var p in boardConfig.nodes) {
      if (p.type == PieceType.goat) {
        double distance = ((point.x - p.x) * (point.x - p.x) + 
                         (point.y - p.y) * (point.y - p.y)).toDouble();
        totalDistance += distance;
        goatCount++;
      }
    }
    
    return goatCount > 0 ? totalDistance / goatCount : 0.0;
  }

  static List<List<Point>> _cloneSquareBoard(List<List<Point>> original) {
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
        p.adjacentPoints = orig.adjacentPoints.map((adj) => points[adj.x][adj.y]).toList();
      }
    }
    return points;
  }

  static BoardConfig _cloneAaduPuliConfig(BoardConfig original) {
    final nodes = original.nodes.map((p) => Point(
      x: p.x,
      y: p.y,
      type: p.type,
      id: p.id,
      position: p.position,
      adjacentPoints: [],
    )).toList();
    
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].adjacentPoints = original.nodes[i].adjacentPoints.map((adj) {
        final idx = original.nodes.indexOf(adj);
        return nodes[idx];
      }).toList();
    }
    
    return BoardConfig(nodes: nodes, connections: original.connections);
  }
}