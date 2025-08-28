import 'package:flutter/material.dart';
import '../models/piece.dart';
import '../models/board_config.dart';

class BoardUtils {
  static BoardConfig getAaduPuliConfig() {
    final nodes = List.generate(
      23,
      (index) => Point(
        id: '$index',
        x: 0,
        y: 0,
        position: _getPositionForIndex(index),
        adjacentPoints: [],
      ),
    );

    final horizontalConnections = [
      [1,2], [2,3], [3,4], [4,5], [5,6],   
      [7,8], [8,9], [9,10], [10,11], [11,12],
      [13,14], [14,15], [15,16], [16,17], [17,18],
      [19,20], [20,21], [21,22],
    ];
    
    final verticalConnections = [
      [0,2], [2,8], [8,14], [14,19],
      [1,7], [7,13],
      [0,3], [3,9], [9,15], [15,20],
      [0,4], [4,10], [10,16], [16,21],
      [0,5], [5,11], [11,17], [17,22],
      [6,12], [12,18],
    ];

    final connections = [
      ...horizontalConnections,
      ...verticalConnections,
    ];

    for (final connection in connections) {
      final from = nodes[connection[0]];
      final to = nodes[connection[1]];
      if (!from.adjacentPoints.contains(to)) {
        from.adjacentPoints.add(to);
      }
      if (!to.adjacentPoints.contains(from)) {
        to.adjacentPoints.add(from);
      }
    }

    return BoardConfig(nodes: nodes, connections: _createConnections(nodes));
  }

  static Offset _getPositionForIndex(int index) {
    switch (index) {
      case 0: return Offset(0.5, 0.0);
      case 1: return Offset(0.0, 0.21);
      case 2: return Offset(0.35, 0.21);
      case 3: return Offset(0.45, 0.21);
      case 4: return Offset(0.55, 0.21);
      case 5: return Offset(0.65, 0.21);
      case 6: return Offset(1.0, 0.21);
      case 7: return Offset(0.0, 0.45);
      case 8: return Offset(0.235, 0.45);
      case 9: return Offset(0.4, 0.45);
      case 10: return Offset(0.6, 0.45);
      case 11: return Offset(0.77, 0.45);
      case 12: return Offset(1.0, 0.45);
      case 13: return Offset(0.0, 0.7);
      case 14: return Offset(0.135, 0.7);
      case 15: return Offset(0.35, 0.7);
      case 16: return Offset(0.64, 0.7);
      case 17: return Offset(0.86, 0.7);
      case 18: return Offset(1.0, 0.7);
      case 19: return Offset(0.04, 1);
      case 20: return Offset(0.3, 1);
      case 21: return Offset(0.68, 1);
      case 22: return Offset(0.95, 1);
      default: return Offset(0, 0);
    }
  }

  static List<Connection> _createConnections(List<Point> nodes) {
    final connections = <Connection>[];
    final addedPairs = <String>{};
    for (final node in nodes) {
      for (final adjacent in node.adjacentPoints) {
        final pairKey = '${node.id}-${adjacent.id}';
        final reversePairKey = '${adjacent.id}-${node.id}';
        if (!addedPairs.contains(pairKey) && !addedPairs.contains(reversePairKey)) {
          connections.add(Connection(node, adjacent));
          addedPairs.add(pairKey);
        }
      }
    }
    return connections;
  } 
}
