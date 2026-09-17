import 'package:flutter/material.dart';

class UserDot extends StatelessWidget {
  const UserDot({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A7DE1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}
