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
        case Difficulty.unbeatable:
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
        case Difficulty.unbeatable:
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
    List<Point> edgePoints = emptyPoints.where((p) => _isEdgePosition(p, board, boardConfig, boardType)).toList();
    
    if (edgePoints.isNotEmpty && Random().nextDouble() < 0.6) {
      Point selected = edgePoints[Random().nextInt(edgePoints.length)];
      developer.log('Easy mode: edge placement at ${selected.x}, ${selected.y}');
      return selected;
    }
    
    Point selected = emptyPoints[Random().nextInt(emptyPoints.length)];
    developer.log('Easy mode: random placement at ${selected.x}, ${selected.y}');
    return selected;
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

    developer.log('Easy mode: ${allMoves.length} moves available');

    // Simple random movement with slight preference for edges
    List<Map<String, Point>> edgeMoves = [];
    for (Map<String, Point> move in allMoves) {
      if (_isEdgePosition(move['to']!, board, boardConfig, boardType)) {
        edgeMoves.add(move);
      }
    }

    if (edgeMoves.isNotEmpty && Random().nextDouble() < 0.5) {
      Map<String, Point> selected = edgeMoves[Random().nextInt(edgeMoves.length)];
      developer.log('Easy mode: edge move from ${selected['from']!.x}, ${selected['from']!.y} to ${selected['to']!.x}, ${selected['to']!.y}');
      return selected;
    }

    Map<String, Point> selected = allMoves[Random().nextInt(allMoves.length)];
    developer.log('Easy mode: random move from ${selected['from']!.x}, ${selected['from']!.y} to ${selected['to']!.x}, ${selected['to']!.y}');
    return selected;
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
      developer.log('Medium mode: threat blocking at ${threatBlock.x}, ${threatBlock.y}');
      return threatBlock;
    }

    // Priority 2: Place near tigers to limit their mobility
    Point? nearTiger = _findNearTigerPlacement(board, boardConfig, boardType, emptyPoints);
    if (nearTiger != null) {
      developer.log('Medium mode: near tiger placement at ${nearTiger.x}, ${nearTiger.y}');
      return nearTiger;
    }

    // Priority 3: Form basic defensive formations
    Point? defensiveFormation = _findDefensiveFormationPlacement(board, boardConfig, boardType, emptyPoints);
    if (defensiveFormation != null) {
      developer.log('Medium mode: defensive formation at ${defensiveFormation.x}, ${defensiveFormation.y}');
      return defensiveFormation;
    }

    // Priority 4: Place on edges for safety
    List<Point> edgePoints = emptyPoints.where((p) => _isEdgePosition(p, board, boardConfig, boardType)).toList();
    if (edgePoints.isNotEmpty) {
      Point selected = edgePoints[Random().nextInt(edgePoints.length)];
      developer.log('Medium mode: edge placement at ${selected.x}, ${selected.y}');
      return selected;
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
        developer.log('Medium mode: clustered move');
        return clusteredMove;
      }
      
      // Priority 3: Move towards edges if possible
      Map<String, Point>? edgeMove = _findEdgeMove(safeMoves, board, boardConfig, boardType);
      if (edgeMove != null) {
        developer.log('Medium mode: edge move');
        return edgeMove;
      }
      
      // Priority 4: Block obvious tiger threats
      Map<String, Point>? threatBlock = _findThreatBlockingMove(safeMoves, board, boardConfig, boardType);
      if (threatBlock != null) {
        developer.log('Medium mode: threat blocking move');
        return threatBlock;
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

    // Priority 1: Block immediate tiger jumps (CRITICAL)
    Point? jumpBlock = _findCriticalJumpBlock(board, boardConfig, boardType, emptyPoints);
    if (jumpBlock != null) {
      developer.log('Hard mode: CRITICAL jump block at ${jumpBlock.x}, ${jumpBlock.y}');
      return jumpBlock;
    }

    // Priority 2: Block potential tiger escape routes
    Point? escapeBlock = _findEscapeRouteBlock(board, boardConfig, boardType, emptyPoints);
    if (escapeBlock != null) {
      developer.log('Hard mode: escape route block at ${escapeBlock.x}, ${escapeBlock.y}');
      return escapeBlock;
    }

    // Priority 3: Form defensive walls around tigers
    Point? wallFormation = _findWallFormationPlacement(board, boardConfig, boardType, emptyPoints, placedGoats);
    if (wallFormation != null) {
      developer.log('Hard mode: wall formation at ${wallFormation.x}, ${wallFormation.y}');
      return wallFormation;
    }

    // Priority 4: Place on key intersections to restrict tiger movement
    Point? keyIntersection = _findKeyIntersectionPlacement(board, boardConfig, boardType, emptyPoints);
    if (keyIntersection != null) {
      developer.log('Hard mode: key intersection at ${keyIntersection.x}, ${keyIntersection.y}');
      return keyIntersection;
    }

    // Priority 5: Early game - place near tigers to limit their mobility
    if (placedGoats < 15) {
      Point? nearTiger = _findNearTigerPlacement(board, boardConfig, boardType, emptyPoints);
      if (nearTiger != null) {
        developer.log('Hard mode: near tiger placement at ${nearTiger.x}, ${nearTiger.y}');
        return nearTiger;
      }
    }

    // Priority 6: Place on edges to create boundaries
    List<Point> edgePoints = emptyPoints.where((p) => _isEdgePosition(p, board, boardConfig, boardType)).toList();
    if (edgePoints.isNotEmpty) {
      Point selected = _findBestEdgePlacement(edgePoints, board, boardConfig, boardType);
      developer.log('Hard mode: best edge placement at ${selected.x}, ${selected.y}');
      return selected;
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

    // Priority 1: Block imminent tiger jumps (CRITICAL)
    Map<String, Point>? jumpBlock = _findCriticalJumpBlockMove(allMoves, board, boardConfig, boardType);
    if (jumpBlock != null) {
      developer.log('Hard mode: CRITICAL jump block move');
      return jumpBlock;
    }

    // Priority 2: Move to block tiger escape routes
    Map<String, Point>? escapeBlock = _findEscapeBlockMove(allMoves, board, boardConfig, boardType);
    if (escapeBlock != null) {
      developer.log('Hard mode: escape block move');
      return escapeBlock;
    }

    // Priority 3: Strengthen existing walls and formations
    Map<String, Point>? wallStrengthen = _findWallStrengtheningMove(allMoves, board, boardConfig, boardType);
    if (wallStrengthen != null) {
      developer.log('Hard mode: wall strengthening move');
      return wallStrengthen;
    }

    // Priority 4: Move to key intersections
    Map<String, Point>? keyMove = _findKeyIntersectionMove(allMoves, board, boardConfig, boardType);
    if (keyMove != null) {
      developer.log('Hard mode: key intersection move');
      return keyMove;
    }

    // Priority 5: Keep goats clustered and connected
    Map<String, Point>? clusteredMove = _findClusteredMove(allMoves, board, boardConfig, boardType);
    if (clusteredMove != null) {
      developer.log('Hard mode: clustered move');
      return clusteredMove;
    }

    // Priority 6: Avoid dangerous moves
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

  static Point? _findDefensiveFormationPlacement(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    try {
      for (Point point in emptyPoints) {
        if (_countAdjacentGoats(point, board, boardConfig, boardType) >= 1) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findDefensiveFormationPlacement: $e');
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

  static Map<String, Point>? _findThreatBlockingMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      for (Map<String, Point> move in moves) {
        if (_blocksImmediateThreat(move['to']!, board, boardConfig, boardType)) {
          return move;
        }
      }
    } catch (e) {
      developer.log('Error in _findThreatBlockingMove: $e');
    }
    return null;
  }

  // Hard mode helpers
  static Point? _findCriticalJumpBlock(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    try {
      for (Point point in emptyPoints) {
        if (_blocksTigerJump(point, board, boardConfig, boardType) && 
            !_isAdjacentToTiger(point, board, boardConfig, boardType)) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findCriticalJumpBlock: $e');
    }
    return null;
  }

  static Point? _findEscapeRouteBlock(
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
    List<Point> emptyPoints,
  ) {
    try {
      for (Point point in emptyPoints) {
        if (_isAdjacentToTiger(point, board, boardConfig, boardType) && 
            !_blocksTigerJump(point, board, boardConfig, boardType)) {
          return point;
        }
      }
    } catch (e) {
      developer.log('Error in _findEscapeRouteBlock: $e');
    }
    return null;
  }

  static Point? _findWallFormationPlacement(
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
      developer.log('Error in _findWallFormationPlacement: $e');
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

  static Map<String, Point>? _findCriticalJumpBlockMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      for (Map<String, Point> move in moves) {
        if (_blocksTigerJumpMove(move, board, boardConfig, boardType) && 
            !_isAdjacentToTigerMove(move, board, boardConfig, boardType)) {
          return move;
        }
      }
    } catch (e) {
      developer.log('Error in _findCriticalJumpBlockMove: $e');
    }
    return null;
  }

  static Map<String, Point>? _findEscapeBlockMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      for (Map<String, Point> move in moves) {
        if (_isAdjacentToTigerMove(move, board, boardConfig, boardType) && 
            !_blocksTigerJumpMove(move, board, boardConfig, boardType)) {
          return move;
        }
      }
    } catch (e) {
      developer.log('Error in _findEscapeBlockMove: $e');
    }
    return null;
  }

  static Map<String, Point>? _findWallStrengtheningMove(
    List<Map<String, Point>> moves,
    List<List<Point>> board,
    BoardConfig? boardConfig,
    BoardType boardType,
  ) {
    try {
      for (Map<String, Point> move in moves) {
        if (_formsStrategicWallMove(move, board, boardConfig, boardType)) {
          return move;
        }
      }
    } catch (e) {
      developer.log('Error in _findWallStrengtheningMove: $e');
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

  static bool _isAdjacentToTigerMove(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      return move['to']!.adjacentPoints.any((adj) => adj.type == PieceType.tiger);
    } catch (e) {
      developer.log('Error in _isAdjacentToTigerMove: $e');
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

  static bool _blocksTigerJumpMove(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _blocksSquareJump(move['to']!, board);
      } else {
        return _blocksAaduPuliJump(move['to']!, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _blocksTigerJumpMove: $e');
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

  static bool _formsStrategicWallMove(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _formsSquareWall(move['to']!, board, 0); // Placeholder for placedGoats
      } else {
        return _formsAaduPuliWall(move['to']!, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _formsStrategicWallMove: $e');
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

  static bool _isKeyIntersectionMove(Map<String, Point> move, List<List<Point>> board, BoardConfig? boardConfig, BoardType boardType) {
    try {
      if (boardType == BoardType.square) {
        return _isSquareKeyIntersection(move['to']!, board);
      } else {
        return _isAaduPuliKeyIntersection(move['to']!, boardConfig!);
      }
    } catch (e) {
      developer.log('Error in _isKeyIntersectionMove: $e');
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
      
      // CRITICAL: Block tiger jumps
      if (_blocksSquareJump(to, board)) {
        score += 500.0;
      }
      
      // Block tiger threats
      if (_blocksSquareThreat(to, board)) {
        score += 300.0;
      }
      
      // Form walls and clusters
      score += _countAdjacentGoats(to, board, null, BoardType.square) * 100.0;
      
      // Edge positions are safer
      if (to.x == 0 || to.x == board.length - 1 || to.y == 0 || to.y == board[0].length - 1) {
        score += 50.0;
      }
      
      // Key intersections
      if (_isSquareKeyIntersection(to, board)) {
        score += 200.0;
      }
      
      // Penalize risky positions
      score -= _calculateSquareRisk(to, board) * 200.0;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateSquareHeuristic: $e');
      return 0.0;
    }
  }

  static double _evaluateSquarePlacement(Point point, List<List<Point>> board) {
    try {
      double score = 0.0;
      
      // CRITICAL: Block tiger jumps
      if (_blocksSquareJump(point, board)) {
        score += 800.0;
      }
      
      // Block tiger threats
      if (_blocksSquareThreat(point, board)) {
        score += 400.0;
      }
      
      // Form walls and clusters
      score += _countAdjacentGoats(point, board, null, BoardType.square) * 150.0;
      
      // Edge positions are safer
      if (point.x == 0 || point.x == board.length - 1 || point.y == 0 || point.y == board[0].length - 1) {
        score += 100.0;
      }
      
      // Key intersections
      if (_isSquareKeyIntersection(point, board)) {
        score += 300.0;
      }
      
      // Penalize risky positions
      score -= _calculateSquareRisk(point, board) * 100.0;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateSquarePlacement: $e');
      return 0.0;
    }
  }

  static double _evaluateAaduPuliHeuristic(Map<String, Point> move, BoardConfig boardConfig) {
    try {
      Point to = move['to']!;
      double score = 0.0;
      
      // CRITICAL: Block tiger jumps
      if (_blocksAaduPuliJump(to, boardConfig)) {
        score += 500.0;
      }
      
      // Block tiger threats
      if (_blocksAaduPuliThreat(to, boardConfig)) {
        score += 300.0;
      }
      
      // Form walls and clusters
      score += _countAdjacentGoats(to, [], boardConfig, BoardType.aaduPuli) * 100.0;
      
      // Key intersections
      if (_isAaduPuliKeyIntersection(to, boardConfig)) {
        score += 200.0;
      }
      
      // Penalize risky positions
      score -= _calculateAaduPuliRisk(to, boardConfig) * 2.0;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateAaduPuliHeuristic: $e');
      return 0.0;
    }
  }

  static double _evaluateAaduPuliPlacement(Point point, BoardConfig boardConfig) {
    try {
      double score = 0.0;
      
      // CRITICAL: Block tiger jumps
      if (_blocksAaduPuliJump(point, boardConfig)) {
        score += 800.0;
      }
      
      // Block tiger threats
      if (_blocksAaduPuliThreat(point, boardConfig)) {
        score += 400.0;
      }
      
      // Form walls and clusters
      score += _countAdjacentGoats(point, [], boardConfig, BoardType.aaduPuli) * 150.0;
      
      // Key intersections
      if (_isAaduPuliKeyIntersection(point, boardConfig)) {
        score += 300.0;
      }
      
      // Penalize risky positions
      score -= _calculateAaduPuliRisk(point, boardConfig) * 1.0;
      
      return score;
    } catch (e) {
      developer.log('Error in _evaluateAaduPuliPlacement: $e');
      return 0.0;
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

  static bool _blocksAaduPuliJumpMove(Map<String, Point> move, BoardConfig boardConfig) {
    try {
      Point to = move['to']!;
      return _blocksAaduPuliJump(to, boardConfig);
    } catch (e) {
      developer.log('Error in _blocksAaduPuliJumpMove: $e');
      return false;
    }
  }
}