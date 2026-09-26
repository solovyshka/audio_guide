import 'package:audio_guide/models/area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('country area reads the same dossier sections as a city', () {
    final area = AreaSummary.fromJson({
      'id': 'cyprus',
      'type': 'country',
      'title': 'Кипр',
      'center': {'lat': 35.0, 'lon': 33.2},
      'history': {
        'founded': 'неолит',
        'summary': 'Историческая справка',
        'events': [
          {'year': '1960', 'text': 'Независимость'},
        ],
      },
      'present': {
        'summary': 'Современная справка',
        'population': '923 381',
        'economy': 'Услуги',
      },
      'sights': [
        {
          'id': 'kourion',
          'name': 'Курион',
          'lat': 34.6656,
          'lon': 32.8857,
          'kind': 'sight',
          'summary': 'Античный город',
        },
      ],
      'nature': [],
      'culture': [],
      'leisure': [],
    });

    expect(area.history.events.single.year, '1960');
    expect(area.present.population, '923 381');
    expect(area.sights.single.id, 'kourion');
  });
}
