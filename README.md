# tiger_trap

A Flutter implementation of the classic Nepali board game Bagh-Chal (Tiger and Goats).

## Table of Contents
- [About](#about)
- [Features](#features)
- [Gameplay](#gameplay)
- [Folder Structure](#folder-structure)
- [How to Run the App](#how-to-run-the-app)
- [Getting Started](#getting-started)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## About
Bagh-Chal (meaning "Tiger's Move") is a traditional strategy board game from Nepal, played between two players: one controlling four tigers and the other controlling up to twenty goats. The goal for the tigers is to capture goats, while the goats aim to block the tigers' movements.

## Features
- Play as Tiger or Goat
- Single player (vs AI) and two player modes
- Multiple board configurations
- Interactive game board
- Rules and instructions screen
- Audio feedback
- Pause and resume functionality
- Board selection and difficulty settings

## Gameplay
- **Tigers**: Move along lines to adjacent points and can capture goats by jumping over them.
- **Goats**: Placed one at a time and can only move after all are placed. Goats cannot capture tigers.
- The game ends when all tigers are blocked or enough goats are captured.

## Folder Structure
```
lib/
  constants.dart
  main.dart
  controllers/
  game/
    aadu_puli/
      aadu_puli_provider.dart
  logic/
    aadu_puli_logic.dart
    game_controller.dart
    square_board_logic.dart
  models/
    aadu_puli_node.dart
    board_config.dart
    piece.dart
  providers/
    background_audio_provider.dart
  screens/
    board_selection.dart
    game_mode_screen.dart
    game_screen.dart
    home_screen.dart
    rules_screen.dart
    side_and_difficulty_screen.dart
  utils/
    board_utils.dart
  widgets/
    aadu_puli_board.dart
    board.dart
    custom_widgets.dart
```

## How to Run the App
1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd tiger_trap
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the app:**
   - For Android:
     ```bash
     flutter run
     ```
   - For iOS:
     ```bash
     flutter run
     ```
   - For Web:
     ```bash
     flutter run -d chrome
     ```

## Getting Started
A few resources to get you started if this is your first Flutter project:
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter documentation](https://docs.flutter.dev/)

## Contributing
Contributions are welcome! Please open issues or submit pull requests for improvements and bug fixes.

## License
This project is licensed under the MIT License.

## Contact
For questions or suggestions, please contact the maintainer at [lakh5939@gmail.com].
