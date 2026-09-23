import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A scrollable collection of child components.
class ListComponent extends JasprComponent {
  /// Creates a [ListComponent].
  const ListComponent();

  @override
  String get name => 'List';

  /// The schema from the A2UI v0.9 basic catalog.
  @override
  Schema get schema => Schema.object(
    properties: {
      'children': CommonSchemas.childList,
      'direction': Schema.string(enumValues: ['vertical', 'horizontal']),
      'align': Schema.string(enumValues: ['start', 'center', 'end', 'stretch']),
    },
    required: ['children'],
  );

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-list'),
      styles: Styles(
        raw: {
          'gap': '0.5rem',
          'min-width': '0',
          'min-height': '0',
          'padding': '0',
          'margin': '0',
        },
      ),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final isHorizontal = scope.string('direction') == 'horizontal';
    return div(
      scope.children(),
      classes: 'a2ui-list',
      styles: Styles(
        display: Display.flex,
        flexDirection: isHorizontal ? FlexDirection.row : FlexDirection.column,
        alignItems: _align(scope.string('align')),
        overflow: Overflow.only(
          x: isHorizontal ? Overflow.auto : null,
          y: isHorizontal ? null : Overflow.auto,
        ),
      ),
    );
  }
}

AlignItems _align(String? value) => switch (value) {
  'start' => AlignItems.start,
  'center' => AlignItems.center,
  'end' => AlignItems.end,
  _ => AlignItems.stretch,
};
