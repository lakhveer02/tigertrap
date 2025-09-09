class GoatAIHardMode {
  final int searchDepth;
  GoatAIHardMode({this.searchDepth = 3});

  Move getBestMove(Board board, bool isPlacementPhase) {
    int bestScore = -99999;
    Move? bestMove;
    List<Move> moves = isPlacementPhase ? board.getGoatPlacements() : board.getGoatMoves();
    for (var move in moves) {
      Board next = board.applyMove(move);
      int score = minimax(next, searchDepth - 1, false, -100000, 100000);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove ?? moves.first;
  }

  int minimax(Board board, int depth, bool isGoatTurn, int alpha, int beta) {
    if (depth == 0 || board.isGameOver()) {
      return evaluate(board);
    }
    if (isGoatTurn) {
      int maxEval = -99999;
      for (var move in board.getGoatMoves()) {
        int eval = minimax(board.applyMove(move), depth - 1, false, alpha, beta);
        maxEval = maxEval > eval ? maxEval : eval;
        alpha = alpha > eval ? alpha : eval;
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 99999;
      for (var move in board.getTigerMoves()) {
        int eval = minimax(board.applyMove(move), depth - 1, true, alpha, beta);
        minEval = minEval < eval ? minEval : eval;
        beta = beta < eval ? beta : eval;
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int evaluate(Board board) {
    int blockedTigers = board.countBlockedTigers();
    int safeGoats = board.countSafeGoats();
    int goatsInDanger = board.countGoatsInDanger();
    int tigersTrappedInCorner = board.countTigersInCorner();
    int goatsCaptured = board.goatsCaptured;
    int goatMobility = board.goatMobility();
    return (blockedTigers * 50)
      + (safeGoats * 10)
      - (goatsInDanger * 20)
      + (tigersTrappedInCorner * 40)
      - (goatsCaptured * 30)
      + (goatMobility * 5);
  }
}

// Usage example in your game controller:
// final hardAI = GoatAIHardMode(searchDepth: 3);
// Move aiMove = hardAI.getBestMove(board, isPlacementPhase);
// applyMove(aiMove);