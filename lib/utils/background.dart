import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image(
        image: AssetImage("assets/background.png"),
        fit: BoxFit.cover,
      ),
    );
  }
}
