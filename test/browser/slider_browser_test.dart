@TestOn('browser')
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/slider.dart';
import 'package:jaspr_test/client_test.dart';

/// The hop a VM test cannot reach: a real input event on a real range input
/// reaching the data model.
SurfaceModel<JasprComponent> surfaceWith(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) {
  final catalog = MinimalJasprCatalog().copyWith(
    add: [const SliderComponent()],
  );
  final processor = MessageProcessor<JasprComponent>(catalogs: [catalog])
    ..processMessages([
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'main',
          'catalogId': catalog.id,
          'sendDataModel': true,
        },
      }),
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateComponents': {'surfaceId': 'main', 'components': components},
      }),
    ]);
  final surface = processor.groupModel.getSurface('main')!;
  data.forEach(surface.dataModel.set);
  return surface;
}

void main() {
  group('Slider in a browser', () {
    testClient('dragging writes the numeric value through', (tester) async {
      final surface = surfaceWith(
        [
          {
            'id': 'root',
            'component': 'Slider',
            'min': 0,
            'max': 10,
            'value': {'path': '/amount'},
          },
        ],
        data: {'/amount': 5},
      );

      tester.pumpComponent(Surface(surface: surface));

      await tester.input(find.tag('input'), value: '8');

      expect(surface.dataModel.get('/amount'), 8);
    });
  });
}
