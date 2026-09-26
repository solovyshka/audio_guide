import 'package:audio_guide/maps/map_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('map controls expose zoom and current-location actions',
      (tester) async {
    var zoom = 0;
    var located = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapControls(
            onZoomIn: () => zoom += 1,
            onZoomOut: () => zoom -= 1,
            onLocate: () async => located = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Приблизить'));
    await tester.tap(find.byTooltip('Отдалить'));
    await tester.tap(find.byTooltip('Моё местоположение'));
    await tester.pump();

    expect(zoom, 0);
    expect(located, isTrue);
  });
}
