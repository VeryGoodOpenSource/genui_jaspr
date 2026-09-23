import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A range input, bound to the data model in both directions.
///
/// Inputs bind through `ComponentScope.setter`, which already turns `NaN`
/// into null, so this gets that for free the same way `TextField`'s number
/// variant does.
class SliderComponent extends JasprComponent {
  /// Creates a [SliderComponent].
  const SliderComponent();

  @override
  String get name => 'Slider';

  /// The schema from the A2UI spec's basic catalog, taken from Flutter's
  /// `genui` reference implementation since `a2ui_core` has none to copy it
  /// from.
  @override
  Schema get schema => Schema.combined(
    allOf: [
      CommonSchemas.checkable,
      Schema.object(
        properties: {
          'value': Schema.combined(
            anyOf: [
              Schema.number(),
              CommonSchemas.dataBinding,
              CommonSchemas.functionCall,
            ],
          ),
          'min': Schema.number(),
          'max': Schema.number(),
          'label': CommonSchemas.dynamicString,
        },
        required: ['value'],
      ),
    ],
  );

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-slider'),
      styles: Styles(
        raw: {'display': 'flex', 'flex-direction': 'column', 'gap': '0.25rem'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-slider__label'),
      styles: Styles(raw: {'font-size': '0.875rem', 'font-weight': '500'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-slider__input'),
      styles: Styles(
        raw: {'accent-color': 'var(--a2ui-primary-color, #1a73e8)'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-slider__error'),
      styles: Styles(
        raw: {
          'color': 'var(--a2ui-error-color, #b3261e)',
          'font-size': '0.8125rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-slider--invalid .a2ui-slider__label'),
      styles: Styles(raw: {'color': 'var(--a2ui-error-color, #b3261e)'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final labelText = scope.string('label');
    final value = scope.string('value');
    final write = scope.setter('value');
    final errors = scope.validationErrors;

    return label(
      [
        if (labelText != null)
          span([Component.text(labelText)], classes: 'a2ui-slider__label'),
        input<Object?>(
          classes: 'a2ui-slider__input',
          type: InputType.range,
          value: value,
          onInput: write,
          attributes: {
            'min': scope.string('min') ?? '0',
            'max': scope.string('max') ?? '1',
          },
        ),
        for (final error in errors)
          small([Component.text(error)], classes: 'a2ui-slider__error'),
      ],
      classes: errors.isEmpty
          ? 'a2ui-slider'
          : 'a2ui-slider a2ui-slider--invalid',
    );
  }
}
