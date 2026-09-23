@TestOn('browser')
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/check_box.dart';
import 'package:jaspr_test/client_test.dart';

/// The hop a VM test cannot reach: a real click on a real checkbox reaching
/// the data model.
SurfaceModel<JasprComponent> surfaceWith(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) {
  final catalog = MinimalJasprCatalog().copyWith(
    add: [const CheckBoxComponent()],
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
  group('CheckBox in a browser', () {
    testClient('clicking writes through to the data model', (tester) async {
      final surface = surfaceWith(
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Subscribe',
            'value': {'path': '/subscribed'},
          },
        ],
        data: {'/subscribed': false},
      );

      tester.pumpComponent(Surface(surface: surface));

      await tester.click(find.tag('input'));

      expect(surface.dataModel.get('/subscribed'), true);
    });

    testClient('clicking again unchecks it', (tester) async {
      final surface = surfaceWith(
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Subscribe',
            'value': {'path': '/subscribed'},
          },
        ],
        data: {'/subscribed': true},
      );

      tester.pumpComponent(Surface(surface: surface));

      await tester.click(find.tag('input'));

      expect(surface.dataModel.get('/subscribed'), false);
    });
  });
}
