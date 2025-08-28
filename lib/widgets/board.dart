import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiger_trap/game/aadu_puli/aadu_puli_provider.dart';
import '../models/piece.dart' as piece;
import 'aadu_puli_board.dart' as aadu;
import '../constants.dart';
import '../logic/game_controller.dart';

class Board extends StatefulWidget {
  final List<List<piece.Point>> board;
  final List<piece.Point> validMoves;
  final piece.Point? selectedPiece;
  final Function(piece.Point) onTap;
  final BoardType? boardType;
  const Board({
    required this.board,
    required this.validMoves,
    required this.selectedPiece,
    required this.onTap,
    this.boardType,
    super.key,
  });

  @override
  State<Board> createState() => _BoardState();
}

final brown38 = Colors.brown.withAlpha((0.38 * 255).toInt());

class _BoardState extends State<Board> with TickerProviderStateMixin {
  AnimationController? _moveController;
  AnimationController? _captureController;
  Offset? _fromPos;
  Offset? _toPos;
  piece.Point? _movingTiger;
  piece.Point? _capturedGoat;
  bool _isAnimating = false;

  AnimationController? _bloodController;
  Offset? _bloodPos;
  bool _showBlood = false;

  @override
  void dispose() {
    _moveController?.dispose();
    _captureController?.dispose();
    _bloodController?.dispose();
    super.dispose();
  }

  void _showBloodEffect(Offset pos) {
    _bloodController?.dispose();
    _bloodController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    setState(() {
      _bloodPos = pos;
      _showBlood = true;
    });
    _bloodController!.forward().then((_) {
      setState(() {
        _showBlood = false;
      });
    });
  }

  void _onPieceTap(piece.Point point, double margin, double cellSize) async {
    if (_isAnimating) return;

    final isTigerJump =
        widget.selectedPiece?.type == piece.PieceType.tiger &&
        widget.validMoves.contains(point) &&
        !_areAdjacent(widget.selectedPiece!, point);

    if (isTigerJump) {
      setState(() {
        _isAnimating = true;
        _movingTiger = widget.selectedPiece;
        _fromPos = _getBoardPos(_movingTiger!, margin, cellSize);
        _toPos = _getBoardPos(point, margin, cellSize);
        _capturedGoat = _findCapturedGoat(widget.selectedPiece!, point);
      });

      _moveController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _captureController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );

      await _moveController!.forward();
      await _captureController!.forward();

      if (_capturedGoat != null) {
        final bloodPos = _getBoardPos(_capturedGoat!, margin, cellSize);
        _showBloodEffect(bloodPos);
      }

      setState(() {
        _isAnimating = false;
        _movingTiger = null;
        _capturedGoat = null;
      });

      widget.onTap(point);
    } else {
      widget.onTap(point);
    }
  }

  bool _areAdjacent(piece.Point a, piece.Point b) {
    return a.adjacentPoints.contains(b);
  }

  piece.Point? _findCapturedGoat(piece.Point from, piece.Point to) {
    for (final adj in from.adjacentPoints) {
      if (adj.type == piece.PieceType.goat && adj.adjacentPoints.contains(to)) {
        if ((adj.x == (from.x + to.x) ~/ 2) &&
            (adj.y == (from.y + to.y) ~/ 2)) {
          return adj;
        }
      }
    }
    return null;
  }

  Offset _getBoardPos(piece.Point point, double margin, double cellSize) {
    return Offset(margin + point.y * cellSize, margin + point.x * cellSize);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, controller, _) {
        final type = widget.boardType ?? controller.boardType;
        if (type == BoardType.square) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth;
              const margin = 20.0;
              final cellSize = (size - 2 * margin) / 4;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.black38, Colors.black38],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.stellarGold.withAlpha(
                        (0.1 * 255).toInt(),
                      ),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(size, size),
                      painter: _BoardPainter(),
                    ),
                    ...List.generate(5, (x) {
                      return List.generate(5, (y) {
                        final point = widget.board[x][y];
                        final pos = Offset(
                          margin + y * cellSize,
                          margin + x * cellSize,
                        );
                        if (_isAnimating &&
                            _movingTiger == point &&
                            _moveController != null) {
                          final animation = Tween<Offset>(
                            begin: _fromPos!,
                            end: _toPos!,
                          ).animate(_moveController!);
                          return AnimatedBuilder(
                            animation: _moveController!,
                            builder: (context, child) {
                              final animPos = animation.value;
                              return Positioned(
                                left: animPos.dx - 21,
                                top: animPos.dy - 21,
                                child: Image.asset(
                                  'assets/images/tiger.png',
                                  width: 42,
                                  height: 42,
                                ),
                              );
                            },
                          );
                        }
                        if (_isAnimating &&
                            _capturedGoat == point &&
                            _captureController != null) {
                          final animPos = Offset(
                            margin + point.y * cellSize,
                            margin + point.x * cellSize,
                          );
                          return Positioned(
                            left: animPos.dx - 21,
                            top: animPos.dy - 21,
                            child: FadeTransition(
                              opacity: Tween<double>(
                                begin: 1,
                                end: 0,
                              ).animate(_captureController!),
                              child: Image.asset(
                                'assets/images/goat.png',
                                width: 38,
                                height: 38,
                              ),
                            ),
                          );
                        }
                        return Positioned(
                          left: pos.dx - 20,
                          top: pos.dy - 20,
                          child: GestureDetector(
                            onTap: () => _onPieceTap(point, margin, cellSize),
                            child: _BuildPiece(
                              point: point,
                              cellSize: cellSize,
                              isSelected: widget.selectedPiece == point,
                              isValidMove: widget.validMoves.contains(point),
                            ),
                          ),
                        );
                      });
                    }).expand((e) => e),
                    if (_isAnimating && _captureController != null)
                      Positioned.fill(
                        child: Center(
                          child: FadeTransition(
                            opacity: Tween<double>(
                              begin: 1,
                              end: 0.2,
                            ).animate(_captureController!),
                            child: Image.asset(
                              'assets/images/tiger_jump_goat.png',
                              width: 180,
                              height: 180,
                            ),
                          ),
                        ),
                      ),
                    if (_showBlood &&
                        _bloodPos != null &&
                        _bloodController != null)
                      Positioned(
                        left: _bloodPos!.dx - 28,
                        top: _bloodPos!.dy - 28,
                        child: FadeTransition(
                          opacity: CurveTween(
                            curve: Curves.ease,
                          ).animate(_bloodController!),
                          child: Image.asset(
                            'assets/images/blood_effect.png',
                            width: 65,
                            height: 65,
                          ),
                        ),
                      ),
                    IgnorePointer(),
                  ],
                ),
              );
            },
          );
        } else {
          return Consumer<GameController>(
            builder: (context, gameController, _) {
              return Consumer<AaduPuliProvider>(
                builder: (context, aaduProvider, _) {
                  return aadu.AaduPuliBoard(
                    config: aaduProvider.config,
                    validMoves: aaduProvider.validMoves,
                    selectedPiece: aaduProvider.selectedPiece,
                    onTap: (point) {
                      if (gameController.gameMode == GameMode.pvc && 
                          gameController.isComputerTurn()) {
                        gameController.handlePointTap(point);
                      } else {
                        aaduProvider.handleTap(point);
                      }
                    },
                    gameMessage: aaduProvider.gameMessage,
                  );
                },
              );
            },
          );
        }
      },
    );
  }
}

class _BuildPiece extends StatelessWidget {
  final piece.Point point;
  final double cellSize;
  final bool isSelected;
  final bool isValidMove;

  const _BuildPiece({
    required this.point,
    required this.cellSize,
    required this.isSelected,
    required this.isValidMove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (point.type != piece.PieceType.empty)
            BoxShadow(
              color: Colors.black.withAlpha((0.3 * 255).toInt()),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          if (isSelected)
            BoxShadow(
              color: Colors.amber.withAlpha((0.6 * 255).toInt()),
              blurRadius: 15,
              spreadRadius: 3,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isValidMove)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    point.type == piece.PieceType.empty
                        ? Colors.green.withAlpha((0.4 * 255).toInt())
                        : Colors.red.withAlpha((0.4 * 255).toInt()),
                border: Border.all(
                  color:
                      point.type == piece.PieceType.empty
                          ? Colors.greenAccent
                          : Colors.redAccent,
                  width: 2,
                ),
              ),
            ),
          _PieceImage(point: point),
        ],
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  final piece.Point point;

  const _PieceImage({required this.point});

  @override
  Widget build(BuildContext context) {
    if (point.type == piece.PieceType.empty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child:
          point.type == piece.PieceType.tiger
              ? Image.asset(
                'assets/images/tiger.png',
                width: 36,
                height: 36,
                key: ValueKey('tiger-${point.x}-${point.y}'),
              )
              : Image.asset(
                'assets/images/goat.png',
                width: 38,
                height: 38,
                key: ValueKey('goat-${point.x}-${point.y}'),
              ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = AppColors.stellarGold.withAlpha((0.7 * 255).toInt())
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    const margin = 20.0;
    final cellSize = (size.width - 2 * margin) / 4;

    final borderPaint =
        Paint()
          ..color = AppColors.stellarGold
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(
        margin,
        margin,
        size.width - 2 * margin,
        size.height - 2 * margin,
      ),
      borderPaint,
    );

    for (int i = 0; i < 5; i++) {
      final y = margin + i * cellSize;
      canvas.drawLine(
        Offset(margin, y),
        Offset(size.width - margin, y),
        gridPaint,
      );
    }

    for (int i = 0; i < 5; i++) {
      final x = margin + i * cellSize;
      canvas.drawLine(
        Offset(x, margin),
        Offset(x, size.height - margin),
        gridPaint,
      );
    }

    for (int x = 0; x < 5; x++) {
      for (int y = 0; y < 5; y++) {
        final cx = margin + y * cellSize;
        final cy = margin + x * cellSize;

        if (x > 0 && y > 0 && (x % 2 == y % 2)) {
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx - cellSize, cy - cellSize),
            gridPaint,
          );
        }
        if (x > 0 && y < 4 && (x % 2 == y % 2)) {
          canvas.drawLine(
            Offset(cx, cy),
            Offset(cx + cellSize, cy - cellSize),
            gridPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
