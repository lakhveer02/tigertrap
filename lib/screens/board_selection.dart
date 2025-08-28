import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../logic/game_controller.dart';
import 'game_screen.dart';

class BoardSelectionScreen extends StatelessWidget {
  final GameMode gameMode;

  const BoardSelectionScreen({required this.gameMode, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Board', style: AppTextStyles.cosmicTitle(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.spaceGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.spaceGradient),
        child: Center(
          child: Card(
            color: Colors.black.withAlpha((0.5 * 255).toInt()),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Image.asset(
                      'assets/images/square.png',
                      width: 40,
                      height: 40,
                    ),
                    title: Text(
                      'Square Board',
                      style: AppTextStyles.nebulaSubtitle(context),
                    ),
                    onTap: () {
                      context.read<GameController>().setBoardType(BoardType.square);
                      context.read<GameController>().setGameMode(
                        gameMode,
                        side: context.read<GameController>().playerSide,
                        diff: context.read<GameController>().difficulty,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                  ),
                  const Divider(height: 32, color: Colors.white24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Image.asset(
                      'assets/images/aaduaatam.png',
                      width: 40,
                      height: 40,
                    ),
                    title: Text(
                      'Aadu Puli Aatam',
                      style: AppTextStyles.nebulaSubtitle(context),
                    ),
                    onTap: () {
                      context.read<GameController>().setBoardType(BoardType.aaduPuli);
                      context.read<GameController>().setGameMode(
                        gameMode,
                        side: context.read<GameController>().playerSide,
                        diff: context.read<GameController>().difficulty,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
