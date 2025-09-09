import 'package:flutter/material.dart';
import '../constants.dart';
import '../logic/game_controller.dart';
import 'board_selection.dart'; 
import 'side_and_difficulty_screen.dart'; 

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.spaceGradient),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), 
        title: Text('Select Mode', style: AppTextStyles.cosmicTitle(context)),
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
                  _buildModeButton(context, 'Player vs Player', Icons.group, () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => BoardSelectionScreen(gameMode: GameMode.pvp),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  _buildModeButton(context, 'Player vs Computer', Icons.computer, () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SideAndDifficultyScreen(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          backgroundColor: AppColors.cosmicBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.stellarGold),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.stellarGold),
            const SizedBox(width: 12),
            Text(text, style: AppTextStyles.nebulaSubtitle(context)),
          ],
        ),
      ),
    );
  }
}
