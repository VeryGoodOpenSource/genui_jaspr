import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:universal_web/web.dart' as web;

/// A date, time, or date-and-time input, bound to the data model in both
/// directions. Omitting `variant` renders both a date and a time picker, the
/// same default the A2UI spec's other renderers use.
///
/// Jaspr's own `onInput` converts a date, time, or datetime-local input's
/// value to a `DateTime`, which throws once the field is cleared (its
/// `valueAsNumber` is `NaN`, and `NaN.toInt()` has no web implementation).
/// This registers a raw `input` listener instead and reads the element's
/// `value` directly, which is already the exact string the schema binds, so
/// nothing needs converting or reformatting, and clearing the field writes
/// null the same way Slider and `TextField`'s number variant treat their own
/// missing-value case, rather than throwing.
class DateTimeInputComponent extends JasprComponent {
  /// Creates a [DateTimeInputComponent].
  const DateTimeInputComponent();

  @override
  String get name => 'DateTimeInput';

  /// The schema from the A2UI spec's basic catalog, taken from Flutter's
  /// `genui` reference implementation since `a2ui_core` has none to copy it
  /// from.
  @override
  Schema get schema => Schema.combined(
    allOf: [
      CommonSchemas.checkable,
      Schema.object(
        properties: {
          'value': CommonSchemas.dynamicString,
          'variant': Schema.string(enumValues: ['date', 'time', 'datetime']),
          'min': Schema.string(),
          'max': Schema.string(),
          'label': CommonSchemas.dynamicString,
        },
        required: ['value'],
      ),
    ],
  );

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-date-time-input'),
      styles: Styles(
        raw: {'display': 'flex', 'flex-direction': 'column', 'gap': '0.25rem'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-date-time-input__label'),
      styles: Styles(raw: {'font-size': '0.875rem', 'font-weight': '500'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-date-time-input__input'),
      styles: Styles(
        raw: {
          'font': 'inherit',
          'padding': '0.5rem',
          'border': '1px solid var(--a2ui-border-color, #c4c7c5)',
          'border-radius': '0.375rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-date-time-input__input:focus-visible'),
      styles: Styles(
        raw: {'outline': '2px solid var(--a2ui-primary-color, #1a73e8)'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-date-time-input__error'),
      styles: Styles(
        raw: {
          'color': 'var(--a2ui-error-color, #b3261e)',
          'font-size': '0.8125rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector(
        '.a2ui-date-time-input--invalid .a2ui-date-time-input__input',
      ),
      styles: Styles(raw: {'border-color': 'var(--a2ui-error-color, #b3261e)'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final variant = scope.string('variant') ?? 'datetime';
    final labelText = scope.string('label');
    final value = scope.string('value');
    final write = scope.setter('value');
    final errors = scope.validationErrors;

    return label(
      [
        if (labelText != null)
          span([
            Component.text(labelText),
          ], classes: 'a2ui-date-time-input__label'),
        input<Object?>(
          classes: 'a2ui-date-time-input__input',
          type: _inputType(variant),
          value: value == null || value.isEmpty ? null : value,
          events: write == null ? null : {'input': _writeRawValue(write)},
          attributes: {
            'min': ?scope.string('min'),
            'max': ?scope.string('max'),
          },
        ),
        for (final error in errors)
          small([
            Component.text(error),
          ], classes: 'a2ui-date-time-input__error'),
      ],
      classes: errors.isEmpty
          ? 'a2ui-date-time-input'
          : 'a2ui-date-time-input a2ui-date-time-input--invalid',
    );
  }
}

/// Maps the schema's `variant` onto the input type that gives the browser's
/// own date or time picker for that kind of value.
InputType _inputType(String variant) => switch (variant) {
  'date' => InputType.date,
  'time' => InputType.time,
  _ => InputType.dateTimeLocal,
};

/// Writes the input's raw string value straight to the data model, or null
/// once it is emptied.
///
/// Only a real browser ever calls this: a VM test can drive `build` but has
/// no DOM to dispatch an `input` event from, which is what the browser suite
/// covers instead. The event always comes from the `<input>` this listener is
/// attached to, so its target is always an `HTMLInputElement`.
void Function(web.Event) _writeRawValue(void Function(Object?) write) {
  // coverage:ignore-start
  return (event) {
    final input = event.target! as web.HTMLInputElement;
    write(input.value.isEmpty ? null : input.value);
  };
  // coverage:ignore-end
}
