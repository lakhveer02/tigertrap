import 'dart:math';
import 'dart:developer' as developer;
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
    developer.log('GoatAI.placeGoat called with difficulty: $difficulty, placedGoats: $placedGoats');
    
    try {
      // Validate inputs
      if (board.isEmpty) {
        throw Exception("Board is empty");
      }
      
      if (boardType == BoardType.square && boardConfig != null) {
        developer.log('Warning: Square board type but boardConfig provided');
      }
      
      if (boardType == BoardType.aaduPuli && boardConfig == null) {
        throw Exception("Aadu Puli board type requires boardConfig");
      }
      
      switch (difficulty) {
        case Difficulty.easy:
          return _easyPlacement(board, boardConfig, boardType, placedGoats);
        case Difficulty.medium:
          return _mediumPlacement(board, boardConfig, boardType, placedGoats);
        case Difficulty.hard:
          return _hardPlacement(board, boardConfig, boardType, placedGoats, unsafeMoveHistory);
      }
    } catch (e) {
      developer.log('GoatAI.placeGoat error: $e');
      // Fallback to simple random placement
      List<Point> emptyPoints = _getEmptyPoints(board, boardConfig, boardType);
      if (emptyPoints.isEmpty) {
        throw Exception("No empty points available for goat placement");
      }
      return emptyPoints[Random().nextInt(emptyPoints.length)];
    }
  }

  static Map<String, Point> moveGoat(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    Difficulty difficulty,
  ) {
    developer.log('GoatAI.moveGoat called with difficulty: $difficulty');
    
    try {
      // Validate inputs
      if (board.isEmpty) {
        throw Exception("Board is empty");
      }
      
      switch (difficulty) {
        case Difficulty.easy:
          return _easyMovement(board, boardConfig, boardType);
        case Difficulty.medium:
          return _mediumMovement(board, boardConfig, boardType);
        case Difficulty.hard:
          return _hardMovement(board, boardConfig, boardType);
      }
    } catch (e) {
      developer.log('GoatAI.moveGoat error: $e');
      // Fallback to simple random movement
      List<Map<String, Point>> allMoves = _getAllGoatMoves(board, boardConfig, boardType);
      if (allMoves.isEmpty) {
        throw Exception("No valid moves for goats");
      }
      return allMoves[Random().nextInt(allMoves.length)];
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
    
    developer.log('Easy mode: ${emptyPoints.length} empty points available');
    
    // Simple random placement with slight preference for edges
    List<Point> preferredPoints = [];
    List<Point> otherPoints = [];
    
    for (Point point in emptyPoints) {
      if (_isEdgePosition(point, board, boardConfig, boardType)) {
        preferredPoints.add(point);
      } else {
        otherPoints.add(point);
      }
    }
    
    developer.log('Easy mode: ${preferredPoints.length} preferred points, ${otherPoints.length} other points');
    
    // 70% chance to pick from preferred (edge) positions
    if (preferredPoints.isNotEmpty && Random().nextDouble() < 0.7) {
      Point selected = preferredPoints[Random().nextInt(preferredPoints.length)];
      developer.log('Easy mode: selected preferred point at ${selected.x}, ${selected.y}');
      return selected;
    } else {
      Point selected = emptyPoints[Random().nextInt(emptyPoints.length)];
      developer.log('Easy mode: selected random point at ${selected.x}, ${selected.y}');
      return selected;
    }
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
    
    // Filter out moves that result in immediate capture
    List<Map<String, Point>> safeMoves = [];
    for (Map<String, Point> move in allMoves) {
      if (!_resultsInImmediateCapture(move, board, boardConfig, boardType)) {
        safeMoves.add(move);
      }
    }
    
    // Use safe moves if available, otherwise use any move
    List<Map<String, Point>> movesToChooseFrom = safeMoves.isNotEmpty ? safeMoves : allMoves;
    return movesToChooseFrom[Random().nextInt(movesToChooseFrom.length)];
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

    developer.log('Medium mode: ${emptyPoints.length} empty points available');

    // Priority 1: Block immediate tiger threats
    Point? threatBlock = _findThreatBlockingPlacement(board, boardConfig, boardType, emptyPoints);
    if (threatBlock != null) {
      developer.log('Medium mode: blocking threat at ${threatBlock.x}, ${threatBlock.y}');
      return threatBlock;
    }

    // Priority 2: Place near tigers to limit mobility
    Point? nearTigerPlacement = _findNearTigerPlacement(board, boardConfig, boardType, emptyPoints);
    if (nearTigerPlacement != null) {
      developer.log('Medium mode: placing near tiger at ${nearTigerPlacement.x}, ${nearTigerPlacement.y}');
      return nearTigerPlacement;
    }

    // Priority 3: Place on edges (early game strategy)
    if (placedGoats < 15) {
      List<Point> edgePoints = emptyPoints.where((p) => _isEdgePosition(p, board, boardConfig, boardType)).toList();
      if (edgePoints.isNotEmpty) {
        Point selected = edgePoints[Random().nextInt(edgePoints.length)];
        developer.log('Medium mode: placing on edge at ${selected.x}, ${selected.y}');
        return selected;
      }
    }

    // Fallback: random placement
    Point selected = emptyPoints[Random().nextInt(emptyPoints.length)];
    developer.log('Medium mode: random placement at ${selected.x}, ${selected.y}');
    return selected;
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
    List<Map<String, Point>> safeMoves = [];
    for (Map<String, Point> move in allMoves) {
      if (!_resultsInImmediateCapture(move, board, boardConfig, boardType)) {
        safeMoves.add(move);
      }
    }

    if (safeMoves.isNotEmpty) {
      // Priority 2: Try to keep goats clustered
      Map<String, Point>? clusteredMove = _findClusteredMove(safeMoves, board, boardConfig, boardType);
      if (clusteredMove != null) {
        return clusteredMove;
      }
      
      // Priority 3: Move towards edges if possible
      Map<String, Point>? edgeMove = _findEdgeMove(safeMoves, board, boardConfig, boardType);
      if (edgeMove != null) {
        return edgeMove;
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

    developer.log('Hard mode: ${emptyPoints.length} empty points available');

    // Priority 1: Block potential tiger jumps
    Point? jumpBlock = _findJumpBlockingPlacement(board, boardConfig, boardType, emptyPoints, unsafeMoveHistory);
    if (jumpBlock != null) {
      developer.log('Hard mode: blocking jump at ${jumpBlock.x}, ${jumpBlock.y}');
      return jumpBlock;
    }

    // Priority 2: Form strategic walls and gradually trap tigers
    Point? strategicPlacement = _findStrategicPlacement(board, boardConfig, boardType, emptyPoints, placedGoats);
    if (strategicPlacement != null) {
      developer.log('Hard mode: strategic placement at ${strategicPlacement.x}, ${strategicPlacement.y}');
      return strategicPlacement;
    }

    // Priority 3: Place on key intersections to restrict tiger freedom
    Point? keyIntersection = _findKeyIntersectionPlacement(board, boardConfig, boardType, emptyPoints);
    if (keyIntersection != null) {
      developer.log('Hard mode: key intersection at ${keyIntersection.x}, ${keyIntersection.y}');
      return keyIntersection;
    }

    // Priority 4: Early game edge placement
    if (placedGoats < 12) {
      List<Point> edgePoints = emptyPoints.where((p) => _isEdgePosition(p, board, boardConfig, boardType)).toList();
      if (edgePoints.isNotEmpty) {
        Point selected = _findBestEdgePlacement(edgePoints, board, boardConfig, boardType);
        developer.log('Hard mode: best edge placement at ${selected.x}, ${selected.y}');
        return selected;
      }
    }

    // Fallback: safest available position
    Point selected = _findSafestPlacement(emptyPoints, board, boardConfig, boardType);
    developer.log('Hard mode: safest placement at ${selected.x}, ${selected.y}');
    return selected;
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

    // Priority 2: Keep goats clustered and connected
    Map<String, Point>? clusteredMove = _findClusteredMove(allMoves, board, boardConfig, boardType);
    if (clusteredMove != null) {
      return clusteredMove;
    }

    // Priority 3: Move to key intersections
    Map<String, Point>? keyMove = _findKeyIntersectionMove(allMoves, board, boardConfig, boardType);
    if (keyMove != null) {
      return keyMove;
    }

    // Priority 4: Avoid dangerous moves
    List<Map<String, Point>> safeMoves = [];
    for (Map<String, Point> move in allMoves) {
      if (!_resultsInImmediateCapture(move, board, boardConfig, boardType)) {
        safeMoves.add(move);
      }
    }

    if (safeMoves.isNotEmpty) {
      return _findBestHeuristicMove(safeMoves, board, boardConfig, boardType);
    }

    // Fallback: best heuristic move even if unsafe
    return _findBestHeuristicMove(allMoves, board, boardConfig, boardType);
  }

  // ===== HELPER METHODS =====
  static List<Point> _getEmptyPoints(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Point> emptyPoints = [];
    try {
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
    } catch (e) {
      developer.log('Error in _getEmptyPoints: $e');
    }
    return emptyPoints;
  }

  static List<Map<String, Point>> _getAllGoatMoves(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    List<Map<String, Point>> allMoves = [];
    try {
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
    } catch (e) {
      developer.log('Error in _getAllGoatMoves: $e');
    }
    return allMoves;
  }

  static bool _isEdgePosition(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return point.x == 0 || point.x == board.length - 1 || 
               point.y == 0 || point.y == board[0].length - 1;
      } else {
        // For Aadu Puli, consider positions with fewer connections as edges
        return point.adjacentPoints.length <= 3;
      }
    } catch (e) {
      developer.log('Error in _isEdgePosition: $e');
      return false;
    }
  }

  static bool _resultsInImmediateCapture(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      Point to = move['to']!;
      
      if (boardType == BoardType.square) {
        // Check if any tiger can capture this goat immediately
        for (var row in board) {
          for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
            if (_canTigerCaptureGoat(tiger, to, board)) {
              return true;
            }
          }
        }
      } else if (boardConfig != null) {
        for (var tiger in boardConfig!.nodes.where((n) => n.type == PieceType.tiger)) {
          if (_canTigerCaptureGoatAaduPuli(tiger, to, boardConfig!)) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      developer.log('Error in _resultsInImmediateCapture: $e');
      return false;
    }
  }

  static bool _canTigerCaptureGoat(Point tiger, Point goat, List<List<Point>> board) {
    try {
      // Check if tiger is adjacent to goat and can jump over it
      if (!tiger.adjacentPoints.contains(goat)) return false;
      
      // Find the landing position
      int dx = goat.x - tiger.x;
      int dy = goat.y - tiger.y;
      int landingX = goat.x + dx;
      int landingY = goat.y + dy;
      
      // Check if landing position is valid and empty
      if (landingX >= 0 && landingX < board.length && 
          landingY >= 0 && landingY < board[0].length) {
        Point landing = board[landingX][landingY];
        return landing.type == PieceType.empty;
      }
      
      return false;
    } catch (e) {
      developer.log('Error in _canTigerCaptureGoat: $e');
      return false;
    }
  }

  static bool _canTigerCaptureGoatAaduPuli(Point tiger, Point goat, BoardConfig boardConfig) {
    try {
      // Check if tiger is adjacent to goat and can jump over it
      if (!tiger.adjacentPoints.contains(goat)) return false;
      
      // Find landing position by checking goat's adjacent points
      for (Point landing in goat.adjacentPoints) {
        if (landing != tiger && landing.type == PieceType.empty) {
          String key = '${tiger.id},${goat.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key)) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      developer.log('Error in _canTigerCaptureGoatAaduPuli: $e');
      return false;
    }
  }

  // Medium mode helpers
  static Point? _findThreatBlockingPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    try {
      for (Point point in emptyPoints) {
        if (_blocksImmediateThreat(point, board, boardConfig, boardType)) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findThreatBlockingPlacement: $e');
    }
    return null;
  }

  static Point? _findNearTigerPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    try {
      List<Point> nearTigerPoints = [];
      for (Point point in emptyPoints) {
        if (_isAdjacentToTiger(point, board, boardConfig, boardType)) {
          nearTigerPoints.add(point);
        }
      }
      
      if (nearTigerPoints.isNotEmpty) {
        return nearTigerPoints[Random().nextInt(nearTigerPoints.length)];
      }
    } catch (e) {
      developer.log('Error in _findNearTigerPlacement: $e');
    }
    return null;
  }

  static Map<String, Point>? _findClusteredMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
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
    } catch (e) {
      developer.log('Error in _findClusteredMove: $e');
      return null;
    }
  }

  static Map<String, Point>? _findEdgeMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      List<Map<String, Point>> edgeMoves = [];
      for (Map<String, Point> move in moves) {
        if (_isEdgePosition(move['to']!, board, boardConfig, boardType)) {
          edgeMoves.add(move);
        }
      }
      
      if (edgeMoves.isNotEmpty) {
        return edgeMoves[Random().nextInt(edgeMoves.length)];
      }
    } catch (e) {
      developer.log('Error in _findEdgeMove: $e');
    }
    return null;
  }

  // Hard mode helpers
  static Point? _findJumpBlockingPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
    Set<String> unsafeMoveHistory,
  ) {
    try {
      for (Point point in emptyPoints) {
        if (_blocksTigerJump(point, board, boardConfig, boardType) && 
            !unsafeMoveHistory.contains('${point.x},${point.y}')) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findJumpBlockingPlacement: $e');
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
    try {
      for (Point point in emptyPoints) {
        if (_formsStrategicWall(point, board, boardConfig, boardType, placedGoats)) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findStrategicPlacement: $e');
    }
    return null;
  }

  static Point? _findKeyIntersectionPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    try {
      for (Point point in emptyPoints) {
        if (_isKeyIntersection(point, board, boardConfig, boardType)) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findKeyIntersectionPlacement: $e');
    }
    return null;
  }

  static Point _findBestEdgePlacement(
    List<Point> edgePoints,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      Point bestPoint = edgePoints.first;
      double bestScore = double.negativeInfinity;
      
      for (Point point in edgePoints) {
        double score = _evaluatePlacementScore(point, board, boardConfig, boardType);
        if (score > bestScore) {
          bestScore = score;
          bestPoint = point;
        }
      }
      
      return bestPoint;
    } catch (e) {
      developer.log('Error in _findBestEdgePlacement: $e');
      return edgePoints.first;
    }
  }

  static Point _findSafestPlacement(
    List<Point> emptyPoints,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
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
    } catch (e) {
      developer.log('Error in _findSafestPlacement: $e');
      return emptyPoints.first;
    }
  }

  static Map<String, Point>? _findJumpBlockingMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      for (Map<String, Point> move in moves) {
        if (_blocksTigerJumpMove(move, board, boardConfig, boardType)) {
          return move;
        }
      }
    } catch (e) {
      developer.log('Error in _findJumpBlockingMove: $e');
    }
    return null;
  }

  static Map<String, Point>? _findKeyIntersectionMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      for (Map<String, Point> move in moves) {
        if (_isKeyIntersection(move['to']!, board, boardConfig, boardType)) {
          return move;
        }
      }
    } catch (e) {
      developer.log('Error in _findKeyIntersectionMove: $e');
    }
    return null;
  }

  static Map<String, Point> _findBestHeuristicMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
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
    } catch (e) {
      developer.log('Error in _findBestHeuristicMove: $e');
      return moves.first;
    }
  }

  // ===== EVALUATION METHODS =====
  static bool _blocksImmediateThreat(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _blocksSquareThreat(point, board);
      } else {
        return _blocksAaduPuliThreat(point, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _blocksImmediateThreat: $e');
      return false;
    }
  }

  static bool _isAdjacentToTiger(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      return point.adjacentPoints.any((adj) => adj.type == PieceType.tiger);
    } catch (e) {
      developer.log('Error in _isAdjacentToTiger: $e');
      return false;
    }
  }

  static int _countAdjacentGoats(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      return point.adjacentPoints.where((adj) => adj.type == PieceType.goat).length;
    } catch (e) {
      developer.log('Error in _countAdjacentGoats: $e');
      return 0;
    }
  }

  static bool _blocksTigerJump(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _blocksSquareJump(point, board);
      } else {
        return _blocksAaduPuliJump(point, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _blocksTigerJump: $e');
      return false;
    }
  }

  static bool _formsStrategicWall(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType, int placedGoats) {
    try {
      if (boardType == BoardType.square) {
        return _formsSquareWall(point, board, placedGoats);
      } else {
        return _formsAaduPuliWall(point, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _formsStrategicWall: $e');
      return false;
    }
  }

  static bool _isKeyIntersection(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _isSquareKeyIntersection(point, board);
      } else {
        return _isAaduPuliKeyIntersection(point, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _isKeyIntersection: $e');
      return false;
    }
  }

  static double _calculateRisk(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _calculateSquareRisk(point, board);
      } else {
        return _calculateAaduPuliRisk(point, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _calculateRisk: $e');
      return 0.0;
    }
  }

  static bool _blocksTigerJumpMove(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _blocksSquareJumpMove(move, board);
      } else {
        return _blocksAaduPuliJumpMove(move, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _blocksTigerJumpMove: $e');
      return false;
    }
  }

  static double _evaluateMoveHeuristic(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _evaluateSquareHeuristic(move, board);
      } else {
        return _evaluateAaduPuliHeuristic(move, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _evaluateMoveHeuristic: $e');
      return 0.0;
    }
  }

  static double _evaluatePlacementScore(Point point, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _evaluateSquarePlacement(point, board);
      } else {
        return _evaluateAaduPuliPlacement(point, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _evaluatePlacementScore: $e');
      return 0.0;
    }
  }

  // ===== BOARD-SPECIFIC IMPLEMENTATIONS =====
  // Square board implementations
  static bool _blocksSquareThreat(Point point, List<List<Point>> board) {
    try {
      for (var row in board) {
        for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
          var tigerMoves = square.SquareBoardLogic.getValidMoves(tiger, board);
          for (var move in tigerMoves) {
            if ((move.x - tiger.x).abs() == 2 || (move.y - tiger.y).abs() == 2) {
              int midX = (tiger.x + move.x) ~/ 2;
              int midY = (tiger.y + move.y) ~/ 2;
              if (midX == point.x && midY == point.y) {
                return true;
              }
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error in _blocksSquareThreat: $e');
    }
    return false;
  }

  static bool _blocksSquareJump(Point point, List<List<Point>> board) {
    try {
      for (var row in board) {
        for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
          for (var adj in tiger.adjacentPoints) {
            if (adj.type == PieceType.goat) {
              int dx = adj.x - tiger.x;
              int dy = adj.y - tiger.y;
              int landingX = adj.x + dx;
              int landingY = adj.y + dy;
              if (landingX >= 0 && landingX < board.length && 
                  landingY >= 0 && landingY < board[0].length &&
                  landingX == point.x && landingY == point.y) {
                return true;
              }
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error in _blocksSquareJump: $e');
    }
    return false;
  }

  static bool _formsSquareWall(Point point, List<List<Point>> board, int placedGoats) {
    try {
      if (placedGoats < 12) {
        return point.x == 0 || point.x == board.length - 1 || 
               point.y == 0 || point.y == board[0].length - 1;
      }
      return point.adjacentPoints.where((adj) => adj.type == PieceType.goat).length >= 2;
    } catch (e) {
      developer.log('Error in _formsSquareWall: $e');
      return false;
    }
  }

  static bool _isSquareKeyIntersection(Point point, List<List<Point>> board) {
    try {
      int adjacentEmpty = point.adjacentPoints.where((adj) => adj.type == PieceType.empty).length;
      return adjacentEmpty <= 2;
    } catch (e) {
      developer.log('Error in _isSquareKeyIntersection: $e');
      return false;
    }
  }

  static double _calculateSquareRisk(Point point, List<List<Point>> board) {
    try {
      double risk = 0.0;
      for (var row in board) {
        for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
          double distance = ((point.x - tiger.x) * (point.x - tiger.x) + 
                            (point.y - tiger.y) * (point.y - tiger.y)).toDouble();
          risk += 1.0 / (distance + 1.0);
        }
      }
      return risk;
    } catch (e) {
      developer.log('Error in _calculateSquareRisk: $e');
      return 0.0;
    }
  }

  static bool _blocksSquareJumpMove(Map<String, Point> move, List<List<Point>> board) {
    try {
      Point to = move['to']!;
      return _blocksSquareJump(to, board);
    } catch (e) {
      developer.log('Error in _blocksSquareJumpMove: $e');
      return false;
    }
  }

  static double _evaluateSquareHeuristic(Map<String, Point> move, List<List<Point>> board) {
    try {
      Point to = move['to']!;
      double score = 0.0;
      
      if (_blocksSquareJump(to, board)) {
        score += 200.0;
      }
      
      score += _countAdjacentGoats(to, board, null, BoardType.square) * 50.0;
      
      if (to.x == 0 || to.x == board.length - 1 || to.y == 0 || to.y == board[0].length - 1) {
        score += 30.0;
      }
      
      score -= _calculateSquareRisk(to, board) * 100.0;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateSquareHeuristic: $e');
      return 0.0;
    }
  }

  static double _evaluateSquarePlacement(Point point, List<List<Point>> board) {
    try {
      double score = 0.0;
      
      if (_blocksSquareJump(point, board)) {
        score += 300.0;
      }
      
      score += _countAdjacentGoats(point, board, null, BoardType.square) * 100.0;
      
      if (point.x == 0 || point.x == board.length - 1 || point.y == 0 || point.y == board[0].length - 1) {
        score += 50.0;
      }
      
      score -= _calculateSquareRisk(point, board) * 50.0;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateSquarePlacement: $e');
      return 0.0;
    }
  }

  // Aadu Puli board implementations
  static bool _blocksAaduPuliThreat(Point point, BoardConfig boardConfig) {
    try {
      for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
        for (var landing in point.adjacentPoints) {
          if (landing == tiger || landing.type != PieceType.empty) continue;
          String key = '${tiger.id},${point.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key)) {
            return true;
          }
        }
      }
    } catch (e) {
      developer.log('Error in _blocksAaduPuliThreat: $e');
    }
    return false;
  }

  static bool _blocksAaduPuliJump(Point point, BoardConfig boardConfig) {
    try {
      for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
        for (var goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
          for (var landing in goat.adjacentPoints) {
            if (landing == tiger || landing.type != PieceType.empty) continue;
            String key = '${tiger.id},${goat.id},${landing.id}';
            if (aadu.AaduPuliLogic.isJumpTriple(key) && landing.id == point.id) {
              return true;
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error in _blocksAaduPuliJump: $e');
    }
    return false;
  }

  static bool _formsAaduPuliWall(Point point, BoardConfig boardConfig) {
    try {
      return point.adjacentPoints.where((adj) => adj.type == PieceType.goat).length >= 2;
    } catch (e) {
      developer.log('Error in _formsAaduPuliWall: $e');
      return false;
    }
  }

  static bool _isAaduPuliKeyIntersection(Point point, BoardConfig boardConfig) {
    try {
      int adjacentEmpty = point.adjacentPoints.where((adj) => adj.type == PieceType.empty).length;
      return adjacentEmpty <= 2;
    } catch (e) {
      developer.log('Error in _isAaduPuliKeyIntersection: $e');
      return false;
    }
  }

  static double _calculateAaduPuliRisk(Point point, BoardConfig boardConfig) {
    try {
      double risk = 0.0;
      for (var tiger in boardConfig.nodes.where((n) => n.type == PieceType.tiger)) {
        if (tiger.adjacentPoints.contains(point)) {
          risk += 100.0;
        }
      }
      return risk;
    } catch (e) {
      developer.log('Error in _calculateAaduPuliRisk: $e');
      return 0.0;
    }
  }

  static bool _blocksAaduPuliJumpMove(Map<String, Point> move, BoardConfig boardConfig) {
    try {
      Point to = move['to']!;
      return _blocksAaduPuliJump(to, boardConfig);
    } catch (e) {
      developer.log('Error in _blocksAaduPuliJumpMove: $e');
      return false;
    }
  }

  static double _evaluateAaduPuliHeuristic(Map<String, Point> move, BoardConfig boardConfig) {
    try {
      Point to = move['to']!;
      double score = 0.0;
      
      if (_blocksAaduPuliJump(to, boardConfig)) {
        score += 200.0;
      }
      
      score += _countAdjacentGoats(to, [], boardConfig, BoardType.aaduPuli) * 50.0;
      
      score -= _calculateAaduPuliRisk(to, boardConfig);
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateAaduPuliHeuristic: $e');
      return 0.0;
    }
  }

  static double _evaluateAaduPuliPlacement(Point point, BoardConfig boardConfig) {
    try {
      double score = 0.0;
      
      if (_blocksAaduPuliJump(point, boardConfig)) {
        score += 300.0;
      }
      
      score += _countAdjacentGoats(point, [], boardConfig, BoardType.aaduPuli) * 100.0;
      
      score -= _calculateAaduPuliRisk(point, boardConfig) * 0.5;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateAaduPuliPlacement: $e');
      return 0.0;
    }
  }
}