import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

import '../support/harness.dart';

/// A button whose action calls a function the catalog does not have.
List<Map<String, dynamic>> brokenButton() => [
  {
    'id': 'root',
    'component': 'Button',
    'child': 'label',
    'action': {
      'functionCall': {'call': 'noSuchFunction', 'args': <String, Object?>{}},
    },
  },
  {'id': 'label', 'component': 'Text', 'text': 'Send'},
];

void main() {
  group('ComponentScope.action', () {
    testComponents('reports a failing action instead of throwing', (
      tester,
    ) async {
      final errors = <A2uiClientError>[];
      final surface = buildSurfaceModel(brokenButton());
      surface.onError.addListener(errors.add);

      tester.pumpComponent(surfaceComponent(surface));
      // A throw here would escape the click handler and fail the test.
      await tester.click(find.tag('button'));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single.surfaceId, 'main');
      expect(errors.single.code, 'INTERNAL_ERROR');
      expect(errors.single.message, contains('noSuchFunction'));
    });

    testComponents('is null for a property that is not an action', (
      tester,
    ) async {
      final captured = await captureScope(tester, MinimalTextApi(), [
        {'id': 'root', 'component': 'Text', 'text': 'hi'},
      ]);

      expect(captured.scope.action('text'), isNull);
    });
  });

  group('ComponentScope.reportError', () {
    testComponents('hands an error to the surface', (tester) async {
      final errors = <A2uiClientError>[];
      final captured = await captureScope(tester, MinimalTextApi(), [
        {'id': 'root', 'component': 'Text', 'text': 'hi'},
      ]);
      captured.surface.onError.addListener(errors.add);

      captured.scope.reportError(A2uiDataError('bad path', path: '/x'));

      expect(errors.single.code, 'DATA_ERROR');
      expect(errors.single.surfaceId, 'main');
      expect(errors.single.details, {'path': '/x'});
    });
  });

  group('ComponentScope.children', () {
    testComponents('reads the children property by default', (tester) async {
      final captured = await captureScope(tester, MinimalColumnApi(), [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
      ]);

      expect(captured.scope.children(), hasLength(2));
      expect(captured.scope.children('nothing'), isEmpty);
    });
  });

  group('ComponentScope.instanceId', () {
    testComponents('differs for the same id on two surfaces', (tester) async {
      final text = [
        {'id': 'root', 'component': 'Text', 'text': 'hi'},
      ];
      final scopes = await _scopesOf(tester, [
        ..._surface('left', text),
        ..._surface('right', text),
      ]);

      expect(scopes.map((scope) => scope.id), ['root', 'root']);
      expect(scopes.map((scope) => scope.instanceId), [
        'left:root',
        'right:root',
      ]);
    });

    testComponents('differs for each row of a templated list', (tester) async {
      final scopes = await _scopesOf(
        tester,
        _surface(
          'main',
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': {'componentId': 'row', 'path': '/rows'},
            },
            {'id': 'row', 'component': 'Text', 'text': 'hi'},
          ],
          data: {
            'rows': ['a', 'b'],
          },
        ),
      );

      expect(scopes.map((scope) => scope.id), ['row', 'row']);
      expect(scopes.map((scope) => scope.instanceId), [
        'main:row:%2Frows%2F0',
        'main:row:%2Frows%2F1',
      ]);
    });

    testComponents('keeps separators in ids from colliding', (tester) async {
      final scopes = await _scopesOf(tester, [
        ..._surface('a:b', [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['c'],
          },
          {'id': 'c', 'component': 'Text', 'text': 'hi'},
        ]),
        ..._surface('a', [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['b:c'],
          },
          {'id': 'b:c', 'component': 'Text', 'text': 'hi'},
        ]),
      ]);

      expect(scopes.map((scope) => scope.instanceId), ['a%3Ab:c', 'a:b%3Ac']);
    });
  });
}

/// Renders every surface [messages] creates, recording the scope each `Text`
/// builder is handed, so a test can compare instances of the same component.
Future<List<ComponentScope>> _scopesOf(
  ComponentTester tester,
  List<A2uiMessage> messages,
) async {
  final scopes = <ComponentScope>[];
  final catalog = MinimalJasprCatalog().copyWith(
    add: [
      JasprComponent.inline(MinimalTextApi(), (scope) {
        scopes.add(scope);
        return const Component.empty();
      }),
    ],
  );
  final processor = MessageProcessor<JasprComponent>(catalogs: [catalog])
    ..processMessages(messages);
  tester.pumpComponent(
    div([
      for (final surface in processor.groupModel.allSurfaces)
        Surface(surface: surface),
    ]),
  );
  await tester.pump();
  return scopes;
}

List<A2uiMessage> _surface(
  String surfaceId,
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) => [
  A2uiMessage.fromJson({
    'version': 'v0.9',
    'createSurface': {
      'surfaceId': surfaceId,
      'catalogId': MinimalJasprCatalog.catalogId,
    },
  }),
  A2uiMessage.fromJson({
    'version': 'v0.9',
    'updateComponents': {'surfaceId': surfaceId, 'components': components},
  }),
  if (data.isNotEmpty)
    A2uiMessage.fromJson({
      'version': 'v0.9',
      'updateDataModel': {'surfaceId': surfaceId, 'path': '/', 'value': data},
    }),
];
