import 'package:flutter/material.dart';
import '../constants.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pagesData = [
    {
      'title': 'Tiger Trap Rules',
      'rules': [
        'Tigers start at the 4 corners',
        'Goats are placed one at a time (20 total)',
        'Tigers move first after each goat placement',
        'Tigers can capture goats by jumping over them',
        'In one Tiger turn, only one move or jump. Then turn switches to Goat.',
        'Goats win by blocking all tiger moves',
        'Tigers win by capturing 5 goats',
      ],
    },
    {
      'title': 'Aadu Puli Aatam Rules',
      'rules': [
        '3 Tigers vs 15 Goats',
        'Tigers start at the top 3 positions',
        'Goats are placed one at a time',
        'After placing all goats, they can move',
        'Tigers move first after each goat placement',
        'Tigers can capture goats by jumping over them',
        'In one Tiger turn, only one move or jump. Then turn switches to Goat.',
        'Goats win by blocking all tiger moves',
        'Tigers win by capturing 5 goats',
      ],
    },
    {
      'title': 'Tiger AI Rules',
      'rules': [
        'AI controls all 4 Tigers',
        'AI prioritizes capturing isolated goats',
        'AI avoids getting blocked by goat formations',
        'AI selects moves using difficulty-based strategy (Easy, Medium, Hard)',
      ],
    },
    {
      'title': 'Goat AI Rules',
      'rules': [
        'AI controls all 20 Goats and plays strategically in both placement and movement phases.',
        'During the placement phase, AI selects positions that prevent tiger jumps, focusing on blocking key paths without exposing goats to capture.',
        'After all goats are placed, AI actively moves goats to trap tigers and limit their mobility.',
        'AI avoids risky placements near jumpable positions early in the game and prioritizes forming blocking formations around tigers.',
        'AI adapts its strategy based on difficulty: higher levels use advanced prediction, coordination, and trap setups to increase chances of victory.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Rules', style: AppTextStyles.cosmicTitle(context)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.spaceGradient),
        ),
        foregroundColor: AppColors.starDust,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.spaceGradient),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pagesData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.haveDimensions) {
                        value = _pageController.page! - index;
                        value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
                      }
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY((_pageController.position.haveDimensions ? (_pageController.page! - index) : 0) * 0.8),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: value,
                          child: _buildBookPage(
                            title: _pagesData[index]['title'],
                            rules: List<String>.from(_pagesData[index]['rules']),
                          ),
                        ),
                      );
                    },
                  );
                },
                pageSnapping: true,
                physics: const BouncingScrollPhysics(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pagesData.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: _currentPage == index ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.stellarGold
                          : AppColors.starDust.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookPage({required String title, required List<String> rules}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: AppColors.panelDecoration.copyWith(
            color: Colors.black.withAlpha((0.7 * 255).toInt()),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cosmicTitle(context).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 12),
                ...rules.map((rule) => _buildRuleItem(context, rule)).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, color: AppColors.stellarGold, size: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.nebulaSubtitle(context)),
          ),
        ],
      ),
    );
  }
}
