import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/render.dart';

const standardIconNames = [
  'accountCircle',
  'add',
  'arrowBack',
  'arrowForward',
  'attachFile',
  'calendarToday',
  'call',
  'camera',
  'check',
  'close',
  'delete',
  'download',
  'edit',
  'event',
  'error',
  'fastForward',
  'favorite',
  'favoriteOff',
  'folder',
  'help',
  'home',
  'info',
  'locationOn',
  'lock',
  'lockOpen',
  'mail',
  'menu',
  'moreVert',
  'moreHoriz',
  'notificationsOff',
  'notifications',
  'pause',
  'payment',
  'person',
  'phone',
  'photo',
  'play',
  'print',
  'refresh',
  'rewind',
  'search',
  'send',
  'settings',
  'share',
  'shoppingCart',
  'skipNext',
  'skipPrevious',
  'star',
  'starHalf',
  'starOff',
  'stop',
  'upload',
  'visibility',
  'visibilityOff',
  'volumeDown',
  'volumeMute',
  'volumeOff',
  'volumeUp',
  'warning',
];

Future<String> renderIcon(
  Object name, {
  Map<String, Object?> data = const {},
}) async => normalizeHtml(
  await renderSurface(
    [
      {'id': 'root', 'component': 'Icon', 'name': name},
    ],
    data: data,
    catalog: MinimalJasprCatalog().copyWith(add: [const IconComponent()]),
  ),
);

void main() {
  group('Icon', () {
    test('exposes the pinned A2UI v0.9 API', () {
      const component = IconComponent();

      expect(component.name, 'Icon');
      expect(
        component.schema.value,
        Schema.object(
          properties: {
            'name': Schema.combined(
              oneOf: [
                Schema.string(enumValues: standardIconNames),
                CommonSchemas.dataBinding,
              ],
            ),
          },
          required: ['name'],
        ).value,
      );
    });

    test(
      'renders a standard name as an accessible-neutral inline SVG',
      () async {
        final html = await renderIcon('add');

        expect(html, startsWith('<svg class="a2ui-icon"'));
        expect(html, contains('viewBox="0 0 24 24"'));
        expect(html, contains('width="24px"'));
        expect(html, contains('height="24px"'));
        expect(html, contains('aria-hidden="true"'));
        expect(html, contains('fill="currentColor"'));
        expect(html, contains('d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"'));
      },
    );

    test('renders every standard icon name', () async {
      for (final name in standardIconNames) {
        final html = await renderIcon(name);
        final path = RegExp('<path[^>]+d="([^"]*)"').firstMatch(html);

        expect(path?.group(1), isNotEmpty, reason: name);
      }
    });

    test('reports and omits an unknown icon name', () async {
      final errors = <Object>[];
      final component = const IconComponent().build(
        ComponentScope(
          id: 'root',
          instanceId: 'main:root',
          type: 'Icon',
          props: const {'name': 'notAStandardIcon'},
          theme: const {},
          buildChild: (_) => const Component.empty(),
          buildChildren: (_) => const [],
          reportError: errors.add,
        ),
      );

      expect(await renderHtml(component), isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single, isA<ArgumentError>());
    });

    test('passes a bound name to a custom renderer', () async {
      final html = normalizeHtml(
        await renderSurface(
          [
            {
              'id': 'root',
              'component': 'Icon',
              'name': {'path': '/icon'},
            },
          ],
          data: {'/icon': 'home'},
          catalog: MinimalJasprCatalog().copyWith(
            add: [
              IconComponent.withRenderer(
                (name) => span([Component.text(name)], classes: 'custom-icon'),
              ),
            ],
          ),
        ),
      );

      expect(html, '<span class="custom-icon">home</span>');
    });

    test('reports a missing name before calling a custom renderer', () async {
      final errors = <Object>[];
      var rendererCalled = false;
      final component =
          IconComponent.withRenderer((name) {
            rendererCalled = true;
            return Component.text(name);
          }).build(
            ComponentScope(
              id: 'root',
              instanceId: 'main:root',
              type: 'Icon',
              props: const {},
              theme: const {},
              buildChild: (_) => const Component.empty(),
              buildChildren: (_) => const [],
              reportError: errors.add,
            ),
          );

      expect(await renderHtml(component), isEmpty);
      expect(rendererCalled, isFalse);
      expect(errors, hasLength(1));
      expect(errors.single, isA<ArgumentError>());
    });
  });
}
