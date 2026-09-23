import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/list.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

Future<String> renderList(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) => renderSurface(
  components,
  data: data,
  catalog: MinimalJasprCatalog().copyWith(add: [const ListComponent()]),
);

void main() {
  group('List', () {
    test('exposes the A2UI v0.9 API', () {
      const component = ListComponent();

      expect(component.name, 'List');
      expect(
        component.schema.value,
        Schema.object(
          properties: {
            'children': CommonSchemas.childList,
            'direction': Schema.string(
              enumValues: ['vertical', 'horizontal'],
            ),
            'align': Schema.string(
              enumValues: ['start', 'center', 'end', 'stretch'],
            ),
          },
          required: ['children'],
        ).value,
      );
    });

    test('renders a vertically scrolling list by default', () async {
      final html = await renderList([
        {
          'id': 'root',
          'component': 'List',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'first'},
        {'id': 'b', 'component': 'Text', 'text': 'second'},
      ]);

      expect(html, startsWith('<div class="a2ui-list"'));
      expect(html, contains('display: flex'));
      expect(html, contains('flex-direction: column'));
      expect(html, contains('align-items: stretch'));
      expect(html, contains('overflow-y: auto'));
      expect(html, isNot(contains('overflow-x')));
      expect(html.indexOf('first'), lessThan(html.indexOf('second')));
    });

    test('renders horizontally with the requested alignment', () async {
      final html = await renderList([
        {
          'id': 'root',
          'component': 'List',
          'children': <String>[],
          'direction': 'horizontal',
          'align': 'center',
        },
      ]);

      expect(html, contains('flex-direction: row'));
      expect(html, contains('align-items: center'));
      expect(html, contains('overflow-x: auto'));
      expect(html, isNot(contains('overflow-y')));
    });

    for (final align in const ['start', 'end', 'stretch']) {
      test('maps $align onto cross-axis alignment', () async {
        final html = await renderList([
          {
            'id': 'root',
            'component': 'List',
            'children': <String>[],
            'align': align,
          },
        ]);

        expect(html, contains('align-items: $align'));
      });
    }

    test('repeats a child template over data-model items', () async {
      final html = await renderList(
        [
          {
            'id': 'root',
            'component': 'List',
            'children': {'componentId': 'item', 'path': '/items'},
          },
          {
            'id': 'item',
            'component': 'Text',
            'text': {'path': 'label'},
          },
        ],
        data: {
          '/items': [
            {'label': 'one'},
            {'label': 'two'},
          ],
        },
      );

      expect(html, contains('>one</p>'));
      expect(html, contains('>two</p>'));
    });
  });
}
