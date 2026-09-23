import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

/// A labelled text input, bound to the data model in both directions.
///
/// The field is wrapped in its `label`, which associates the two without
/// needing generated ids. Typing writes straight to the path the model bound
/// `value` to, so the next request carries what the user entered without the
/// app copying it anywhere.
class TextFieldComponent extends ExternalApiJasprComponent {
  /// Creates a [TextFieldComponent].
  TextFieldComponent() : super(MinimalTextFieldApi());

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-field'),
      styles: Styles(
        raw: {'display': 'flex', 'flex-direction': 'column', 'gap': '0.25rem'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-field__label'),
      styles: Styles(raw: {'font-size': '0.875rem', 'font-weight': '500'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-field__input'),
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
      selector: Selector('.a2ui-field__input:focus-visible'),
      styles: Styles(
        raw: {'outline': '2px solid var(--a2ui-primary-color, #1a73e8)'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-field__error'),
      styles: Styles(
        raw: {
          'color': 'var(--a2ui-error-color, #b3261e)',
          'font-size': '0.8125rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-field--invalid .a2ui-field__input'),
      styles: Styles(raw: {'border-color': 'var(--a2ui-error-color, #b3261e)'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final variant = scope.string('variant') ?? 'shortText';
    final labelText = scope.string('label') ?? '';
    final value = scope.string('value') ?? '';
    final write = scope.setter('value');
    final errors = scope.validationErrors;

    // A number input hands over a num, and NaN while its text is not a number.
    // The setter turns that NaN into nothing rather than letting it reach JSON.
    final field = variant == 'longText'
        ? _LongText(value: value, onInput: write)
        : input<Object?>(
            classes: 'a2ui-field__input',
            type: _inputType(variant),
            value: value.isEmpty ? null : value,
            onInput: write,
            attributes: {'pattern': ?scope.string('validationRegexp')},
          );

    return label(
      [
        span([Component.text(labelText)], classes: 'a2ui-field__label'),
        field,
        for (final error in errors)
          small([Component.text(error)], classes: 'a2ui-field__error'),
      ],
      classes: errors.isEmpty ? 'a2ui-field' : 'a2ui-field a2ui-field--invalid',
    );
  }
}

/// Maps the schema's `variant` onto the input type that gives the browser's own
/// keyboard and validation for that kind of value.
InputType _inputType(String variant) => switch (variant) {
  'number' => InputType.number,
  'obscured' => InputType.password,
  _ => InputType.text,
};

/// A textarea that follows its bound value in both directions.
///
/// A textarea carries its initial value as content rather than an attribute,
/// and once the user has typed, what the browser shows is the element's `value`
/// property rather than that content. Rendering the content alone therefore
/// works until the first keystroke and then silently stops following the data
/// model, so the property is set as well whenever the two differ.
class _LongText extends StatefulComponent {
  const _LongText({required this.value, required this.onInput});

  final String value;
  final void Function(Object?)? onInput;

  @override
  State<_LongText> createState() => _LongTextState();
}

class _LongTextState extends State<_LongText> {
  final _node = GlobalNodeKey<web.HTMLTextAreaElement>();

  @override
  void didUpdateComponent(_LongText oldComponent) {
    super.didUpdateComponent(oldComponent);
    // The element already exists here, so its value can be brought in line
    // before the new content is rendered. The user's own typing arrives as a
    // value equal to what the element holds, and is left alone: setting a
    // textarea's value, even to what it already holds, moves the caret. The
    // key yields no node outside a browser, where the content is all anyone
    // will see, and the null-aware writes make that a quiet no-op.
    final node = _node.currentNode;
    if (node?.value != component.value) node?.value = component.value;
  }

  @override
  Component build(BuildContext context) {
    return textarea(
      [Component.text(component.value)],
      key: _node,
      classes: 'a2ui-field__input',
      onInput: component.onInput,
    );
  }
}
