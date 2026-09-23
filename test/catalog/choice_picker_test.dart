// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/choice_picker.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../support/harness.dart';
import '../support/render.dart';

/// A function that computes a list of options, for a model that sends
/// `options` as a function call.
class _PrimaryColoursFunction extends FunctionImplementation {
  @override
  String get name => 'primaryColours';

  @override
  A2uiReturnType get returnType => A2uiReturnType.array;

  @override
  Schema get argumentSchema => Schema.object();

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) => [
    {'label': 'Red', 'value': 'red'},
    {'label': 'Blue', 'value': 'blue'},
  ];
}

final Catalog<JasprComponent> _catalog = MinimalJasprCatalog().copyWith(
  add: [ChoicePickerComponent()],
  addFunctions: [_PrimaryColoursFunction()],
);

Future<String> renderChoicePicker(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) async => normalizeHtml(
  await renderSurface(components, data: data, catalog: _catalog),
);

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
  group('ChoicePicker', () {
    group('mutuallyExclusive', () {
      test('renders a radio input per option', () async {
        final html = await renderChoicePicker(
          pickerSurface({
            'label': 'Colour',
            'variant': 'mutuallyExclusive',
            'value': 'blue',
          }),
        );

        expect(
          html,
          '<fieldset class="a2ui-choice-picker">'
          '<legend class="a2ui-choice-picker__label">Colour</legend>'
          '<label class="a2ui-choice-picker__option">'
          '<input class="a2ui-choice-picker__input" type="radio" name="main:root"/>'
          '<span class="a2ui-choice-picker__option-label">Red</span>'
          '</label>'
          '<label class="a2ui-choice-picker__option">'
          '<input class="a2ui-choice-picker__input" type="radio" name="main:root" checked/>'
          '<span class="a2ui-choice-picker__option-label">Blue</span>'
          '</label>'
          '</fieldset>',
        );
      });

      test('gives each templated row its own radio group', () async {
        final html = await renderChoicePicker(
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': {'componentId': 'picker', 'path': '/rows'},
            },
            {
              'id': 'picker',
              'component': 'ChoicePicker',
              'variant': 'mutuallyExclusive',
              'options': [
                {'label': 'Red', 'value': 'red'},
              ],
              'value': 'red',
            },
          ],
          data: {
            '/rows': ['a', 'b'],
          },
        );

        expect(html, contains('name="main:picker:%2Frows%2F0"'));
        expect(html, contains('name="main:picker:%2Frows%2F1"'));
      });

      test('checks none of them when the value matches no option', () async {
        final html = await renderChoicePicker(
          pickerSurface({'variant': 'mutuallyExclusive', 'value': 'green'}),
        );

        expect(html, isNot(contains('checked')));
      });

      test('shows the message for a failing check', () async {
        final html = await renderChoicePicker(
          pickerSurface({
            'variant': 'mutuallyExclusive',
            'value': 'red',
            'checks': [
              {
                'condition': {'path': '/ok'},
                'message': 'Pick one',
              },
            ],
          }),
          data: {'/ok': false},
        );

        expect(
          html,
          contains('class="a2ui-choice-picker a2ui-choice-picker--invalid"'),
        );
        expect(
          html,
          contains('<small class="a2ui-choice-picker__error">Pick one</small>'),
        );
      });
    });

    group('multipleSelection', () {
      test('renders a checkbox input per option', () async {
        final html = await renderChoicePicker(
          pickerSurface({
            'variant': 'multipleSelection',
            'value': ['red'],
          }),
        );

        expect(
          html,
          contains(
            '<input class="a2ui-choice-picker__input" type="checkbox" checked/>'
            '<span class="a2ui-choice-picker__option-label">Red</span>',
          ),
        );
        expect(
          html,
          contains(
            '<input class="a2ui-choice-picker__input" type="checkbox"/>'
            '<span class="a2ui-choice-picker__option-label">Blue</span>',
          ),
        );
      });

      test('is the default when no variant is given', () async {
        // Matches the A2UI reference implementation: an omitted variant
        // means multipleSelection, not mutuallyExclusive.
        final html = await renderChoicePicker(
          pickerSurface({'value': <String>[]}),
        );

        expect(html, contains('type="checkbox"'));
        expect(html, isNot(contains('type="radio"')));
      });

      test('checks the matching option when the value is a scalar', () async {
        // The schema admits a plain string for `value` regardless of variant,
        // so a scalar under multipleSelection must render, not crash.
        final html = await renderChoicePicker(
          pickerSurface({'variant': 'multipleSelection', 'value': 'red'}),
        );

        expect(
          html,
          contains(
            '<input class="a2ui-choice-picker__input" type="checkbox" checked/>'
            '<span class="a2ui-choice-picker__option-label">Red</span>',
          ),
        );
      });

      test('shows the message for a failing check', () async {
        final html = await renderChoicePicker(
          pickerSurface({
            'variant': 'multipleSelection',
            'value': ['red'],
            'checks': [
              {
                'condition': {'path': '/ok'},
                'message': 'Pick at least one',
              },
            ],
          }),
          data: {'/ok': false},
        );

        expect(
          html,
          contains('class="a2ui-choice-picker a2ui-choice-picker--invalid"'),
        );
        expect(
          html,
          contains(
            '<small class="a2ui-choice-picker__error">Pick at least one</small>',
          ),
        );
      });
    });

    group('options', () {
      test("resolves each literal option's own bound label", () async {
        final html = await renderChoicePicker(
          [
            {
              'id': 'root',
              'component': 'ChoicePicker',
              'options': [
                {
                  'label': {'path': '/redLabel'},
                  'value': 'red',
                },
              ],
              'value': 'red',
            },
          ],
          data: {'/redLabel': 'Crimson'},
        );

        expect(
          html,
          contains(
            '<span class="a2ui-choice-picker__option-label">Crimson</span>',
          ),
        );
      });

      test('renders options bound to a data-model path', () async {
        final html = await renderChoicePicker(
          [
            {
              'id': 'root',
              'component': 'ChoicePicker',
              'options': {'path': '/opts'},
              'value': 'blue',
            },
          ],
          data: {
            '/opts': [
              {'label': 'Red', 'value': 'red'},
              {'label': 'Blue', 'value': 'blue'},
            ],
          },
        );

        expect(
          html,
          '<fieldset class="a2ui-choice-picker">'
          '<label class="a2ui-choice-picker__option">'
          '<input class="a2ui-choice-picker__input" type="checkbox"/>'
          '<span class="a2ui-choice-picker__option-label">Red</span>'
          '</label>'
          '<label class="a2ui-choice-picker__option">'
          '<input class="a2ui-choice-picker__input" type="checkbox" checked/>'
          '<span class="a2ui-choice-picker__option-label">Blue</span>'
          '</label>'
          '</fieldset>',
        );
      });

      test('skips bound entries that are not options', () async {
        final html = await renderChoicePicker(
          [
            {
              'id': 'root',
              'component': 'ChoicePicker',
              'options': {'path': '/opts'},
              'value': 'red',
            },
          ],
          data: {
            '/opts': [
              'red',
              {'label': 'Blue', 'value': 'blue'},
            ],
          },
        );

        expect(html, contains('>Blue<'));
        expect(html, isNot(contains('>red<')));
      });

      test('renders no options while a bound path holds nothing', () async {
        final html = await renderChoicePicker([
          {
            'id': 'root',
            'component': 'ChoicePicker',
            'options': {'path': '/opts'},
            'value': 'red',
          },
        ]);

        expect(html, '<fieldset class="a2ui-choice-picker"></fieldset>');
      });

      testComponents('follows bound options when the data changes', (
        tester,
      ) async {
        final surface = buildSurfaceModel(
          [
            {
              'id': 'root',
              'component': 'ChoicePicker',
              'options': {'path': '/opts'},
              'value': 'red',
            },
          ],
          data: {
            '/opts': [
              {'label': 'Red', 'value': 'red'},
            ],
          },
          catalog: _catalog,
        );
        tester.pumpComponent(surfaceComponent(surface));
        await tester.pump();

        expect(find.text('Green'), findsNothing);

        surface.dataModel.set('/opts', [
          {'label': 'Red', 'value': 'red'},
          {'label': 'Green', 'value': 'green'},
        ]);
        await tester.pump();

        expect(find.text('Green'), findsOneComponent);
      });

      test('renders options computed by a function call', () async {
        final html = await renderChoicePicker([
          {
            'id': 'root',
            'component': 'ChoicePicker',
            'options': {
              'call': 'primaryColours',
              'args': <String, Object?>{},
            },
            'value': 'red',
          },
        ]);

        expect(
          html,
          contains('<span class="a2ui-choice-picker__option-label">Red</span>'),
        );
        expect(
          html,
          contains(
            '<span class="a2ui-choice-picker__option-label">Blue</span>',
          ),
        );
      });
    });

    test('renders an empty label rather than the text "null"', () async {
      final html = await renderChoicePicker([
        {
          'id': 'root',
          'component': 'ChoicePicker',
          'options': [
            {'value': 'red'},
          ],
          'value': 'red',
        },
      ]);

      expect(
        html,
        contains('<span class="a2ui-choice-picker__option-label"></span>'),
      );
      expect(html, isNot(contains('>null<')));
    });

    test('checks the matching option when the value is a list', () async {
      // The reference implementation's own example data sends a
      // single-element list even under mutuallyExclusive.
      final html = await renderChoicePicker(
        pickerSurface({
          'variant': 'mutuallyExclusive',
          'value': ['blue'],
        }),
      );

      expect(
        html,
        contains(
          '<input class="a2ui-choice-picker__input" type="radio" name="main:root" checked/>'
          '<span class="a2ui-choice-picker__option-label">Blue</span>',
        ),
      );
    });

    test('shows no message while its checks pass', () async {
      final html = await renderChoicePicker(
        pickerSurface({
          'value': 'red',
          'checks': [
            {
              'condition': {'path': '/ok'},
              'message': 'Pick one',
            },
          ],
        }),
        data: {'/ok': true},
      );

      expect(html, isNot(contains('a2ui-choice-picker--invalid')));
      expect(html, isNot(contains('a2ui-choice-picker__error')));
    });

    test('renders with no legend when no label is given', () async {
      final html = await renderChoicePicker(
        pickerSurface({'value': 'red'}),
      );

      expect(html, isNot(contains('a2ui-choice-picker__label')));
    });

    group('write-back', () {
      testComponents(
        'selecting an option writes its value through, mutually exclusive',
        (tester) async {
          final captured = await captureScope(
            tester,
            ChoicePickerApi(),
            pickerSurface({
              'variant': 'mutuallyExclusive',
              'value': {'path': '/colour'},
            }),
            data: {'/colour': 'red'},
          );

          expect(captured.scope.props['value'], 'red');

          final write = captured.scope.setter('value');
          expect(write, isNotNull);

          write!('blue');
          await tester.pump();

          expect(captured.surface.dataModel.get('/colour'), 'blue');
        },
      );

      testComponents(
        'selecting options writes the list through, multiple selection',
        (tester) async {
          final captured = await captureScope(
            tester,
            ChoicePickerApi(),
            pickerSurface({
              'variant': 'multipleSelection',
              'value': {'path': '/colours'},
            }),
            data: {
              '/colours': ['red'],
            },
          );

          expect(captured.scope.props['value'], ['red']);

          final write = captured.scope.setter('value');
          expect(write, isNotNull);

          write!(['red', 'blue']);
          await tester.pump();

          expect(captured.surface.dataModel.get('/colours'), [
            'red',
            'blue',
          ]);
        },
      );

      testComponents('a literal value provides no setter', (tester) async {
        final captured = await captureScope(
          tester,
          ChoicePickerApi(),
          pickerSurface({'value': 'red'}),
        );

        expect(captured.scope.setter('value'), isNull);
      });
    });
  });
}
