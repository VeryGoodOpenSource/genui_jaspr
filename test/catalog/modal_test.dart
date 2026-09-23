// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/modal.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../support/basic_catalog_fixtures.dart';
import '../support/harness.dart';
import '../support/render.dart';

void main() {
  group('Modal', () {
    test('exposes the A2UI v0.9 API', () {
      const component = ModalComponent();

      expect(component.name, 'Modal');
      expect(
        component.schema.value,
        Schema.object(
          properties: {
            'trigger': CommonSchemas.componentId,
            'content': CommonSchemas.componentId,
          },
          required: ['trigger', 'content'],
        ).value,
      );
    });

    test('initially renders its trigger beside a closed dialog', () async {
      final html = normalizeHtml(
        await renderSurface(
          modalFixtureComponents(),
          catalog: MinimalJasprCatalog().copyWith(
            add: [const ModalComponent()],
          ),
        ),
      );

      expect(
        html,
        '<div class="a2ui-modal">'
        '<div class="a2ui-modal__trigger">'
        '<button class="a2ui-button a2ui-button--primary" type="button">'
        '<p class="a2ui-text a2ui-text--body">Open details</p>'
        '</button>'
        '</div>'
        '<dialog id="main:root-dialog" class="a2ui-modal__dialog">'
        '<button class="a2ui-modal__close" aria-label="Close dialog" '
        'type="button">Close</button>'
        '<div class="a2ui-modal__content">'
        '<p class="a2ui-text a2ui-text--body">Hidden details</p>'
        '</div>'
        '</dialog>'
        '</div>',
      );
    });

    testComponents('keeps the trigger button action intact', (tester) async {
      final actions = <A2uiClientAction>[];
      final surface = buildSurfaceModel(
        modalFixtureComponents(),
        onAction: actions.add,
        catalog: MinimalJasprCatalog().copyWith(add: [const ModalComponent()]),
      );

      tester.pumpComponent(surfaceComponent(surface));
      await tester.click(find.tag('button').first);

      expect(actions.map((action) => action.name), ['opened']);
    });
  });
}
