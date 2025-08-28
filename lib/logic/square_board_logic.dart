import '../models/piece.dart';

class SquareBoardLogic {
  static List<List<Point>> initializeBoard() {
    final board = List.generate(
      5,
      (x) => List.generate(5, (y) => Point(x: x, y: y, adjacentPoints: [])),
    );

    for (int x = 0; x < 5; x++) {
      for (int y = 0; y < 5; y++) {
        board[x][y].adjacentPoints = _calculateAdjacentPoints(x, y, board);
      }
    }

    board[0][0].type = PieceType.tiger;
    board[0][4].type = PieceType.tiger;
    board[4][0].type = PieceType.tiger;
    board[4][4].type = PieceType.tiger;

    return board;
  }

  static List<Point> _calculateAdjacentPoints(
    int x,
    int y,
    List<List<Point>> board,
  ) {
    List<Point> adjacents = [];
    const directions = [
      [0, 1],
      [1, 0],
      [0, -1],
      [-1, 0],
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1],
    ];

    for (var dir in directions) {
      int nx = x + dir[0];
      int ny = y + dir[1];
      if (nx >= 0 && nx < 5 && ny >= 0 && ny < 5) {
        if (dir[0] == 0 || dir[1] == 0) {
          adjacents.add(board[nx][ny]);
        } else {
          if ((x % 2 == 0 && y % 2 == 0) || (x % 2 == 1 && y % 2 == 1)) {
            adjacents.add(board[nx][ny]);
          }
        }
      }
    }
    return adjacents;
  }

  static List<Point> getValidMoves(Point piece, List<List<Point>> board) {
    List<Point> moves = [];
    for (final adjacent in piece.adjacentPoints) {
      if (adjacent.type == PieceType.empty) {
        moves.add(adjacent);
      }
    }

    if (piece.type == PieceType.tiger) {
      for (final adjacent in piece.adjacentPoints) {
        if (adjacent.type == PieceType.goat) {
          int dx = adjacent.x - piece.x;
          int dy = adjacent.y - piece.y;
          int jumpX = adjacent.x + dx;
          int jumpY = adjacent.y + dy;
          if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
            Point jumpPoint = board[jumpX][jumpY];
            if (jumpPoint.type == PieceType.empty &&
                adjacent.adjacentPoints.contains(jumpPoint)) {
              moves.add(jumpPoint);
            }
          }
        }
      }
    }
    return moves;
  }

  static MoveResult executeMove(Point from, Point to, List<List<Point>> board) {
    if (to.type != PieceType.empty) return MoveResult.invalid;

    final isJump = (to.x - from.x).abs() == 2 || (to.y - from.y).abs() == 2;
    to.type = from.type;
    from.type = PieceType.empty;

    if (isJump) {
      final capturedX = (from.x + to.x) ~/ 2;
      final capturedY = (from.y + to.y) ~/ 2;

      if (capturedX >= 0 && capturedX < 5 && capturedY >= 0 && capturedY < 5) {
        final capturedPoint = board[capturedX][capturedY];
        if (capturedPoint.type == PieceType.goat) {
          capturedPoint.type = PieceType.empty;
          return MoveResult.capture;
        }
      }
    }
    return MoveResult.regular;
  }

  static bool checkTigerWin(int capturedGoats) => capturedGoats >= 5;

  static bool checkGoatWin(List<List<Point>> board) {
    for (var row in board) {
      for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
        if (getValidMoves(tiger, board).isNotEmpty) return false;
      }
    }
    return true;
  }
}
enum MoveResult { invalid, regular, capture, captureWithMoreJumps }