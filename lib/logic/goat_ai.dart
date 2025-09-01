import 'dart:math';
import '../models/piece.dart';
import '../models/board_config.dart';
import '../logic/square_board_logic.dart' as square;
import '../logic/aadu_puli_logic.dart' as aadu;
import '../constants.dart';

class GoatAI {
  static Point placeGoat(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    int placedGoats,
    Difficulty difficulty,
    Set<String> unsafeMoveHistory,
  ) {
    switch (difficulty) {
      case Difficulty.easy:
        return _easyPlacement(board, boardConfig, boardType, placedGoats);
      case Difficulty.medium:
        return _mediumPlacement(board, boardConfig, boardType, placedGoats);
      case Difficulty.hard:
        return _hardPlacement(board, boardConfig, boardType, placedGoats, unsafeMoveHistory);
    }
  }

  static Map<String, Point> moveGoat(
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
  static Point _easyPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    int placedGoats,
  ) {
    List<Point> emptyPoints = _getEmptyPoints(board, boardConfig, boardType);
    if (emptyPoints.isEmpty) {
      throw Exception("No empty points available for goat placement");
    }
    
    // Random placement without considering threats
    return emptyPoints[Random().nextInt(emptyPoints.length)];
  }

  static Map<String, Point> _easyMovement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = _getAllGoatMoves(board, boardConfig, boardType);
    if (allMoves.isEmpty) {
      throw Exception("No valid moves for goats");
    }
    
    // Random legal move without considering tiger threats
    return allMoves[Random().nextInt(allMoves.length)];
  }

  // ===== MEDIUM MODE =====
  static Point _mediumPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    int placedGoats,
  ) {
    List<Point> emptyPoints = _getEmptyPoints(board, boardConfig, boardType);
    if (emptyPoints.isEmpty) {
      throw Exception("No empty points available for goat placement");
    }

    // Priority 1: Block tiger when directly threatened
    Point? threatBlock = _findThreatBlockingPlacement(board, boardConfig, boardType, emptyPoints);
    if (threatBlock != null) {
      return threatBlock;
    }

    // Priority 2: Place near tigers to limit mobility
    Point? nearTigerPlacement = _findNearTigerPlacement(board, boardConfig, boardType, emptyPoints);
    if (nearTigerPlacement != null) {
      return nearTigerPlacement;
    }

    // Fallback: random placement
    return emptyPoints[Random().nextInt(emptyPoints.length)];
  }

  static Map<String, Point> _mediumMovement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = _getAllGoatMoves(board, boardConfig, boardType);
    if (allMoves.isEmpty) {
      throw Exception("No valid moves for goats");
    }

    // Priority 1: Avoid moves that result in immediate capture
    List<Map<String, Point>> safeMoves = _filterSafeMoves(allMoves, board, boardConfig, boardType);
    if (safeMoves.isNotEmpty) {
      // Priority 2: Try to keep goats clustered
      Map<String, Point>? clusteredMove = _findClusteredMove(safeMoves, board, boardConfig, boardType);
      if (clusteredMove != null) {
        return clusteredMove;
      }
      return safeMoves[Random().nextInt(safeMoves.length)];
    }

    // Fallback: random move even if unsafe
    return allMoves[Random().nextInt(allMoves.length)];
  }

  // ===== HARD MODE =====
  static Point _hardPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    int placedGoats,
    Set<String> unsafeMoveHistory,
  ) {
    List<Point> emptyPoints = _getEmptyPoints(board, boardConfig, boardType);
    if (emptyPoints.isEmpty) {
      throw Exception("No empty points available for goat placement");
    }

    // Priority 1: Actively block potential tiger jumps
    Point? jumpBlock = _findJumpBlockingPlacement(board, boardConfig, boardType, emptyPoints, unsafeMoveHistory);
    if (jumpBlock != null) {
      return jumpBlock;
    }

    // Priority 2: Form strategic walls and gradually trap tigers
    Point? strategicPlacement = _findStrategicPlacement(board, boardConfig, boardType, emptyPoints, placedGoats);
    if (strategicPlacement != null) {
      return strategicPlacement;
    }

    // Priority 3: Place on key intersections to restrict tiger freedom
    Point? keyIntersection = _findKeyIntersectionPlacement(board, boardConfig, boardType, emptyPoints);
    if (keyIntersection != null) {
      return keyIntersection;
    }

    // Fallback: safest available position
    return _findSafestPlacement(emptyPoints, board, boardConfig, boardType);
  }

  static Map<String, Point> _hardMovement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = _getAllGoatMoves(board, boardConfig, boardType);
    if (allMoves.isEmpty) {
      throw Exception("No valid moves for goats");
    }

    // Priority 1: Block imminent tiger jumps
    Map<String, Point>? jumpBlock = _findJumpBlockingMove(allMoves, board, boardConfig, boardType);
    if (jumpBlock != null) {
      return jumpBlock;
    }

    // Priority 2: Calculate 2-3 moves ahead using minimax
    Map<String, Point>? minimaxMove = _findMinimaxMove(allMoves, board, boardConfig, boardType);
    if (minimaxMove != null) {
      return minimaxMove;
    }

    // Priority 3: Keep goats on key intersections
    Map<String, Point>? keyMove = _findKeyIntersectionMove(allMoves, board, boardConfig, boardType);
    if (keyMove != null) {
      return keyMove;
    }

    // Fallback: best heuristic move
    return _findBestHeuristicMove(allMoves, board, boardConfig, boardType);
  }

  // ===== HELPER METHODS =====
  static List<Point> _getEmptyPoints(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
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
    return emptyPoints;
  }

  static List<Map<String, Point>> _getAllGoatMoves(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = [];
    if (boardType == BoardType.square) {
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
    } else if (boardConfig != null) {
      for (var goat in boardConfig!.nodes.where((n) => n.type == PieceType.goat)) {
        var valids = aadu.AaduPuliLogic.getValidMoves(goat, boardConfig!);
        for (var to in valids) {
          if (to.type == PieceType.empty) {
            allMoves.add({'from': goat, 'to': to});
          }
        }
      }
    }
    return allMoves;
  }

  // Medium mode helpers
  static Point? _findThreatBlockingPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    // Find positions that block immediate tiger captures
    for (Point point in emptyPoints) {
      if (_blocksImmediateThreat(point, board, boardConfig, boardType)) {
        return point;
      }
    }
    return null;
  }

  static Point? _findNearTigerPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    // Find positions adjacent to tigers to limit their mobility
    for (Point point in emptyPoints) {
      if (_isAdjacentToTiger(point, board, boardConfig, boardType)) {
        return point;
      }
    }
    return null;
  }

  static List<Map<String, Point>> _filterSafeMoves(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    return moves.where((move) {
      return !_resultsInImmediateCapture(move, board, boardConfig, boardType);
    }).toList();
  }

  static Map<String, Point>? _findClusteredMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    Map<String, Point>? bestMove;
    int maxAdjacentGoats = -1;

    for (Map<String, Point> move in moves) {
      int adjacentGoats = _countAdjacentGoats(move['to']!, board, boardConfig, boardType);
      if (adjacentGoats > maxAdjacentGoats) {
        maxAdjacentGoats = adjacentGoats;
        bestMove = move;
      }
    }

    return bestMove;
  }

  // Hard mode helpers
  static Point? _findJumpBlockingPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
    Set<String> unsafeMoveHistory,
  ) {
    // Find positions that block potential tiger jump landings
    for (Point point in emptyPoints) {
      if (_blocksTigerJump(point, board, boardConfig, boardType) && 
          !unsafeMoveHistory.contains('${point.x},${point.y}')) {
        return point;
      }
    }
    return null;
  }

  static Point? _findStrategicPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
    int placedGoats,
  ) {
    // Form strategic walls and gradually trap tigers
    for (Point point in emptyPoints) {
      if (_formsStrategicWall(point, board, boardConfig, boardType, placedGoats)) {
        return point;
      }
    }
    return null;
  }

  static Point? _findKeyIntersectionPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    // Place on key intersections to restrict tiger freedom
    for (Point point in emptyPoints) {
      if (_isKeyIntersection(point, board, boardConfig, boardType)) {
        return point;
      }
    }
    return null;
  }

  static Point _findSafestPlacement(
    List<Point> emptyPoints,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    Point safest = emptyPoints.first;
    double lowestRisk = double.infinity;

    for (Point point in emptyPoints) {
      double risk = _calculateRisk(point, board, boardConfig, boardType);
      if (risk < lowestRisk) {
        lowestRisk = risk;
        safest = point;
      }
    }

    return safest;
  }

  static Map<String, Point>? _findJumpBlockingMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    // Find moves that block imminent tiger jumps
    for (Map<String, Point> move in moves) {
      if (_blocksTigerJumpMove(move, board, boardConfig, boardType)) {
        return move;
      }
    }
    return null;
  }

  static Map<String, Point>? _findMinimaxMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    // Calculate 2-3 moves ahead using minimax algorithm
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

  static Map<String, Point>? _findKeyIntersectionMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    // Keep goats on key intersections
    for (Map<String, Point> move in moves) {
      if (_isKeyIntersection(move['to']!, board, boardConfig, boardType)) {
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
  static bool _blocksImmediateThreat(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Implementation depends on board type
    if (boardType == BoardType.square) {
      // Check if placing a goat here blocks an immediate tiger capture
      return _blocksSquareThreat(point, board);
    } else {
      return _blocksAaduPuliThreat(point, boardConfig!);
    }
  }

  static bool _isAdjacentToTiger(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    if (boardType == BoardType.square) {
      return point.adjacentPoints.any((adj) => adj.type == PieceType.tiger);
    } else {
      return point.adjacentPoints.any((adj) => adj.type == PieceType.tiger);
    }
  }

  static bool _resultsInImmediateCapture(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Check if this move results in the goat being captured immediately
    if (boardType == BoardType.square) {
      return _resultsInSquareCapture(move, board);
    } else {
      return _resultsInAaduPuliCapture(move, boardConfig!);
    }
  }

  static int _countAdjacentGoats(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    return point.adjacentPoints.where((adj) => adj.type == PieceType.goat).length;
  }

  static bool _blocksTigerJump(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Check if this position blocks a potential tiger jump
    if (boardType == BoardType.square) {
      return _blocksSquareJump(point, board);
    } else {
      return _blocksAaduPuliJump(point, boardConfig!);
    }
  }

  static bool _formsStrategicWall(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType, int placedGoats) {
    // Check if this placement forms a strategic wall
    if (boardType == BoardType.square) {
      return _formsSquareWall(point, board, placedGoats);
    } else {
      return _formsAaduPuliWall(point, boardConfig!);
    }
  }

  static bool _isKeyIntersection(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Check if this is a key intersection that restricts tiger freedom
    if (boardType == BoardType.square) {
      return _isSquareKeyIntersection(point, board);
    } else {
      return _isAaduPuliKeyIntersection(point, boardConfig!);
    }
  }

  static double _calculateRisk(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Calculate the risk of placing a goat at this position
    if (boardType == BoardType.square) {
      return _calculateSquareRisk(point, board);
    } else {
      return _calculateAaduPuliRisk(point, boardConfig!);
    }
  }

  static bool _blocksTigerJumpMove(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Check if this move blocks a tiger jump
    if (boardType == BoardType.square) {
      return _blocksSquareJumpMove(move, board);
    } else {
      return _blocksAaduPuliJumpMove(move, boardConfig!);
    }
  }

  static double _evaluateMoveMinimax(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType, int depth, bool maximizing) {
    // Implement minimax evaluation for the move
    if (boardType == BoardType.square) {
      return _evaluateSquareMinimax(move, board, depth, maximizing);
    } else {
      return _evaluateAaduPuliMinimax(move, boardConfig!, depth, maximizing);
    }
  }

  static double _evaluateMoveHeuristic(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    // Implement heuristic evaluation for the move
    if (boardType == BoardType.square) {
      return _evaluateSquareHeuristic(move, board);
    } else {
      return _evaluateAaduPuliHeuristic(move, boardConfig!);
    }
  }

  // ===== BOARD-SPECIFIC IMPLEMENTATIONS =====
  // Square board implementations
  static bool _blocksSquareThreat(Point point, List<List<Point>> board) {
    // Check if placing a goat here blocks an immediate tiger capture
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, board);
      for (var move in tigerMoves) {
        if ((move.x - tiger.x).abs() == 2 || (move.y - tiger.y).abs() == 2) {
          int midX = (tiger.x + move.x) ~/ 2;
          int midY = (tiger.y + move.y) ~/ 2;
          if (midX == point.x && midY == point.y) {
            return true; // This position blocks a potential capture
          }
        }
      }
    }
    return false;
  }

  static bool _resultsInSquareCapture(Map<String, Point> move, List<List<Point>> board) {
    // Check if this move results in the goat being captured immediately
    Point to = move['to']!;
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      if (tiger.adjacentPoints.contains(to)) {
        // Check if there's an empty landing spot for the tiger to jump
        for (var landing in to.adjacentPoints) {
          if (landing.type == PieceType.empty && landing != tiger) {
            return true; // Goat can be captured
          }
        }
      }
    }
    return false;
  }

  static bool _blocksSquareJump(Point point, List<List<Point>> board) {
    // Check if this position blocks a potential tiger jump landing
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      for (var adj in tiger.adjacentPoints) {
        if (adj.type == PieceType.goat) {
          int dx = adj.x - tiger.x;
          int dy = adj.y - tiger.y;
          int landingX = adj.x + dx;
          int landingY = adj.y + dy;
          if (landingX >= 0 && landingX < board.length && 
              landingY >= 0 && landingY < board[0].length &&
              landingX == point.x && landingY == point.y) {
            return true; // This position blocks a jump landing
          }
        }
      }
    }
    return false;
  }

  static bool _formsSquareWall(Point point, List<List<Point>> board, int placedGoats) {
    // Check if this placement forms a strategic wall
    // Early game: prefer edges
    if (placedGoats < 12) {
      return point.x == 0 || point.x == board.length - 1 || 
             point.y == 0 || point.y == board[0].length - 1;
    }
    // Late game: prefer positions that connect existing goats
    return point.adjacentPoints.where((adj) => adj.type == PieceType.goat).length >= 2;
  }

  static bool _isSquareKeyIntersection(Point point, List<List<Point>> board) {
    // Check if this is a key intersection that restricts tiger freedom
    // Positions that control multiple paths or are central
    int adjacentEmpty = point.adjacentPoints.where((adj) => adj.type == PieceType.empty).length;
    return adjacentEmpty <= 2; // Few empty adjacent spots = key intersection
  }

  static double _calculateSquareRisk(Point point, List<List<Point>> board) {
    // Calculate the risk of placing a goat at this position
    double risk = 0.0;
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      double distance = ((point.x - tiger.x) * (point.x - tiger.x) + 
                        (point.y - tiger.y) * (point.y - tiger.y)).toDouble();
      risk += 1.0 / (distance + 1.0); // Closer tigers = higher risk
    }
    return risk;
  }

  static bool _blocksSquareJumpMove(Map<String, Point> move, List<List<Point>> board) {
    // Check if this move blocks a tiger jump
    Point to = move['to']!;
    return _blocksSquareJump(to, board);
  }

  static double _evaluateSquareMinimax(Map<String, Point> move, List<List<Point>> board, int depth, bool maximizing) {
    // Simple minimax evaluation for square board
    // This is a simplified version - in practice, you'd want a more sophisticated evaluation
    Point to = move['to']!;
    double score = 0.0;
    
    // Bonus for blocking tigers
    if (_blocksSquareJump(to, board)) {
      score += 100.0;
    }
    
    // Bonus for clustering
    score += _countAdjacentGoats(to, board, null, BoardType.square) * 10.0;
    
    // Penalty for being near tigers
    for (var tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      double distance = ((to.x - tiger.x) * (to.x - tiger.x) + 
                        (to.y - tiger.y) * (to.y - tiger.y)).toDouble();
      score -= 50.0 / (distance + 1.0);
    }
    
    return maximizing ? score : -score;
  }

  static double _evaluateSquareHeuristic(Map<String, Point> move, List<List<Point>> board) {
    // Heuristic evaluation for square board
    Point to = move['to']!;
    double score = 0.0;
    
    // Blocking bonus
    if (_blocksSquareJump(to, board)) {
      score += 200.0;
    }
    
    // Clustering bonus
    score += _countAdjacentGoats(to, board, null, BoardType.square) * 50.0;
    
    // Edge bonus (early game)
    if (to.x == 0 || to.x == board.length - 1 || to.y == 0 || to.y == board[0].length - 1) {
      score += 30.0;
    }
    
    // Risk penalty
    score -= _calculateSquareRisk(to, board) * 100.0;
    
    return score;
  }

  // Aadu Puli board implementations
  static bool _blocksAaduPuliThreat(Point point, BoardConfig boardConfig) {
    // Check if placing a goat here blocks an immediate tiger capture
    for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
      for (var landing in point.adjacentPoints) {
        if (landing == tiger || landing.type != PieceType.empty) continue;
        String key = '${tiger.id},${point.id},${landing.id}';
        if (aadu.AaduPuliLogic.isJumpTriple(key)) {
          return true; // This position blocks a potential capture
        }
      }
    }
    return false;
  }

  static bool _resultsInAaduPuliCapture(Map<String, Point> move, BoardConfig boardConfig) {
    // Check if this move results in the goat being captured immediately
    Point to = move['to']!;
    for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
      if (tiger.adjacentPoints.contains(to)) {
        for (var landing in to.adjacentPoints) {
          if (landing.type == PieceType.empty && landing != tiger) {
            String key = '${tiger.id},${to.id},${landing.id}';
            if (aadu.AaduPuliLogic.isJumpTriple(key)) {
              return true; // Goat can be captured
            }
          }
        }
      }
    }
    return false;
  }

  static bool _blocksAaduPuliJump(Point point, BoardConfig boardConfig) {
    // Check if this position blocks a potential tiger jump landing
    for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
      for (var goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
        for (var landing in goat.adjacentPoints) {
          if (landing == tiger || landing.type != PieceType.empty) continue;
          String key = '${tiger.id},${goat.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key) && landing.id == point.id) {
            return true; // This position blocks a jump landing
          }
        }
      }
    }
    return false;
  }

  static bool _formsAaduPuliWall(Point point, BoardConfig boardConfig) {
    // Check if this placement forms a strategic wall
    return point.adjacentPoints.where((adj) => adj.type == PieceType.goat).length >= 2;
  }

  static bool _isAaduPuliKeyIntersection(Point point, BoardConfig boardConfig) {
    // Check if this is a key intersection that restricts tiger freedom
    int adjacentEmpty = point.adjacentPoints.where((adj) => adj.type == PieceType.empty).length;
    return adjacentEmpty <= 2; // Few empty adjacent spots = key intersection
  }

  static double _calculateAaduPuliRisk(Point point, BoardConfig boardConfig) {
    // Calculate the risk of placing a goat at this position
    double risk = 0.0;
    for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
      if (tiger.adjacentPoints.contains(point)) {
        risk += 100.0; // High risk if adjacent to tiger
      }
    }
    return risk;
  }

  static bool _blocksAaduPuliJumpMove(Map<String, Point> move, BoardConfig boardConfig) {
    // Check if this move blocks a tiger jump
    Point to = move['to']!;
    return _blocksAaduPuliJump(to, boardConfig);
  }

  static double _evaluateAaduPuliMinimax(Map<String, Point> move, BoardConfig boardConfig, int depth, bool maximizing) {
    // Simple minimax evaluation for Aadu Puli board
    Point to = move['to']!;
    double score = 0.0;
    
    // Bonus for blocking tigers
    if (_blocksAaduPuliJump(to, boardConfig)) {
      score += 100.0;
    }
    
    // Bonus for clustering
    score += _countAdjacentGoats(to, null, boardConfig, BoardType.aaduPuli) * 10.0;
    
    // Penalty for being near tigers
    for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
      if (tiger.adjacentPoints.contains(to)) {
        score -= 50.0;
      }
    }
    
    return maximizing ? score : -score;
  }

  static double _evaluateAaduPuliHeuristic(Map<String, Point> move, BoardConfig boardConfig) {
    // Heuristic evaluation for Aadu Puli board
    Point to = move['to']!;
    double score = 0.0;
    
    // Blocking bonus
    if (_blocksAaduPuliJump(to, boardConfig)) {
      score += 200.0;
    }
    
    // Clustering bonus
    score += _countAdjacentGoats(to, null, boardConfig, BoardType.aaduPuli) * 50.0;
    
    // Risk penalty
    score -= _calculateAaduPuliRisk(to, boardConfig);
    
    return score;
  }
}