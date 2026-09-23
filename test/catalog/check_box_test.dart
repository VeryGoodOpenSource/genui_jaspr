// The expected markup below is built from adjacent string literals joined
// with no space, so it matches the rendered HTML exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/check_box.dart';
import 'package:jaspr_test/jaspr_test.dart';

import '../support/harness.dart';
import '../support/render.dart';

Future<String> renderCheckBox(
  List<Map<String, dynamic>> components, {
  Map<String, Object?> data = const {},
}) async => normalizeHtml(
  await renderSurface(
    components,
    data: data,
    catalog: MinimalJasprCatalog().copyWith(add: [const CheckBoxComponent()]),
  ),
);

void main() {
  group('CheckBox', () {
    test('wraps a checkbox input in its label', () async {
      final html = await renderCheckBox([
        {'id': 'root', 'component': 'CheckBox', 'label': 'Subscribe'},
      ]);

      expect(
        html,
        '<label class="a2ui-checkbox">'
        '<input class="a2ui-checkbox__input" type="checkbox"/>'
        '<span class="a2ui-checkbox__label">Subscribe</span>'
        '</label>',
      );
    });

    test('checks the box when the bound value is true', () async {
      final html = await renderCheckBox(
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Subscribe',
            'value': {'path': '/subscribed'},
          },
        ],
        data: {'/subscribed': true},
      );

      expect(html, contains('checked'));
    });

    test('leaves the box unchecked when the bound value is false', () async {
      final html = await renderCheckBox(
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Subscribe',
            'value': {'path': '/subscribed'},
          },
        ],
        data: {'/subscribed': false},
      );

      expect(html, isNot(contains('checked')));
    });

    test('shows the message for a failing check', () async {
      final html = await renderCheckBox(
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Agree to terms',
            'checks': [
              {
                'condition': {'path': '/agreedOk'},
                'message': 'You must agree first',
              },
            ],
          },
        ],
        data: {'/agreedOk': false},
      );

      expect(html, contains('class="a2ui-checkbox a2ui-checkbox--invalid"'));
      expect(
        html,
        contains(
          '<small class="a2ui-checkbox__error">You must agree first</small>',
        ),
      );
    });

    test('shows no message while its checks pass', () async {
      final html = await renderCheckBox(
        [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Agree to terms',
            'checks': [
              {
                'condition': {'path': '/agreedOk'},
                'message': 'You must agree first',
              },
            ],
          },
        ],
        data: {'/agreedOk': true},
      );

      expect(html, isNot(contains('a2ui-checkbox--invalid')));
      expect(html, isNot(contains('a2ui-checkbox__error')));
    });

    // The browser turns a click into a call to this setter. That final hop
    // lives in Jaspr's own event handling and needs a real input element, so
    // what is verified here is the contract the renderer offers the builder: a
    // bound value comes with a setter, and it writes where the model asked.
    group('write-back', () {
      testComponents('a bound value writes through to the model', (
        tester,
      ) async {
        final captured = await captureScope(
          tester,
          const CheckBoxComponent(),
          [
            {
              'id': 'root',
              'component': 'CheckBox',
              'label': 'Subscribe',
              'value': {'path': '/subscribed'},
            },
          ],
          data: {'/subscribed': false},
        );

        expect(captured.scope.props['value'], false);

        final write = captured.scope.setter('value');
        expect(write, isNotNull);

        write!(true);
        await tester.pump();

        expect(captured.surface.dataModel.get('/subscribed'), true);
      });

      testComponents('a literal value provides no setter', (tester) async {
        final captured = await captureScope(tester, const CheckBoxComponent(), [
          {
            'id': 'root',
            'component': 'CheckBox',
            'label': 'Subscribe',
            'value': true,
          },
        ]);

        expect(captured.scope.setter('value'), isNull);
      });
    });
  });
}
