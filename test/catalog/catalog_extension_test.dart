import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// The API of a component the minimal catalog does not have.
class _DividerApi extends ComponentApi {
  @override
  String get name => 'Divider';

  @override
  Schema get schema => Schema.object(properties: {'axis': Schema.string()});
}

/// A component that declares nothing but its API and [build], so it takes
/// [JasprComponent]'s own default for [JasprComponent.styles].
class _BareDividerComponent extends JasprComponent {
  @override
  String get name => 'Divider';

  @override
  Schema get schema => Schema.object(properties: {});

  @override
  Component build(ComponentScope scope) => const hr();
}

/// A component whose API is defined by someone else.
class _ExternalDividerComponent extends ExternalApiJasprComponent {
  _ExternalDividerComponent() : super(_DividerApi());

  @override
  Component build(ComponentScope scope) => const hr();
}

class _UpperFunction extends FunctionImplementation {
  @override
  String get name => 'upper';

  @override
  A2uiReturnType get returnType => A2uiReturnType.string;

  @override
  Schema get argumentSchema => Schema.object(properties: {});

  @override
  Object? execute(
    Map<String, dynamic> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) => '${args['value']}'.toUpperCase();
}

void main() {
  group('JasprComponent', () {
    test('is its own API', () {
      final component = _BareDividerComponent();

      expect(component, isA<ComponentApi>());
      expect(component.name, 'Divider');
      expect(component.schema.value, Schema.object(properties: {}).value);
    });
  });

  group('ExternalApiJasprComponent', () {
    test('takes its name and schema from the API it wraps', () {
      final component = _ExternalDividerComponent();

      expect(component.api, isA<_DividerApi>());
      expect(component.name, 'Divider');
      expect(
        component.schema.value,
        Schema.object(properties: {'axis': Schema.string()}).value,
      );
    });

    test('renders from its own build', () async {
      final html = await renderSurface(
        [
          {'id': 'root', 'component': 'Divider'},
        ],
        catalog: MinimalJasprCatalog().copyWith(
          add: [_ExternalDividerComponent()],
        ),
      );

      expect(html, '<hr/>');
    });

    test('backs JasprComponent.inline', () {
      final component = JasprComponent.inline(
        _DividerApi(),
        (scope) => const hr(),
      );

      expect(component, isA<ExternalApiJasprComponent>());
      expect(component.name, 'Divider');
    });
  });

  group('Catalog.styles', () {
    test('gathers the rules of every component in the catalog', () {
      final catalog = MinimalJasprCatalog().copyWith(
        add: [const IconComponent()],
      );

      expect(_selectorsOf(catalog.styles), contains('.a2ui-icon'));
    });

    test('a derivation that drops a component drops its rules too', () {
      final catalog = MinimalJasprCatalog()
          .copyWith(add: [const IconComponent()])
          .copyWith(remove: ['Icon']);

      expect(_selectorsOf(catalog.styles), isNot(contains('.a2ui-icon')));
    });

    test('an inline component carries the rules it was given', () {
      final catalog = MinimalJasprCatalog().copyWith(
        add: [
          JasprComponent.inline(
            _DividerApi(),
            (scope) => const hr(),
            styles: const [
              StyleRule(
                selector: Selector('.a2ui-divider'),
                styles: Styles(raw: {'border': 'none'}),
              ),
            ],
          ),
        ],
      );

      expect(_selectorsOf(catalog.styles), contains('.a2ui-divider'));
    });

    test('a component that declares no rules contributes none', () {
      final catalog = MinimalJasprCatalog().copyWith(
        add: [_BareDividerComponent()],
      );

      expect(_BareDividerComponent().styles, isEmpty);
      expect(
        _selectorsOf(catalog.styles),
        _selectorsOf(MinimalJasprCatalog().styles),
      );
    });

    test('an inline component given no rules contributes none', () {
      final component = JasprComponent.inline(
        _DividerApi(),
        (scope) => const hr(),
      );

      expect(component.styles, isEmpty);
    });
  });

  group('Catalog.copyWith', () {
    test('adds a component under a new id', () {
      final catalog = MinimalJasprCatalog().copyWith(
        id: 'com.example.catalog',
        add: [JasprComponent.inline(_DividerApi(), (scope) => const hr())],
      );

      expect(catalog.id, 'com.example.catalog');
      expect(catalog.components.keys, contains('Divider'));
      expect(catalog.components.keys, containsAll(['Text', 'Button']));
      // The original is untouched.
      expect(MinimalJasprCatalog().components.keys, isNot(contains('Divider')));
    });

    test('replaces a component of the same name', () async {
      final catalog = MinimalJasprCatalog().copyWith(
        add: [
          JasprComponent.inline(
            MinimalTextApi(),
            (scope) => span([
              Component.text(scope.string('text') ?? ''),
            ], classes: 'swapped'),
          ),
        ],
      );

      final html = await renderSurface([
        {'id': 'root', 'component': 'Text', 'text': 'hi'},
      ], catalog: catalog);

      expect(html, '<span class="swapped">hi</span>');
    });

    test('removes a component by name', () {
      final catalog = MinimalJasprCatalog().copyWith(remove: ['TextField']);

      expect(catalog.components.keys, isNot(contains('TextField')));
      expect(catalog.components, hasLength(4));
    });

    test('keeps the id, functions and theme schema unless told otherwise', () {
      final original = MinimalJasprCatalog();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.functions.keys, original.functions.keys);
      expect(copy.themeSchema, same(original.themeSchema));
    });

    test('merges functions and swaps the theme schema', () {
      final theme = Schema.object(properties: {'accent': Schema.string()});
      final catalog = MinimalJasprCatalog().copyWith(
        addFunctions: [_UpperFunction()],
        themeSchema: theme,
      );

      expect(catalog.functions.keys, containsAll(['capitalize', 'upper']));
      expect(catalog.themeSchema, same(theme));
    });
  });
}

Set<String> _selectorsOf(List<StyleRule> rules) => {
  for (final rule in rules) rule.toCss().split('{').first.trim(),
};
