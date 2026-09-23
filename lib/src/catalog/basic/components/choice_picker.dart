import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// `ChoicePicker`'s API, one of the basic catalog's components that
/// `a2ui_core` does not ship. Its schema is trimmed to the fields this
/// renderer acts on: a labelled group of options, rendered as radio buttons
/// when `mutuallyExclusive` or checkboxes when `multipleSelection`.
class ChoicePickerApi extends ComponentApi {
  @override
  String get name => 'ChoicePicker';

  @override
  Schema get schema => Schema.combined(
    allOf: [
      CommonSchemas.checkable,
      Schema.object(
        properties: {
          'label': CommonSchemas.dynamicString,
          // The reference implementation's `listOrReference`: a literal
          // list whose options each bind their own `label`, or a binding or
          // function call supplying the whole list. The renderer narrows the
          // schema to whichever the value is, so both resolve fully.
          'options': Schema.combined(
            oneOf: [
              Schema.list(
                items: Schema.object(
                  properties: {
                    'label': CommonSchemas.dynamicString,
                    'value': Schema.string(),
                  },
                  required: ['label', 'value'],
                ),
              ),
              CommonSchemas.dataBinding,
              CommonSchemas.functionCall,
            ],
          ),
          'value': Schema.combined(
            anyOf: [
              Schema.string(),
              Schema.list(items: Schema.string()),
              CommonSchemas.dataBinding,
              CommonSchemas.functionCall,
            ],
          ),
          'variant': Schema.string(
            enumValues: ['mutuallyExclusive', 'multipleSelection'],
          ),
        },
        required: ['options', 'value'],
      ),
    ],
  );
}

/// A group of options the user picks one or more of, bound to the data model
/// in both directions.
///
/// `multipleSelection` (the default, matching the A2UI reference
/// implementation) renders a checkbox per option and writes back the list of
/// every option currently checked. `mutuallyExclusive` renders radio buttons
/// sharing a group name unique to this rendered instance, so only one can ever
/// be checked, and a picker with the same id on another surface, or in
/// another row of a template, stays a separate group.
class ChoicePickerComponent extends JasprComponent {
  /// Creates a [ChoicePickerComponent].
  ChoicePickerComponent();

  @override
  final ComponentApi api = ChoicePickerApi();

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-choice-picker'),
      styles: Styles(
        raw: {
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '0.375rem',
          'border': 'none',
          'padding': '0',
          'margin': '0',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-choice-picker__label'),
      styles: Styles(
        raw: {'font-size': '0.875rem', 'font-weight': '500', 'padding': '0'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-choice-picker__option'),
      styles: Styles(
        raw: {
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '0.5rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-choice-picker__input'),
      styles: Styles(
        raw: {'width': '1.125rem', 'height': '1.125rem'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-choice-picker__option-label'),
      styles: Styles(raw: {'font-size': '0.9375rem'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-choice-picker__error'),
      styles: Styles(
        raw: {
          'color': 'var(--a2ui-error-color, #b3261e)',
          'font-size': '0.8125rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector(
        '.a2ui-choice-picker--invalid .a2ui-choice-picker__label',
      ),
      styles: Styles(raw: {'color': 'var(--a2ui-error-color, #b3261e)'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final labelText = scope.string('label');
    final isMulti = scope.string('variant') != 'mutuallyExclusive';
    // A bound list comes straight from the data model, which may hold
    // anything, or nothing yet while the path is unset. Only maps are options.
    final rawOptions = scope.props['options'];
    final options = (rawOptions is List ? rawOptions : const <Object?>[])
        .whereType<Map<Object?, Object?>>();
    final write = scope.setter('value');
    final errors = scope.validationErrors;

    final selected = _selectedValues(scope.props['value']);

    return fieldset(
      [
        if (labelText != null)
          legend([
            Component.text(labelText),
          ], classes: 'a2ui-choice-picker__label'),
        for (final option in options)
          _option(
            groupName: scope.instanceId,
            option: option,
            isMulti: isMulti,
            selected: selected,
            write: write,
          ),
        for (final error in errors)
          small([
            Component.text(error),
          ], classes: 'a2ui-choice-picker__error'),
      ],
      classes: errors.isEmpty
          ? 'a2ui-choice-picker'
          : 'a2ui-choice-picker a2ui-choice-picker--invalid',
    );
  }

  Component _option({
    required String groupName,
    required Map<Object?, Object?> option,
    required bool isMulti,
    required Set<String> selected,
    required void Function(Object?)? write,
  }) {
    final value = '${option['value']}';
    final optionLabel = option['label']?.toString() ?? '';
    final checked = selected.contains(value);

    ValueChanged<bool>? onChange;
    if (write != null) {
      // Only a real browser ever calls into these closures: a VM test can
      // drive `build` but never fires a real `change` event, which is what
      // the browser suite covers instead.
      // coverage:ignore-start
      onChange = isMulti
          ? (isChecked) {
              final next = Set<String>.of(selected);
              if (isChecked) {
                next.add(value);
              } else {
                next.remove(value);
              }
              write(next.toList());
            }
          : (isChecked) {
              if (isChecked) write(value);
            };
      // coverage:ignore-end
    }

    return label(
      [
        input<bool>(
          classes: 'a2ui-choice-picker__input',
          type: isMulti ? InputType.checkbox : InputType.radio,
          name: isMulti ? null : groupName,
          checked: checked,
          onChange: onChange,
        ),
        span([
          Component.text(optionLabel),
        ], classes: 'a2ui-choice-picker__option-label'),
      ],
      classes: 'a2ui-choice-picker__option',
    );
  }
}

/// Normalizes `value` into the set of currently-selected option values.
///
/// The schema admits either a plain string or a list of strings for either
/// variant, so a model that sends one shape under the "wrong" variant (a
/// scalar under `multipleSelection`, or a list under `mutuallyExclusive`,
/// which the A2UI reference implementation's own example data does) still
/// renders correctly rather than crashing or matching nothing.
Set<String> _selectedValues(Object? value) {
  if (value is List) return value.map((v) => '$v').toSet();
  if (value == null) return const {};
  return {'$value'};
}
