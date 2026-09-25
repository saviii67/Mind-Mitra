import 'package:flutter/material.dart';

/// Standard rounded card used across MindMitra screens.
class MindCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const MindCard({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}