import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _idleFill = Color(0xFFF7F4EE);
const _idleStroke = Color(0xFF1F4B3A);
const _activeFill = Color(0xFF1F4B3A);
const _activeStroke = Color(0xFFE4C56A);
const _idleText = Color(0xFF1F4B3A);
const _activeText = Color(0xFFFFFFFF);

Future<ui.Image> paintStopMarker({
  required int number,
  required bool active,
  required double devicePixelRatio,
}) async {
  final logical = active ? 44.0 : 34.0;
  final size = (logical * devicePixelRatio).round().clamp(64, 256);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  final radius = size / 2 - devicePixelRatio;
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = active ? _activeFill : _idleFill
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = active ? _activeStroke : _idleStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = (active ? 3.2 : 2.2) * devicePixelRatio
      ..isAntiAlias = true,
  );
  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.center,
                fontWeight: FontWeight.w700,
                fontSize: size * (number > 9 ? 0.38 : 0.46),
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                color: active ? _activeText : _idleText,
                fontWeight: FontWeight.w700,
              ),
            )
            ..addText('$number'))
          .build()
        ..layout(ui.ParagraphConstraints(width: size.toDouble()));
  canvas.drawParagraph(
    paragraph,
    Offset(0, (size - paragraph.height) / 2),
  );
  final picture = recorder.endRecording();
  return picture.toImage(size, size);
}

Future<ui.Image> paintUserMarker({required double devicePixelRatio}) async {
  final size = (22 * devicePixelRatio).round().clamp(48, 128);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  canvas.drawCircle(
    center,
    size / 2 - devicePixelRatio,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );
  canvas.drawCircle(
    center,
    size / 2 - 3.2 * devicePixelRatio,
    Paint()
      ..color = const Color(0xFF2A7DE1)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );
  final picture = recorder.endRecording();
  return picture.toImage(size, size);
}
