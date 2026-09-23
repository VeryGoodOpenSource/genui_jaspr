import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A checkbox with a label, bound to the data model in both directions.
class CheckBoxComponent extends JasprComponent {
  /// Creates a [CheckBoxComponent].
  const CheckBoxComponent();

  @override
  String get name => 'CheckBox';

  /// The schema from the A2UI spec's basic catalog, taken from Flutter's
  /// `genui` reference implementation since `a2ui_core` has none to copy it
  /// from.
  @override
  Schema get schema => Schema.combined(
    allOf: [
      CommonSchemas.checkable,
      Schema.object(
        properties: {
          'label': CommonSchemas.dynamicString,
          'value': CommonSchemas.dynamicBoolean,
        },
        required: ['label', 'value'],
      ),
    ],
  );

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-checkbox'),
      styles: Styles(
        raw: {
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '0.5rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-checkbox__input'),
      styles: Styles(
        raw: {'width': '1.125rem', 'height': '1.125rem'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-checkbox__label'),
      styles: Styles(raw: {'font-size': '0.9375rem'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-checkbox__error'),
      styles: Styles(
        raw: {
          'color': 'var(--a2ui-error-color, #b3261e)',
          'font-size': '0.8125rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-checkbox--invalid .a2ui-checkbox__label'),
      styles: Styles(raw: {'color': 'var(--a2ui-error-color, #b3261e)'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final labelText = scope.string('label') ?? '';
    final checked = scope.props['value'] == true;
    final write = scope.setter('value');
    final errors = scope.validationErrors;

    return label(
      [
        input<bool>(
          classes: 'a2ui-checkbox__input',
          type: InputType.checkbox,
          checked: checked,
          onChange: write,
        ),
        span([Component.text(labelText)], classes: 'a2ui-checkbox__label'),
        for (final error in errors)
          small([Component.text(error)], classes: 'a2ui-checkbox__error'),
      ],
      classes: errors.isEmpty
          ? 'a2ui-checkbox'
          : 'a2ui-checkbox a2ui-checkbox--invalid',
    );
  }
}
