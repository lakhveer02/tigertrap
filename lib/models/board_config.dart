import 'piece.dart';

class BoardConfig {
  final List<Point> nodes;
  final List<Connection> connections;

  BoardConfig({required this.nodes, required this.connections});
}

class Connection {
  final Point from;
  final Point to;

  Connection(this.from, this.to);
}
