import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// A button that dispatches its action when pressed.
///
/// A button whose `checks` are failing is disabled, so the surface stops an
/// invalid submission at the point of interaction rather than sending it and
/// waiting for the model to object.
class ButtonComponent extends ExternalApiJasprComponent {
  /// Creates a [ButtonComponent].
  ButtonComponent() : super(MinimalButtonApi());

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-button'),
      styles: Styles(
        raw: {
          'font': 'inherit',
          'padding': '0.5rem 1rem',
          'border-radius': '0.375rem',
          'border': '1px solid transparent',
          'cursor': 'pointer',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-button:disabled'),
      styles: Styles(raw: {'opacity': '0.5', 'cursor': 'not-allowed'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-button--primary'),
      styles: Styles(
        raw: {
          'background': 'var(--a2ui-primary-color, #1a73e8)',
          'color': 'var(--a2ui-primary-text-color, #ffffff)',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-button--borderless'),
      styles: Styles(
        raw: {
          'background': 'transparent',
          'color': 'var(--a2ui-primary-color, #1a73e8)',
        },
      ),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final variant = scope.string('variant') ?? 'primary';
    final childId = scope.string('child');
    final onPressed = scope.action('action');
    final enabled = scope.isValid && onPressed != null;

    return button(
      [if (childId != null) scope.buildChild(childId)],
      classes: 'a2ui-button a2ui-button--$variant',
      type: ButtonType.button,
      disabled: !enabled,
      onClick: enabled ? onPressed : null,
    );
  }
}
