// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/date_time_input.dart';
import 'package:jaspr_test/jaspr_test.dart';

import '../support/harness.dart';
import '../support/render.dart';

Future<String> renderDateTimeInput(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) async => normalizeHtml(
  await renderSurface(
    components,
    data: data,
    catalog: MinimalJasprCatalog().copyWith(
      add: [const DateTimeInputComponent()],
    ),
  ),
);

void main() {
  group('DateTimeInput', () {
    test('wraps a date input in its label', () async {
      final html = await renderDateTimeInput([
        {
          'id': 'root',
          'component': 'DateTimeInput',
          'label': 'Birthday',
          'variant': 'date',
          'value': '2024-01-01',
        },
      ]);

      expect(
        html,
        '<label class="a2ui-date-time-input">'
        '<span class="a2ui-date-time-input__label">Birthday</span>'
        '<input class="a2ui-date-time-input__input" type="date" value="2024-01-01"/>'
        '</label>',
      );
    });

    test('renders with no label when none is given', () async {
      final html = await renderDateTimeInput([
        {'id': 'root', 'component': 'DateTimeInput', 'value': ''},
      ]);

      expect(html, isNot(contains('a2ui-date-time-input__label')));
    });

    test('defaults to a combined date and time picker', () async {
      final html = await renderDateTimeInput([
        {
          'id': 'root',
          'component': 'DateTimeInput',
          'label': 'When',
          'value': '',
        },
      ]);

      expect(html, contains('type="datetime-local"'));
    });

    test(
      'asks the browser for the picker that matches the variant',
      () async {
        for (final (variant, type) in const [
          ('date', 'date'),
          ('time', 'time'),
          ('datetime', 'datetime-local'),
        ]) {
          final html = await renderDateTimeInput([
            {
              'id': 'root',
              'component': 'DateTimeInput',
              'label': 'When',
              'variant': variant,
              'value': '',
            },
          ]);

          expect(html, contains('type="$type"'), reason: 'variant $variant');
        }
      },
    );

    test('carries min and max to the browser for every variant', () async {
      for (final variant in const ['date', 'time', 'datetime']) {
        final html = await renderDateTimeInput([
          {
            'id': 'root',
            'component': 'DateTimeInput',
            'label': 'When',
            'variant': variant,
            'value': '',
            'min': '2020-01-01',
            'max': '2030-01-01',
          },
        ]);

        expect(html, contains('min="2020-01-01"'), reason: 'variant $variant');
        expect(html, contains('max="2030-01-01"'), reason: 'variant $variant');
      }
    });

    test('shows the message for a failing check', () async {
      final html = await renderDateTimeInput(
        [
          {
            'id': 'root',
            'component': 'DateTimeInput',
            'label': 'When',
            'value': '',
            'checks': [
              {
                'condition': {'path': '/ok'},
                'message': 'Pick a date',
              },
            ],
          },
        ],
        data: {'/ok': false},
      );

      expect(
        html,
        contains('class="a2ui-date-time-input a2ui-date-time-input--invalid"'),
      );
      expect(
        html,
        contains(
          '<small class="a2ui-date-time-input__error">Pick a date</small>',
        ),
      );
    });

    test('shows no message while its checks pass', () async {
      final html = await renderDateTimeInput(
        [
          {
            'id': 'root',
            'component': 'DateTimeInput',
            'label': 'When',
            'value': '',
            'checks': [
              {
                'condition': {'path': '/ok'},
                'message': 'Pick a date',
              },
            ],
          },
        ],
        data: {'/ok': true},
      );

      expect(html, isNot(contains('a2ui-date-time-input--invalid')));
      expect(html, isNot(contains('a2ui-date-time-input__error')));
    });

    test('shows the value bound from the data model', () async {
      final html = await renderDateTimeInput(
        [
          {
            'id': 'root',
            'component': 'DateTimeInput',
            'label': 'Birthday',
            'variant': 'date',
            'value': {'path': '/birthday'},
          },
        ],
        data: {'/birthday': '2024-01-01'},
      );

      expect(html, contains('value="2024-01-01"'));
    });

    group('write-back', () {
      testComponents('a bound value writes through to the model', (
        tester,
      ) async {
        final captured = await captureScope(
          tester,
          const DateTimeInputComponent(),
          [
            {
              'id': 'root',
              'component': 'DateTimeInput',
              'label': 'Birthday',
              'value': {'path': '/birthday'},
            },
          ],
          data: {'/birthday': '2024-01-01'},
        );

        expect(captured.scope.string('value'), '2024-01-01');

        final write = captured.scope.setter('value');
        expect(write, isNotNull);

        write!('2024-06-15');
        await tester.pump();

        expect(captured.surface.dataModel.get('/birthday'), '2024-06-15');
      });

      testComponents('a literal value provides no setter', (tester) async {
        final captured = await captureScope(
          tester,
          const DateTimeInputComponent(),
          [
            {
              'id': 'root',
              'component': 'DateTimeInput',
              'label': 'Birthday',
              'value': '2024-01-01',
            },
          ],
        );

        expect(captured.scope.setter('value'), isNull);
      });
    });
  });
}
