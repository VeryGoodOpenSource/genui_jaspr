import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Text, rendered with the element that matches its variant.
///
/// A heading variant becomes a real heading element rather than a styled `div`,
/// so a generated page keeps a document outline that screen readers and search
/// engines can follow.
class TextComponent extends ExternalApiJasprComponent {
  /// Creates a [TextComponent].
  TextComponent() : super(MinimalTextApi());

  @override
  List<StyleRule> get styles => [
    const StyleRule(
      selector: Selector('.a2ui-text'),
      styles: Styles(raw: {'margin': '0'}),
    ),
    const StyleRule(
      selector: Selector('.a2ui-text--body'),
      styles: Styles(raw: {'font-size': '1rem', 'line-height': '1.5'}),
    ),
    const StyleRule(
      selector: Selector('.a2ui-text--caption'),
      styles: Styles(raw: {'font-size': '0.8125rem', 'opacity': '0.7'}),
    ),
    for (final (className, size) in const [
      ('a2ui-text--h1', '2rem'),
      ('a2ui-text--h2', '1.5rem'),
      ('a2ui-text--h3', '1.25rem'),
      ('a2ui-text--h4', '1.125rem'),
      ('a2ui-text--h5', '1rem'),
    ])
      StyleRule(
        selector: Selector('.$className'),
        styles: Styles(
          raw: {'font-size': size, 'line-height': '1.25', 'font-weight': '600'},
        ),
      ),
  ];

  @override
  Component build(ComponentScope scope) {
    final variant = scope.string('variant') ?? 'body';
    final content = scope.string('text') ?? '';
    final classes = 'a2ui-text a2ui-text--$variant';
    final children = [Component.text(content)];

    return switch (variant) {
      'h1' => h1(children, classes: classes),
      'h2' => h2(children, classes: classes),
      'h3' => h3(children, classes: classes),
      'h4' => h4(children, classes: classes),
      'h5' => h5(children, classes: classes),
      'caption' => small(children, classes: classes),
      _ => p(children, classes: classes),
    };
  }
}
