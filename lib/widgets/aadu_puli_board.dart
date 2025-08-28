import 'package:flutter/material.dart';
import '../models/piece.dart' as piece;
import '../models/board_config.dart' as board;
import '../constants.dart';

class AaduPuliBoard extends StatefulWidget {
  final board.BoardConfig config;
  final List<piece.Point> validMoves;
  final piece.Point? selectedPiece;
  final Function(piece.Point) onTap;
  final String? gameMessage;

  const AaduPuliBoard({
    required this.config,
    required this.validMoves,
    required this.selectedPiece,
    required this.onTap,
    this.gameMessage,
    super.key,
  });

  @override
  State<AaduPuliBoard> createState() => _AaduPuliBoardState();
}

class _AaduPuliBoardState extends State<AaduPuliBoard> with TickerProviderStateMixin {
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

  void _onPieceTap(piece.Point point) async {
    if (_isAnimating) return; 

    final isTigerJump = widget.selectedPiece?.type == piece.PieceType.tiger &&
      widget.validMoves.contains(point) &&
      !_areAdjacent(widget.selectedPiece!, point);

    if (isTigerJump) {
      setState(() {
        _isAnimating = true;
        _movingTiger = widget.selectedPiece;
        _fromPos = widget.selectedPiece!.position!;
        _toPos = point.position!;
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

      if (_capturedGoat != null && _capturedGoat!.position != null) {
        // ignore: use_build_context_synchronously
        final size = context.size?.width ?? 300;
        const margin = 20.0;
        final boardWidth = size - 2 * margin;
        final boardHeight = size - 2 * margin;
        final bloodPos = Offset(
          margin + _capturedGoat!.position!.dx * boardWidth,
          margin + _capturedGoat!.position!.dy * boardHeight,
        );
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
        return adj;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        const margin = 20.0;
        final boardSize = size;
        final boardWidth = boardSize - 2 * margin;
        final boardHeight = boardSize - 2 * margin;

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.black38, Colors.black38],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.stellarGold.withAlpha((0.1 * 255).toInt()),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(boardSize, boardSize),
                  painter: _AaduPuliPainter(config: widget.config),
                ),
                ...widget.config.nodes.map((point) {
                  final pos = Offset(
                    margin + point.position!.dx * boardWidth,
                    margin + point.position!.dy * boardHeight,
                  );
                  if (_isAnimating && _movingTiger == point && _moveController != null) {
                    final animation = Tween<Offset>(
                      begin: _fromPos!,
                      end: _toPos!,
                    ).animate(_moveController!);
                    return AnimatedBuilder(
                      animation: _moveController!,
                      builder: (context, child) {
                        final animPos = Offset(
                          margin + animation.value.dx * boardWidth,
                          margin + animation.value.dy * boardHeight,
                        );
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
                  if (_isAnimating && _capturedGoat == point && _captureController != null) {
                    final animPos = Offset(
                      margin + point.position!.dx * boardWidth,
                      margin + point.position!.dy * boardHeight,
                    );
                    return Positioned(
                      left: animPos.dx - 21,
                      top: animPos.dy - 21,
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1, end: 0)
                            .animate(_captureController!),
                        child: Image.asset(
                          'assets/images/goat.png',
                          width: 38,
                          height: 38,
                        ),
                      ),
                    );
                  }
                  return Positioned(
                    left: pos.dx - 21,
                    top: pos.dy - 21,
                    child: GestureDetector(
                      onTap: () => _onPieceTap(point),
                      child: _BuildPiece(
                        point: point,
                        size: boardSize,
                        isSelected: widget.selectedPiece == point,
                        isValidMove: widget.validMoves.contains(point),
                      ),
                    ),
                  );
                }),
                if (_isAnimating && _captureController != null)
                  Positioned.fill(
                    child: Center(
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1, end: 0.2)
                            .animate(_captureController!),
                        child: Image.asset(
                          'assets/images/tiger_jump_goat.png',
                          width: 180,
                          height: 180,
                        ),
                      ),
                    ),
                  ),
                
                if (_showBlood && _bloodPos != null && _bloodController != null)
                  Positioned(
                    left: _bloodPos!.dx - 28,
                    top: _bloodPos!.dy - 28,
                    child: FadeTransition(
                      opacity: CurveTween(curve: Curves.easeInOut)
                          .animate(_bloodController!),
                      child: Image.asset(
                        'assets/images/blood_effect.png',
                        width: 65,
                        height: 65,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BuildPiece extends StatelessWidget {
  final piece.Point point;
  final double size;
  final bool isSelected;
  final bool isValidMove;

  const _BuildPiece({
    required this.point,
    required this.size,
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
          if (isSelected)
            BoxShadow(
              color: Colors.amber.withAlpha((0.6 * 255).toInt()),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          if (isValidMove)
            BoxShadow(
              color: Colors.green.withAlpha((0.4 * 255).toInt()),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isValidMove)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withAlpha((0.2 * 255).toInt()),
                border: Border.all(color: Colors.greenAccent, width: 2),
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
      child: point.type == piece.PieceType.tiger
          ? Image.asset(
              'assets/images/tiger.png',
              width: 32,
              height: 32,
              key: ValueKey('tiger-${point.id}'),
            )
          : Image.asset(
              'assets/images/goat.png',
              width: 38,
              height: 38,
              key: ValueKey('goat-${point.id}'),
            ),
    );
  }
}

class _AaduPuliPainter extends CustomPainter {
  final board.BoardConfig config;
  _AaduPuliPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 24.0;
    final boardWidth = size.width - 2 * padding;
    final boardHeight = size.height - 2 * padding;

    final linePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    for (final conn in config.connections) {
      final start = Offset(
        padding + conn.from.position!.dx * boardWidth,
        padding + conn.from.position!.dy * boardHeight,
      );
      final end = Offset(
        padding + conn.to.position!.dx * boardWidth,
        padding + conn.to.position!.dy * boardHeight,
      );
      canvas.drawLine(start, end, linePaint);
    }

    final nodePaint = Paint()..color = Colors.amber;
    for (final node in config.nodes) {
      final pos = Offset(
        padding + node.position!.dx * boardWidth,
        padding + node.position!.dy * boardHeight,
      );
      canvas.drawCircle(pos, 8, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
