import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiger_trap/widgets/custom_widgets.dart';
import '../constants.dart';
import 'game_mode_screen.dart';
import 'rules_screen.dart';
import 'package:provider/provider.dart';
import '../providers/background_audio_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/image.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCosmicLogo(),
                  const SizedBox(height: 40),
                  Card(
                    color: Colors.black.withAlpha((0.5 * 255).toInt()),
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CosmicButton(
                            text: 'New Game',
                            icon: Icons.play_circle_filled_rounded,
                            onPressed:
                                () => _navigateTo(context, const GameModeScreen()),
                          ),
                          const SizedBox(height: 20),
                          CosmicButton(
                            text: 'How to Play',
                            icon: Icons.menu_book_rounded,
                            onPressed:
                                () => _navigateTo(context, const RulesScreen()),
                          ),
                          const SizedBox(height: 20),
                          Selector<BackgroundAudioProvider, bool>(
                            selector: (_, audio) => audio.isPlaying,
                            builder: (context, isPlaying, _) => CosmicButton(
                              text: isPlaying ? 'Play Music' : 'Music Off',
                              icon: isPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                              onPressed: () => context.read<BackgroundAudioProvider>().toggle(),
                              isActive: isPlaying,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
           
          ],
        ),
      ),
    );
  }

  Widget _buildCosmicLogo() {
    return StellarPanel(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.stellarGold, AppColors.nebulaTeal],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.stellarGold.withAlpha((0.4 * 255).toInt()),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/1024.png',
                  width: 80,
                  height: 80,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'TIGER TRAP',
            style: GoogleFonts.orbitron(
              color: AppColors.stellarGold,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}
