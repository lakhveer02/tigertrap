import 'package:flutter/material.dart';

enum PieceType { goat, tiger, empty }

class Point {
  final int x;
  final int y;
  PieceType  type;
  List<Point> adjacentPoints;
  final String? id;
  final Offset? position;

  Point({
    required this.x,
    required this.y,
    this.type = PieceType.empty,
    List<Point>? adjacentPoints,
    this.id,
    this.position,
  }) : adjacentPoints = adjacentPoints ?? [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          x == other.x &&
          y == other.y &&
          (id ?? '') == (other.id ?? '');

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ (id ?? '').hashCode;
}
