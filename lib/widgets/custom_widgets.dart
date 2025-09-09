import 'package:flutter/material.dart';
import '../constants.dart';

class CosmicButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  const CosmicButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isActive ? [Colors.black38, Colors.black38] : [Colors.black54, Colors.black54],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.stellarGold.withAlpha(isActive ? (0.4 * 255).toInt() : (0.2 * 255).toInt()),
            blurRadius: isActive ? 15 : 8,
            spreadRadius: isActive ? 2 : 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.starDust, size: 28),
                const SizedBox(width: 16),
                Text(text, style: AppTextStyles.nebulaSubtitle(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StellarPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const StellarPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppColors.panelDecoration.copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black38, Colors.black54],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
