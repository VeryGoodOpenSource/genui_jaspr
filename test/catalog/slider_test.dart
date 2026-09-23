// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/slider.dart';
import 'package:jaspr_test/jaspr_test.dart';

import '../support/harness.dart';
import '../support/render.dart';

Future<String> renderSlider(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) async => normalizeHtml(
  await renderSurface(
    components,
    data: data,
    catalog: MinimalJasprCatalog().copyWith(add: [const SliderComponent()]),
  ),
);

void main() {
  group('Slider', () {
    test('wraps a range input in its label', () async {
      final html = await renderSlider([
        {
          'id': 'root',
          'component': 'Slider',
          'label': 'Amount',
          'value': 0.5,
        },
      ]);

      expect(
        html,
        '<label class="a2ui-slider">'
        '<span class="a2ui-slider__label">Amount</span>'
        '<input class="a2ui-slider__input" min="0" max="1" type="range" value="0.5"/>'
        '</label>',
      );
    });

    test('renders with no label when none is given', () async {
      final html = await renderSlider([
        {'id': 'root', 'component': 'Slider', 'value': 0.5},
      ]);

      expect(html, isNot(contains('a2ui-slider__label')));
    });

    test('defaults its range to 0 through 1, per the spec', () async {
      final html = await renderSlider([
        {'id': 'root', 'component': 'Slider', 'value': 0.5},
      ]);

      expect(html, contains('min="0"'));
      expect(html, contains('max="1"'));
    });

    test('carries min and max to the browser', () async {
      final html = await renderSlider([
        {
          'id': 'root',
          'component': 'Slider',
          'value': 5,
          'min': 0,
          'max': 10,
        },
      ]);

      expect(html, contains('min="0"'));
      expect(html, contains('max="10"'));
    });

    test('shows the message for a failing check', () async {
      final html = await renderSlider(
        [
          {
            'id': 'root',
            'component': 'Slider',
            'value': 5,
            'checks': [
              {
                'condition': {'path': '/ok'},
                'message': 'Pick a valid amount',
              },
            ],
          },
        ],
        data: {'/ok': false},
      );

      expect(html, contains('class="a2ui-slider a2ui-slider--invalid"'));
      expect(
        html,
        contains(
          '<small class="a2ui-slider__error">Pick a valid amount</small>',
        ),
      );
    });

    test('shows no message while its checks pass', () async {
      final html = await renderSlider(
        [
          {
            'id': 'root',
            'component': 'Slider',
            'value': 5,
            'checks': [
              {
                'condition': {'path': '/ok'},
                'message': 'Pick a valid amount',
              },
            ],
          },
        ],
        data: {'/ok': true},
      );

      expect(html, isNot(contains('a2ui-slider--invalid')));
      expect(html, isNot(contains('a2ui-slider__error')));
    });

    group('write-back', () {
      testComponents('a bound value writes through to the model', (
        tester,
      ) async {
        final captured = await captureScope(
          tester,
          const SliderComponent(),
          [
            {
              'id': 'root',
              'component': 'Slider',
              'value': {'path': '/amount'},
            },
          ],
          data: {'/amount': 5},
        );

        expect(captured.scope.props['value'], 5);

        final write = captured.scope.setter('value');
        expect(write, isNotNull);

        write!(8);
        await tester.pump();

        expect(captured.surface.dataModel.get('/amount'), 8);
      });

      testComponents('writes NaN as nothing, since JSON cannot carry it', (
        tester,
      ) async {
        final captured = await captureScope(
          tester,
          const SliderComponent(),
          [
            {
              'id': 'root',
              'component': 'Slider',
              'value': {'path': '/amount'},
            },
          ],
          data: {'/amount': 5},
        );

        captured.scope.setter('value')!(double.nan);

        expect(captured.surface.dataModel.get('/amount'), isNull);
      });

      testComponents('a literal value provides no setter', (tester) async {
        final captured = await captureScope(tester, const SliderComponent(), [
          {'id': 'root', 'component': 'Slider', 'value': 5},
        ]);

        expect(captured.scope.setter('value'), isNull);
      });
    });
  });
}
