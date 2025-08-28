import 'package:flutter/material.dart';

enum PieceType { tiger, goat, empty }

class AaduPuliNode {
  final int index;
  final Offset position;
  PieceType type;
  final List<int> adjacent;

  AaduPuliNode({
    required this.index,
    required this.position,
    required this.type,
    required this.adjacent,
  });
}
