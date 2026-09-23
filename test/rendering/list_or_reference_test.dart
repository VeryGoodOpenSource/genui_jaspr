import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A component whose `items` is either a literal list, each element carrying
/// its own bindable `label`, or a binding to a whole list in the data model.
///
/// The same shape as the reference implementation's `listOrReference`, which
/// is what `ChoicePicker`'s `options` uses.
class _ItemsApi extends ComponentApi {
  @override
  String get name => 'Items';

  @override
  Schema get schema => Schema.object(
    properties: {
      'items': Schema.combined(
        anyOf: [
          Schema.list(
            items: Schema.object(
              properties: {'label': CommonSchemas.dynamicString},
            ),
          ),
          CommonSchemas.dataBinding,
          CommonSchemas.functionCall,
        ],
      ),
    },
  );
}

/// A live `Items` surface that keeps the most recent scope its builder saw.
class _Harness {
  _Harness(List<Map<String, dynamic>> components, {Map<String, Object?>? data})
    : processor = MessageProcessor<JasprComponent>(
        catalogs: [
          Catalog<JasprComponent>(
            id: MinimalJasprCatalog.catalogId,
            components: [
              JasprComponent.inline(_ItemsApi(), (scope) {
                _latest = scope;
                return const Component.empty();
              }),
            ],
          ),
        ],
      ) {
    processor.processMessages([
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'main',
          'catalogId': MinimalJasprCatalog.catalogId,
        },
      }),
      _update(components),
    ]);
    data?.forEach(surface.dataModel.set);
  }

  final MessageProcessor<JasprComponent> processor;
  static late ComponentScope _latest;

  SurfaceModel<JasprComponent> get surface =>
      processor.groupModel.getSurface('main')!;

  /// Each resolved item's `label`, which is all these tests assert on. A bound
  /// label also brings a setter alongside it.
  List<Object?> get labels => [
    for (final item in _latest.props['items'] as List) (item as Map)['label'],
  ];

  void update(List<Map<String, dynamic>> components) =>
      processor.processMessages([_update(components)]);

  static A2uiMessage _update(List<Map<String, dynamic>> components) =>
      A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateComponents': {'surfaceId': 'main', 'components': components},
      });
}

List<Map<String, dynamic>> _items(Object? items) => [
  {'id': 'root', 'component': 'Items', 'items': items},
];

const List<Map<String, Object>> _literal = [
  {
    'label': {'path': '/first'},
  },
  {'label': 'Second'},
];

const Map<String, String> _bound = {'path': '/list'};

void main() {
  group('a list-or-binding property', () {
    testComponents("resolves a literal list's own nested bindings", (
      tester,
    ) async {
      final harness = _Harness(_items(_literal), data: {'/first': 'First'});
      tester.pumpComponent(Surface(surface: harness.surface));
      await tester.pump();

      expect(harness.labels, ['First', 'Second']);

      harness.surface.dataModel.set('/first', 'Renamed');
      await tester.pump();

      expect(harness.labels, ['Renamed', 'Second']);
    });

    testComponents('follows a whole list bound in the data model', (
      tester,
    ) async {
      final harness = _Harness(
        _items(_bound),
        data: {
          '/list': [
            {'label': 'A'},
          ],
        },
      );
      tester.pumpComponent(Surface(surface: harness.surface));
      await tester.pump();

      expect(harness.labels, ['A']);

      harness.surface.dataModel.set('/list', [
        {'label': 'A'},
        {'label': 'B'},
      ]);
      await tester.pump();

      expect(harness.labels, ['A', 'B']);
    });

    testComponents('rebinds when an update flips the value between shapes', (
      tester,
    ) async {
      final harness = _Harness(
        _items(_bound),
        data: {
          '/first': 'First',
          '/list': [
            {'label': 'Bound'},
          ],
        },
      );
      tester.pumpComponent(Surface(surface: harness.surface));
      await tester.pump();

      harness.update(_items(_literal));
      await tester.pump();

      expect(harness.labels, ['First', 'Second']);

      harness.update(_items(_bound));
      await tester.pump();

      expect(harness.labels, ['Bound']);
    });
  });
}
