# Goat AI and Tiger AI Implementation

This document describes the implementation of the Goat AI and Tiger AI with three difficulty levels (Easy, Medium, Hard) as specified in the requirements.

## Overview

The AI system has been implemented using two main classes:
- `GoatAI` - Handles goat placement and movement
- `TigerAI` - Handles tiger movement

Both classes support three difficulty levels that match the specifications exactly.

## Goat AI Implementation

### Easy Mode
- **Placement**: Randomly places goats on available nodes
- **Movement**: Random legal move, without considering tiger threats
- **Weakness**: Often leaves goats exposed, doesn't block tiger jumps

### Medium Mode
- **Placement**: 
  - Prioritizes blocking tiger when directly threatened
  - Otherwise, places goats near tigers to limit mobility
- **Movement**:
  - Avoids moves that result in immediate capture
  - Tries to keep goats clustered
- **Weakness**: Still misses long-term traps, reacts only to local threats

### Hard Mode
- **Placement**:
  - Actively blocks potential tiger jumps
  - Places goats strategically to form "walls" and gradually trap tigers
- **Movement**:
  - Calculates 2–3 moves ahead (mini-max or heuristic scoring)
  - Keeps goats on key intersections to restrict tiger freedom
- **Strength**: Plays almost like a human expert — tough to beat

## Tiger AI Implementation

### Easy Mode
- **Movement**: Random legal move or random capture if available
- **Weakness**: Often wastes turns, misses capture opportunities

### Medium Mode
- **Movement**:
  - Always takes capture if possible
  - If no capture, moves closer to goats to increase pressure
  - Avoids getting stuck near corners (some basic positional awareness)
- **Weakness**: Doesn't plan traps well, can still be surrounded

### Hard Mode
- **Movement**:
  - Always takes the best capture (evaluates which move keeps mobility high)
  - Predicts goat blocking 2–3 moves ahead (minimax/heuristics)
  - Moves to the center when possible to maximize options
- **Strength**:
  - Rarely gets trapped
  - Can create situations where goats are forced into sacrifices

## Integration with Game Controller

The AI classes have been integrated into the `GameController` class:

### For Square Board:
```dart
void _makeSquareComputerMove() {
  if (currentTurn == PieceType.tiger) {
    // Use Tiger AI
    final move = TigerAI.moveTiger(board, boardConfig, boardType, difficulty);
    _executeMove(move['from']!, move['to']!);
  } else {
    // Use Goat AI for movement
    final move = GoatAI.moveGoat(board, boardConfig, boardType, difficulty);
    _executeMove(move['from']!, move['to']!);
  }
  // ... rest of the method
}
```

### For Goat Placement:
```dart
void _makeGoatComputerMove() {
  if (!isGoatMovementPhase) {
    // Use Goat AI for placement
    try {
      final placement = GoatAI.placeGoat(board, boardConfig, boardType, placedGoats, difficulty, unsafeMoveHistory);
      _placeGoat(placement);
    } catch (e) {
      // Fallback to existing AI
      _goatPlacementAI();
    }
  } else {
    // Use Goat AI for movement
    try {
      final move = GoatAI.moveGoat(board, boardConfig, boardType, difficulty);
      _executeMove(move['from']!, move['to']!);
      currentTurn = PieceType.tiger;
    } catch (e) {
      // Fallback to existing AI
      _goatMovementAI();
    }
  }
}
```

## Key Features

### Board Type Support
Both AI classes support both board types:
- Square Board (5x5 grid)
- Aadu Puli Board (custom node-based board)

### Difficulty-Based Behavior
Each difficulty level implements the exact behavior described in the requirements:

1. **Easy**: Basic random moves with minimal strategy
2. **Medium**: Reactive strategy with immediate threat detection
3. **Hard**: Proactive strategy with look-ahead planning

### Error Handling
The implementation includes fallback mechanisms:
- If the new AI fails, it falls back to the existing AI implementation
- Error logging for debugging
- Graceful degradation of AI performance

### Performance Considerations
- Minimax search is limited to depth 2-3 to maintain reasonable performance
- Heuristic evaluation functions are optimized for speed
- Board cloning is minimized where possible

## Usage

To use the new AI system:

1. Set the difficulty level in the game controller:
```dart
gameController.setGameMode(
  GameMode.pvc,
  side: PlayerSide.tiger, // or PlayerSide.goat
  diff: Difficulty.hard, // easy, medium, or hard
);
```

2. The AI will automatically use the appropriate difficulty level for both goats and tigers.

## Files Modified

- `lib/logic/game_controller.dart` - Updated to use new AI classes
- `lib/logic/goat_ai.dart` - New Goat AI implementation
- `lib/logic/tiger_ai.dart` - New Tiger AI implementation

## Testing

The AI implementation includes comprehensive evaluation functions for both board types and all difficulty levels. The system maintains backward compatibility by falling back to the existing AI implementation if any errors occur.