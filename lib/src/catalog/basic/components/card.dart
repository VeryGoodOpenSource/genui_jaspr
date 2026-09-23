import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A card-like container around one child component.
class CardComponent extends JasprComponent {
  /// Creates a [CardComponent].
  const CardComponent();

  @override
  String get name => 'Card';

  /// The schema from the A2UI v0.9 basic catalog.
  @override
  Schema get schema => Schema.object(
    properties: {'child': CommonSchemas.componentId},
    required: ['child'],
  );

  /// A transparent surface plus an outline keeps nested cards distinct
  /// without tracking their depth or alternating background colours.
  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-card'),
      styles: Styles(
        raw: {
          'box-sizing': 'border-box',
          'padding': '1rem',
          'background': 'transparent',
          'border': '1px solid var(--a2ui-border-color, #c4c7c5)',
          'border-radius': '0.5rem',
        },
      ),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final childId = scope.string('child');
    return div(
      [if (childId != null) scope.buildChild(childId)],
      classes: 'a2ui-card',
    );
  }
}
