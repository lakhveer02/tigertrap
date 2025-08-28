// ignore_for_file: unrelated_type_equality_checks, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiger_trap/widgets/aadu_puli_board.dart';
import 'package:tiger_trap/widgets/board.dart';
import 'package:tiger_trap/widgets/custom_widgets.dart';
import '../logic/game_controller.dart';
import '../models/aadu_puli_node.dart' as model_piece;
import '../constants.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, controller, _) {
        if (controller.gameMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showGameOverDialog(context, controller);
          });
        }
        return Scaffold(
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/tiger.png', width: 32, height: 32),
                const SizedBox(width: 8),
                Text(
                  'Tiger Trap',
                  style: GoogleFonts.lora(
                    color: Colors.amber.shade400,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(controller.isPaused ? Icons.play_arrow : Icons.pause),
                onPressed: () {
                  if (controller.isPaused) {
                    controller.resumeGame();
                  } else {
                    controller.pauseGame();
                  }
                },
                tooltip: controller.isPaused ? 'Resume Game' : 'Pause Game',
              ),
            ],
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF33691E),
                    Color(0xFF558B2F),
                    Color(0xFF1B5E20),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/jungle_bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Column(
                children: [
                  _buildScorePanel(context, controller),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 0.75,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [_buildGameBoard()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (controller.isPaused) _buildPauseMenu(context, controller),
            ],
          ),
        );
      },
    );
  }

  void _showGameOverDialog(BuildContext context, GameController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.cosmicBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.stellarGold, width: 2),
            ),
            title: Text(
              'Game Over',
              style: AppTextStyles.cosmicTitle(context),
              textAlign: TextAlign.center,
            ),
            content: Text(
              controller.gameMessage!,
              style: AppTextStyles.nebulaSubtitle(context),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                child: Text(
                  'Main Menu',
                  style: AppTextStyles.starText(
                    context,
                  ).copyWith(color: AppColors.nebulaTeal),
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stellarGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'New Game',
                  style: AppTextStyles.starText(
                    context,
                  ).copyWith(color: AppColors.deepSpace),
                ),
                onPressed: () {
                  controller.resetGame();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  Widget _buildPauseMenu(BuildContext context, GameController controller) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: StellarPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: AppTextStyles.cosmicTitle(context)),
              const SizedBox(height: 40),
              CosmicButton(
                text: 'Resume',
                icon: Icons.play_arrow_rounded,
                onPressed: controller.resumeGame,
              ),
              const SizedBox(height: 20),
              CosmicButton(
                text: 'Main Menu',
                icon: Icons.home_rounded,
                onPressed: () {
                  controller.resumeGame();
                  controller.resetGame();
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScorePanel(BuildContext context, GameController game) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
            children: [
              Expanded(
                flex: 1,
                child: _PlayerScoreColumn(
                  isComputer: game.gameMode == GameMode.pvc && game.tigerPlayer == PlayerType.computer,
                  playerLabel: game.gameMode == GameMode.pvc && game.tigerPlayer == PlayerType.computer ? 'Computer' : 'Player 1',
                  pieceLabel: 'Tiger',
                  imageAsset: 'assets/images/tiger.png',
                  count: game.capturedGoats,
                  color: Colors.amber.shade400,
                  isActive: game.currentTurn == model_piece.PieceType.tiger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _PlayerScoreColumn(
                  isComputer: false, // Always human for goat
                  playerLabel: 'Player 2',
                  pieceLabel: 'Goat',
                  imageAsset: 'assets/images/goat.png',
                  count:
                      game.boardType == BoardType.square
                          ? 20 - game.placedGoats
                          : 15 - game.placedGoats,
                  color: Colors.blueGrey.shade100,
                  isActive: game.currentTurn == model_piece.PieceType.goat,
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildGameBoard() {
    return Consumer<GameController>(
      builder: (context, controller, _) {
        if (controller.boardType == BoardType.square) {
          return Board(
            board: controller.board,
            validMoves: controller.validMoves,
            selectedPiece: controller.selectedPiece,
            onTap: controller.handlePointTap,
          );
        } else {
          return AaduPuliBoard(
            config: controller.boardConfig!,
            validMoves: controller.validMoves,
            selectedPiece: controller.selectedPiece,
            onTap: controller.handlePointTap,
            gameMessage: controller.gameMessage,
          );
        }
      },
    );
  }
}

class _PlayerScoreColumn extends StatelessWidget {
  final bool isComputer;
  final String playerLabel;
  final String pieceLabel;
  final String imageAsset;
  final int count;
  final Color color;
  final bool isActive;

  const _PlayerScoreColumn({
    required this.isComputer,
    required this.playerLabel,
    required this.pieceLabel,
    required this.imageAsset,
    required this.count,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playerLabel,
          style: AppTextStyles.starText(
            context,
          ).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Stack(
          children: [
            _PlayerScore(
              imageAsset: imageAsset,
              label: pieceLabel,
              count: count,
              color: color,
              isActive: isActive,
            ),
            if (isComputer)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.computer, color: Colors.blue, size: 16),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlayerScore extends StatelessWidget {
  final String imageAsset;
  final String label;
  final int count;
  final Color color;
  final bool isActive;

  const _PlayerScore({
    required this.imageAsset,
    required this.label,
    required this.count,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.amber : Colors.grey.shade700,
          width: 2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900.withAlpha((0.8 * 255).toInt()),
            Colors.grey.shade800.withAlpha((0.6 * 255).toInt()),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.3 * 255).toInt()),
            blurRadius: 12,
            offset: Offset(4, 4),
          ),
          if (isActive)
            BoxShadow(
              color: Colors.amber.withAlpha((0.2 * 255).toInt()),
              blurRadius: 20,
              spreadRadius: 4,
            ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(imageAsset, width: 32, height: 32),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.robotoCondensed(
                  color: color.withAlpha((0.8 * 255).toInt()),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count.toString(),
                style: GoogleFonts.playfairDisplay(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
