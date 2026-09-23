@TestOn('browser')
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/choice_picker.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

/// The hop a VM test cannot reach: a real click on a real radio or checkbox
/// reaching the data model.
SurfaceModel<JasprComponent> surfaceWith(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
  String surfaceId = 'main',
}) {
  final catalog = MinimalJasprCatalog().copyWith(
    add: [const ChoicePickerComponent()],
  );
  final processor = MessageProcessor<JasprComponent>(catalogs: [catalog])
    ..processMessages([
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': surfaceId,
          'catalogId': catalog.id,
          'sendDataModel': true,
        },
      }),
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateComponents': {'surfaceId': surfaceId, 'components': components},
      }),
    ]);
  final surface = processor.groupModel.getSurface(surfaceId)!;
  data.forEach(surface.dataModel.set);
  return surface;
}

List<Map<String, dynamic>> pickerSurface(Map<String, dynamic> extra) => [
  {
    'id': 'root',
    'component': 'ChoicePicker',
    'options': [
      {'label': 'Red', 'value': 'red'},
      {'label': 'Blue', 'value': 'blue'},
    ],
    ...extra,
  },
];

void main() {
  group('ChoicePicker in a browser', () {
    testClient('picking a radio writes its value through', (tester) async {
      final surface = surfaceWith(
        pickerSurface({
          'variant': 'mutuallyExclusive',
          'value': {'path': '/colour'},
        }),
        data: {'/colour': 'red'},
      );

      tester.pumpComponent(Surface(surface: surface));

      await tester.click(find.tag('input').at(1));

      expect(surface.dataModel.get('/colour'), 'blue');
    });

    testClient(
      'picking a radio leaves a same-id picker on another surface alone',
      (tester) async {
        List<Map<String, dynamic>> picker() => pickerSurface({
          'variant': 'mutuallyExclusive',
          'value': {'path': '/colour'},
        });
        final left = surfaceWith(
          picker(),
          data: {'/colour': 'red'},
          surfaceId: 'left',
        );
        final right = surfaceWith(
          picker(),
          data: {'/colour': 'red'},
          surfaceId: 'right',
        );

        tester.pumpComponent(
          div([Surface(surface: left), Surface(surface: right)]),
        );

        await tester.click(find.tag('input').at(1));

        // Radios sharing a name form one group across the whole document, so
        // checking the left picker's Blue would silently uncheck the right
        // picker's Red without either data model hearing about it.
        final rightRed =
            web.document.querySelectorAll('input').item(2)!
                as web.HTMLInputElement;
        expect(left.dataModel.get('/colour'), 'blue');
        expect(right.dataModel.get('/colour'), 'red');
        expect(rightRed.checked, isTrue);
      },
    );

    testClient('checking a box adds its value to the list', (tester) async {
      final surface = surfaceWith(
        pickerSurface({
          'variant': 'multipleSelection',
          'value': {'path': '/colours'},
        }),
        data: {
          '/colours': ['red'],
        },
      );

      tester.pumpComponent(Surface(surface: surface));

      await tester.click(find.tag('input').at(1));

      expect(surface.dataModel.get('/colours'), ['red', 'blue']);
    });

    testClient('unchecking a box removes its value from the list', (
      tester,
    ) async {
      final surface = surfaceWith(
        pickerSurface({
          'variant': 'multipleSelection',
          'value': {'path': '/colours'},
        }),
        data: {
          '/colours': ['red', 'blue'],
        },
      );

      tester.pumpComponent(Surface(surface: surface));

      await tester.click(find.tag('input').at(0));

      expect(surface.dataModel.get('/colours'), ['blue']);
    });
  });
}
