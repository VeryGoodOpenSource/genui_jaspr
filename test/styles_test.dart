import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/audio_player.dart';
import 'package:genui_jaspr/src/catalog/basic/components/card.dart';
import 'package:genui_jaspr/src/catalog/basic/components/check_box.dart';
import 'package:genui_jaspr/src/catalog/basic/components/choice_picker.dart';
import 'package:genui_jaspr/src/catalog/basic/components/date_time_input.dart';
import 'package:genui_jaspr/src/catalog/basic/components/divider.dart';
import 'package:genui_jaspr/src/catalog/basic/components/image.dart';
import 'package:genui_jaspr/src/catalog/basic/components/list.dart';
import 'package:genui_jaspr/src/catalog/basic/components/modal.dart';
import 'package:genui_jaspr/src/catalog/basic/components/slider.dart';
import 'package:genui_jaspr/src/catalog/basic/components/tabs.dart';
import 'package:genui_jaspr/src/catalog/basic/components/video.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_test/jaspr_test.dart';

import 'support/basic_catalog_fixtures.dart';
import 'support/harness.dart';

/// Pulls every `class="..."` value out of rendered markup.
Set<String> _classNamesIn(List<String> html) {
  final names = <String>{};
  final pattern = RegExp('class="([^"]+)"');
  for (final markup in html) {
    for (final match in pattern.allMatches(markup)) {
      names.addAll(match.group(1)!.split(' ').where((n) => n.isNotEmpty));
    }
  }
  return names;
}

/// Every class the five minimal components emit, across their variants.
Future<Set<String>> minimalClassNames() async {
  final html = <String>[];

  for (final variant in const [
    'body',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'caption',
  ]) {
    html.add(
      await renderSurfaceRaw([
        {'id': 'root', 'component': 'Text', 'text': 'x', 'variant': variant},
      ]),
    );
  }

  for (final variant in const ['primary', 'borderless']) {
    html.add(
      await renderSurfaceRaw([
        {
          'id': 'root',
          'component': 'Button',
          'child': 'label',
          'variant': variant,
          'action': {
            'event': {'name': 'go'},
          },
        },
        {'id': 'label', 'component': 'Text', 'text': 'Go'},
      ]),
    );
  }

  for (final variant in const ['shortText', 'number', 'obscured', 'longText']) {
    html.add(
      await renderSurfaceRaw([
        {
          'id': 'root',
          'component': 'TextField',
          'label': 'L',
          'variant': variant,
        },
      ]),
    );
  }

  // An invalid field, for the error classes.
  html.add(
    await renderSurfaceRaw(
      [
        {
          'id': 'root',
          'component': 'TextField',
          'label': 'L',
          'checks': [
            {
              'condition': {'path': '/ok'},
              'message': 'nope',
            },
          ],
        },
      ],
      data: {'/ok': false},
    ),
  );

  for (final component in const ['Row', 'Column']) {
    html.add(
      await renderSurfaceRaw([
        {'id': 'root', 'component': component, 'children': <String>[]},
      ]),
    );
  }

  return _classNamesIn(html);
}

/// Everything [minimalClassNames] covers, plus every class the Basic-only
/// components emit. The surface's own fallback markup is in here too, which is
/// why [surfaceClassNames] is subtracted before asserting coverage.
Future<Set<String>> basicClassNames() async {
  final html = <String>[
    await renderSurface(
      [
        {'id': 'root', 'component': 'Icon', 'name': 'add'},
      ],
      catalog: MinimalJasprCatalog().copyWith(add: [const IconComponent()]),
    ),
  ];

  final checkBoxCatalog = MinimalJasprCatalog().copyWith(
    add: [const CheckBoxComponent()],
  );

  html
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {'id': 'root', 'component': 'CheckBox', 'label': 'Subscribe'},
        ], catalog: checkBoxCatalog),
      ),
    )
    // An invalid checkbox, for the error classes.
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {
              'id': 'root',
              'component': 'CheckBox',
              'label': 'Subscribe',
              'checks': [
                {
                  'condition': {'path': '/ok'},
                  'message': 'nope',
                },
              ],
            },
          ],
          data: {'/ok': false},
          catalog: checkBoxCatalog,
        ),
      ),
    );

  final choicePickerCatalog = MinimalJasprCatalog().copyWith(
    add: [const ChoicePickerComponent()],
  );
  final choicePickerOptions = [
    {'label': 'Red', 'value': 'red'},
    {'label': 'Blue', 'value': 'blue'},
  ];

  html
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {
            'id': 'root',
            'component': 'ChoicePicker',
            'label': 'Colour',
            'variant': 'mutuallyExclusive',
            'options': choicePickerOptions,
            'value': 'red',
          },
        ], catalog: choicePickerCatalog),
      ),
    )
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {
            'id': 'root',
            'component': 'ChoicePicker',
            'variant': 'multipleSelection',
            'options': choicePickerOptions,
            'value': ['red'],
          },
        ], catalog: choicePickerCatalog),
      ),
    )
    // An invalid choice picker, for the error classes.
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {
              'id': 'root',
              'component': 'ChoicePicker',
              'label': 'Colour',
              'options': choicePickerOptions,
              'value': 'red',
              'checks': [
                {
                  'condition': {'path': '/ok'},
                  'message': 'nope',
                },
              ],
            },
          ],
          data: {'/ok': false},
          catalog: choicePickerCatalog,
        ),
      ),
    );

  final sliderCatalog = MinimalJasprCatalog().copyWith(
    add: [const SliderComponent()],
  );

  html
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {
            'id': 'root',
            'component': 'Slider',
            'label': 'Amount',
            'value': 5,
          },
        ], catalog: sliderCatalog),
      ),
    )
    // An invalid slider, for the error classes.
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {
              'id': 'root',
              'component': 'Slider',
              'label': 'Amount',
              'value': 5,
              'checks': [
                {
                  'condition': {'path': '/ok'},
                  'message': 'nope',
                },
              ],
            },
          ],
          data: {'/ok': false},
          catalog: sliderCatalog,
        ),
      ),
    );

  final dateTimeInputCatalog = MinimalJasprCatalog().copyWith(
    add: [const DateTimeInputComponent()],
  );

  html
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {
            'id': 'root',
            'component': 'DateTimeInput',
            'label': 'When',
            'value': '2024-01-01',
          },
        ], catalog: dateTimeInputCatalog),
      ),
    )
    // An invalid date/time input, for the error classes.
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {
              'id': 'root',
              'component': 'DateTimeInput',
              'label': 'When',
              'value': '2024-01-01',
              'checks': [
                {
                  'condition': {'path': '/ok'},
                  'message': 'nope',
                },
              ],
            },
          ],
          data: {'/ok': false},
          catalog: dateTimeInputCatalog,
        ),
      ),
    )
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {'id': 'root', 'component': 'Card', 'child': 'content'},
            {'id': 'content', 'component': 'Text', 'text': 'x'},
          ],
          catalog: MinimalJasprCatalog().copyWith(add: [const CardComponent()]),
        ),
      ),
    );

  final listCatalog = MinimalJasprCatalog().copyWith(
    add: [const ListComponent()],
  );
  for (final direction in const ['vertical', 'horizontal']) {
    html.add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {
            'id': 'root',
            'component': 'List',
            'children': <String>[],
            'direction': direction,
          },
        ], catalog: listCatalog),
      ),
    );
  }

  final dividerCatalog = MinimalJasprCatalog().copyWith(
    add: [const DividerComponent()],
  );
  for (final axis in const ['horizontal', 'vertical']) {
    html.add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {'id': 'root', 'component': 'Divider', 'axis': axis},
        ], catalog: dividerCatalog),
      ),
    );
  }

  final imageCatalog = MinimalJasprCatalog().copyWith(
    add: [const ImageComponent()],
  );
  for (final variant in const [
    'icon',
    'avatar',
    'smallFeature',
    'mediumFeature',
    'largeFeature',
    'header',
  ]) {
    html.add(
      await renderSurfaceModel(
        buildSurfaceModel([
          {
            'id': 'root',
            'component': 'Image',
            'url': '/photo.png',
            'variant': variant,
          },
        ], catalog: imageCatalog),
      ),
    );
  }

  html
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          tabsFixtureComponents(),
          catalog: MinimalJasprCatalog().copyWith(add: [const TabsComponent()]),
        ),
      ),
    )
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          modalFixtureComponents(),
          catalog: MinimalJasprCatalog().copyWith(
            add: [const ModalComponent()],
          ),
        ),
      ),
    )
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {'id': 'root', 'component': 'AudioPlayer', 'url': '/audio.mp3'},
          ],
          catalog: MinimalJasprCatalog().copyWith(
            add: [const AudioPlayerComponent()],
          ),
        ),
      ),
    )
    ..add(
      await renderSurfaceModel(
        buildSurfaceModel(
          [
            {'id': 'root', 'component': 'Video', 'url': '/video.mp4'},
          ],
          catalog: MinimalJasprCatalog().copyWith(
            add: [const VideoComponent()],
          ),
        ),
      ),
    )
    // The fallback for a component this catalog does not implement.
    ..add(
      await renderSurfaceRaw([
        {'id': 'root', 'component': 'NotARealComponent'},
      ]),
    );

  return {...await minimalClassNames(), ..._classNamesIn(html)};
}

/// Classes the surface renderer emits itself. No component owns them, and the
/// package deliberately ships no rules for them, so an app styles them or does
/// not. Subtracted before any coverage assertion.
const surfaceClassNames = {'a2ui-surface', 'a2ui-missing'};

List<String> _selectorsOf(List<StyleRule> rules) => [
  for (final rule in rules) rule.toCss().split('{').first.trim(),
];

Set<String> _styledClassNames(List<StyleRule> rules) {
  final pattern = RegExp(r'\.([a-zA-Z0-9_-]+)');
  return {
    for (final selector in _selectorsOf(rules))
      for (final match in pattern.allMatches(selector)) match.group(1)!,
  };
}

Future<void> _expectCovers(List<StyleRule> rules, Set<String> emitted) async {
  emitted.removeAll(surfaceClassNames);

  // Guard the guard: if rendering stopped producing classes, this would pass
  // while checking nothing.
  expect(emitted, hasLength(greaterThan(10)));

  final styled = _styledClassNames(rules);
  final uncovered = emitted.where((n) => !styled.contains(n)).toList()..sort();
  expect(uncovered, isEmpty, reason: 'classes with no style rule');
}

void main() {
  group('MinimalJasprCatalog.styles', () {
    test('has a rule for every class the catalog emits', () async {
      await _expectCovers(
        MinimalJasprCatalog().styles,
        await minimalClassNames(),
      );
    });

    test('carries nothing that styles a Basic-only class', () async {
      final basicOnly = (await basicClassNames())
        ..removeAll(await minimalClassNames())
        ..removeAll(surfaceClassNames);

      expect(basicOnly, hasLength(greaterThan(10)));
      expect(
        _styledClassNames(MinimalJasprCatalog().styles).intersection(basicOnly),
        isEmpty,
        reason: 'Basic-only classes styled by the minimal bundle',
      );
    });
  });

  group('BasicJasprCatalog.styles', () {
    test('has a rule for every class the catalog emits', () async {
      await _expectCovers(BasicJasprCatalog().styles, await basicClassNames());
      expect(
        _selectorsOf(BasicJasprCatalog().styles),
        contains('.a2ui-modal__dialog::backdrop'),
      );
    });
  });

  group('both bundles', () {
    for (final (name, rules) in [
      ('minimal', MinimalJasprCatalog().styles),
      ('Basic', BasicJasprCatalog().styles),
    ]) {
      test('the $name bundle declares each selector once', () {
        final selectors = _selectorsOf(rules);
        final seen = <String>{};
        final duplicated =
            selectors.where((selector) => !seen.add(selector)).toList()..sort();

        expect(duplicated, isEmpty, reason: 'selectors declared twice');
      });
    }
  });

  group('surface theme', () {
    test(
      'publishes theme values as custom properties on the surface',
      () async {
        final html = await renderSurfaceRaw(
          [
            {'id': 'root', 'component': 'Text', 'text': 'x'},
          ],
          theme: {'primaryColor': '#ff0000'},
        );

        expect(html, startsWith('<div class="a2ui-surface"'));
        expect(html, contains('--a2ui-primary-color: #ff0000'));
      },
    );

    test('wraps the surface even without a theme', () async {
      final html = await renderSurfaceRaw([
        {'id': 'root', 'component': 'Text', 'text': 'x'},
      ]);

      expect(html, startsWith('<div class="a2ui-surface"'));
      expect(html, isNot(contains('--a2ui-primary-color')));
    });

    test('the primary button resolves against the theme property', () {
      final css = MinimalJasprCatalog().styles
          .map((rule) => rule.toCss())
          .join('\n');

      expect(css, contains('var(--a2ui-primary-color'));
    });
  });
}
