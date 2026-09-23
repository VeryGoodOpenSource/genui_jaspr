// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/card.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/render.dart';

Future<String> renderCard(List<Map<String, dynamic>> components) async =>
    normalizeHtml(
      await renderSurface(
        components,
        catalog: MinimalJasprCatalog().copyWith(add: [const CardComponent()]),
      ),
    );

void main() {
  group('Card', () {
    test('exposes the A2UI v0.9 API', () {
      const component = CardComponent();

      expect(component.name, 'Card');
      expect(
        component.schema.value,
        Schema.object(
          properties: {'child': CommonSchemas.componentId},
          required: ['child'],
        ).value,
      );
    });

    test('renders its one child in a card container', () async {
      expect(
        await renderCard([
          {'id': 'root', 'component': 'Card', 'child': 'content'},
          {'id': 'content', 'component': 'Text', 'text': 'Inside'},
        ]),
        '<div class="a2ui-card">'
        '<p class="a2ui-text a2ui-text--body">Inside</p>'
        '</div>',
      );
    });
  });
}
