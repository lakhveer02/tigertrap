import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/flame.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiger_trap/constants.dart';
import 'package:tiger_trap/game/aadu_puli/aadu_puli_provider.dart';
import 'logic/game_controller.dart';
import 'utils/board_utils.dart';
import 'screens/home_screen.dart';
import 'providers/background_audio_provider.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.images.prefix = '';

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BackgroundAudioProvider>(
          create: (_) => BackgroundAudioProvider(),
        ),
        ChangeNotifierProvider<GameController>(create: (_) => GameController()),
        ChangeNotifierProxyProvider<GameController, AaduPuliProvider>(
          create: (context) {
            final provider = AaduPuliProvider(BoardUtils.getAaduPuliConfig());
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final gameController = context.read<GameController>();
              provider.setGameController(gameController);
            });
            return provider;
          },
          update: (context, gameController, aaduPuliProvider) {
            if (aaduPuliProvider != null) {
              aaduPuliProvider.setGameController(gameController);
              if (gameController.boardType == BoardType.aaduPuli) {
                aaduPuliProvider.resetGame();
              }
            }
            return aaduPuliProvider ?? AaduPuliProvider(BoardUtils.getAaduPuliConfig());
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiger Trap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        textTheme: GoogleFonts.robotoCondensedTextTheme(
          Theme.of(context).textTheme,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}
