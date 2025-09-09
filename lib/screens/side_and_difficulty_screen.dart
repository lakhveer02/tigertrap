import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../logic/game_controller.dart';
import 'board_selection.dart';

class SideAndDifficultyScreen extends StatefulWidget {
  const SideAndDifficultyScreen({super.key});

  @override
  State<SideAndDifficultyScreen> createState() => _SideAndDifficultyScreenState();
}

class _SideAndDifficultyScreenState extends State<SideAndDifficultyScreen> {
  PlayerSide _selectedSide = PlayerSide.tiger; 
  Difficulty _selectedDifficulty = Difficulty.medium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Side & Difficulty', style: AppTextStyles.cosmicTitle(context)),
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
          child: SingleChildScrollView(
            child: Card(
              color: Colors.black.withAlpha((0.5 * 255).toInt()),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Choose Your Side:', style: AppTextStyles.nebulaSubtitle(context)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSideButton(PlayerSide.tiger, 'Tiger', 'assets/images/tiger.png'),
                        const SizedBox(width: 32),
                        _buildSideButton(PlayerSide.goat, 'Goat', 'assets/images/goat.png'),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Align(
                      alignment: Alignment.center,
                      child: Text('Select Difficulty:', style: AppTextStyles.nebulaSubtitle(context)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.3 * 255).toInt()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.stellarGold.withAlpha((0.3 * 255).toInt())),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Difficulty>(
                          dropdownColor: Colors.black87,
                          value: _selectedDifficulty,
                          isExpanded: true,
                          style: AppTextStyles.starText(context).copyWith(color: Colors.lightBlue),
                          items: [
                            DropdownMenuItem(value: Difficulty.easy, child: Text('Easy', style: TextStyle(color: Colors.lightBlue))),
                            DropdownMenuItem(value: Difficulty.medium, child: Text('Medium', style: TextStyle(color: Colors.lightBlue))),
                            DropdownMenuItem(value: Difficulty.hard, child: Text('Hard', style: TextStyle(color: Colors.lightBlue))),
                          ],
                          onChanged: (diff) {
                            if (diff != null) setState(() => _selectedDifficulty = diff);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                          backgroundColor: AppColors.cosmicBlue,
                          foregroundColor: Colors.black,
                          elevation: 4,
                        ),
                        onPressed: () {
                          context.read<GameController>().setGameMode(
                            GameMode.pvc,
                            side: _selectedSide,
                            diff: _selectedDifficulty,
                          );
                          context.read<GameController>().resetGame();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BoardSelectionScreen(gameMode: GameMode.pvc),
                            ),
                          );
                        },
                        child: Text('Continue', style: AppTextStyles.starText(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideButton(PlayerSide side, String label, String asset) {
    return GestureDetector(
      onTap: () => setState(() => _selectedSide = side),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedSide == side 
                  ? AppColors.stellarGold 
                  : Colors.transparent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(asset, width: 80, height: 80),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.starText(context)),
        ],
      ),
    );
  }
}