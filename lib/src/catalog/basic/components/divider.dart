import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A dividing rule between pieces of content.
class DividerComponent extends JasprComponent {
  /// Creates a [DividerComponent].
  const DividerComponent();

  @override
  String get name => 'Divider';

  /// The schema from the A2UI v0.9 basic catalog.
  @override
  Schema get schema => Schema.object(
    properties: {
      'axis': Schema.string(enumValues: ['horizontal', 'vertical']),
    },
  );

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-divider'),
      styles: Styles(
        raw: {
          'width': '100%',
          'height': '0',
          'margin': '0',
          'border': '0',
          'border-top': '1px solid var(--a2ui-border-color, #c4c7c5)',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-divider--vertical'),
      styles: Styles(
        raw: {
          'width': '0',
          'height': '100%',
          'border-top': '0',
          'border-left': '1px solid var(--a2ui-border-color, #c4c7c5)',
        },
      ),
    ),
  ];

  @override
  Component build(ComponentScope scope) => hr(
    classes: scope.string('axis') == 'vertical'
        ? 'a2ui-divider a2ui-divider--vertical'
        : 'a2ui-divider',
  );
}
