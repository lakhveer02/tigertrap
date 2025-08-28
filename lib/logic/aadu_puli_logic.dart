import '../models/piece.dart';
import '../models/board_config.dart';

class AaduPuliLogic {
  static const int maxGoats = 15;
  static const int requiredCaptures = 6;
  
  static final List<List<int>> _lines = [
    [1,2,3,4,5,6],    
    [7,8,9,10,11,12],  
    [13,14,15,16,17,18],
    [19,20,21,22],     
    [0,2,8,14,19],    
    [1,7,13],        
    [0,3,9,15,20],    
    [0,4,10,16,21],   
    [0,5,11,17,22],   
    [6,12,18],        
  ];

  static final Set<String> _jumpTriples = _createJumpTriples();

  static Set<String> _createJumpTriples() {
    final triples = <String>{};
    for (final line in _lines) {
      for (int i = 0; i <= line.length - 3; i++) {
        triples.add('${line[i]},${line[i+1]},${line[i+2]}');
      }
      for (int i = line.length - 1; i >= 2; i--) {
        triples.add('${line[i]},${line[i-1]},${line[i-2]}');
      }
    }
    return triples;
  }

  static void initializeBoard(BoardConfig config) {
    for (var node in config.nodes) {
      node.type = PieceType.empty;
    }
    config.nodes[0].type = PieceType.tiger;
    config.nodes[3].type = PieceType.tiger;
    config.nodes[4].type = PieceType.tiger;
  }

  static List<Point> getValidMoves(Point piece, BoardConfig config) {
    List<Point> moves = [];

    if (piece.type == PieceType.goat) {
      moves.addAll(piece.adjacentPoints.where((p) => p.type == PieceType.empty));
    } 
    else if (piece.type == PieceType.tiger) {
      moves.addAll(piece.adjacentPoints.where((p) => p.type == PieceType.empty));
      for (final goat in piece.adjacentPoints) {
        if (goat.type != PieceType.goat) continue;
        for (final landing in goat.adjacentPoints) {
          if (landing == piece || landing.type != PieceType.empty) continue;
          final key = '${piece.id},${goat.id},${landing.id}';
          if (_jumpTriples.contains(key)) {
            moves.add(landing);
          }
        }
      }
    }
    return moves;
  }

  static Point? _getJumpedGoat(Point from, Point to) {
    for (final goat in from.adjacentPoints) {
      if (goat.type != PieceType.goat) continue;
      
      final key = '${from.id},${goat.id},${to.id}';
      if (_jumpTriples.contains(key)) {
        return goat;
      }
    }
    return null;
  }

  static MoveResult executeMove(Point from, Point to, BoardConfig config) {
    final isAdjacent = from.adjacentPoints.contains(to);
    
    if (to.type != PieceType.empty) return MoveResult.invalid;
    
    if (from.type == PieceType.goat) {
      if (!isAdjacent) return MoveResult.invalid;
      to.type = from.type;
      from.type = PieceType.empty;
      return MoveResult.regular;
    } 
    else if (from.type == PieceType.tiger) {
      if (isAdjacent) {
        to.type = from.type;
        from.type = PieceType.empty;
        return MoveResult.regular;
      } else {
        final jumpedGoat = _getJumpedGoat(from, to);
        if (jumpedGoat == null) return MoveResult.invalid;
        
        to.type = from.type;
        from.type = PieceType.empty;
        jumpedGoat.type = PieceType.empty;
        return MoveResult.capture;
      }
    }
    return MoveResult.invalid;
  }

  static bool checkTigerWin(int capturedGoats) => capturedGoats >= requiredCaptures;

  static bool checkGoatWin(BoardConfig config) {
    return config.nodes
        .where((n) => n.type == PieceType.tiger)
        .every((tiger) => getValidMoves(tiger, config).isEmpty);
  }

  static bool isJumpTriple(String key) => _jumpTriples.contains(key);
  
  static List<List<int>> get lines => _lines;
}

enum MoveResult { invalid, regular, capture } 