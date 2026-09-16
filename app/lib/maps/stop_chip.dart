import 'package:flutter/material.dart';

const idleFill = Color(0xFFF7F4EE);
const idleStroke = Color(0xFF1F4B3A);
const activeFill = Color(0xFF1F4B3A);
const activeStroke = Color(0xFFE4C56A);
const idleText = Color(0xFF1F4B3A);
const activeText = Color(0xFFFFFFFF);

class StopChip extends StatelessWidget {
  const StopChip({
    super.key,
    required this.number,
    required this.active,
  });

  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 40.0 : 32.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? activeFill : idleFill,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? activeStroke : idleStroke,
          width: active ? 3 : 2,
        ),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: active ? activeText : idleText,
          fontWeight: FontWeight.w700,
          fontSize: number > 9 ? 12 : 14,
          height: 1,
        ),
      ),
    );
  }
}
