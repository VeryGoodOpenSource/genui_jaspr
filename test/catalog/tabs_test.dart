// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/tabs.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../support/basic_catalog_fixtures.dart';
import '../support/harness.dart';
import '../support/render.dart';

Future<String> renderTabs({Map<String, Object?> data = const {}}) async =>
    normalizeHtml(
      await renderSurface(
        tabsFixtureComponents(firstTitle: {'path': '/firstTitle'}),
        data: data,
        catalog: MinimalJasprCatalog().copyWith(add: [TabsComponent()]),
      ),
    );

void main() {
  group('Tabs', () {
    test('exposes the A2UI v0.9 API', () {
      final api = TabsApi();

      expect(api.name, 'Tabs');
      expect(
        api.schema.value,
        Schema.object(
          properties: {
            'tabs': Schema.list(
              minItems: 1,
              items: Schema.object(
                properties: {
                  'title': CommonSchemas.dynamicString,
                  'child': CommonSchemas.componentId,
                },
                required: ['title', 'child'],
                additionalProperties: false,
              ),
            ),
          },
          required: ['tabs'],
        ).value,
      );
    });

    test(
      'selects the first tab and renders only its child initially',
      () async {
        expect(
          await renderTabs(data: {'/firstTitle': 'Overview'}),
          '<div class="a2ui-tabs">'
          '<div class="a2ui-tabs__list" role="tablist">'
          '<button id="main:root-tab-0" '
          'class="a2ui-tabs__tab a2ui-tabs__tab--selected" role="tab" '
          'aria-selected="true" aria-controls="main:root-panel-0" '
          'tabindex="0" type="button">Overview</button>'
          '<button id="main:root-tab-1" class="a2ui-tabs__tab" role="tab" '
          'aria-selected="false" aria-controls="main:root-panel-1" '
          'tabindex="-1" type="button">Second</button>'
          '</div>'
          '<div id="main:root-panel-0" class="a2ui-tabs__panel" '
          'role="tabpanel" aria-labelledby="main:root-tab-0">'
          '<p class="a2ui-text a2ui-text--body">First panel</p>'
          '</div>'
          '</div>',
        );
      },
    );

    testComponents('resets when an update removes the selected tab', (
      tester,
    ) async {
      final catalog = MinimalJasprCatalog().copyWith(add: [TabsComponent()]);
      final processor = MessageProcessor<JasprComponent>(catalogs: [catalog])
        ..processMessages([
          A2uiMessage.fromJson({
            'version': 'v0.9',
            'createSurface': {'surfaceId': 'main', 'catalogId': catalog.id},
          }),
          A2uiMessage.fromJson({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'main',
              'components': tabsFixtureComponents(),
            },
          }),
        ]);
      final surface = processor.groupModel.getSurface('main')!;
      tester.pumpComponent(surfaceComponent(surface));

      await tester.click(find.tag('button').at(1));
      expect(find.text('Second panel'), findsOneComponent);

      processor.processMessages([
        A2uiMessage.fromJson({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'main',
            'components': [
              {
                'id': 'root',
                'component': 'Tabs',
                'tabs': [
                  {'title': 'First', 'child': 'first'},
                ],
              },
            ],
          },
        }),
      ]);
      await tester.pump();

      expect(find.text('First panel'), findsOneComponent);
      expect(find.text('Second panel'), findsNothing);
    });
  });
}
