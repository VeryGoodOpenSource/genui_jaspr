import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Displays an image from an A2UI-provided URL.
class ImageComponent extends JasprComponent {
  /// Creates an [ImageComponent].
  const ImageComponent();

  @override
  String get name => 'Image';

  /// The schema from the A2UI v0.9 basic catalog.
  @override
  Schema get schema => Schema.object(
    properties: {
      'url': CommonSchemas.dynamicString,
      'description': CommonSchemas.dynamicString,
      'fit': Schema.string(
        enumValues: ['contain', 'cover', 'fill', 'none', 'scaleDown'],
      ),
      'variant': Schema.string(
        enumValues: [
          'icon',
          'avatar',
          'smallFeature',
          'mediumFeature',
          'largeFeature',
          'header',
        ],
      ),
    },
    required: ['url'],
  );

  /// The fit is absent here because [build] writes it inline, the model
  /// choosing it per instance.
  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-image'),
      styles: Styles(
        raw: {'display': 'block', 'max-width': '100%'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-image--icon'),
      styles: Styles(raw: {'width': '1.5rem', 'height': '1.5rem'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-image--avatar'),
      styles: Styles(
        raw: {'width': '2.5rem', 'height': '2.5rem', 'border-radius': '50%'},
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-image--small-feature'),
      styles: Styles(raw: {'width': '6.25rem', 'height': '6.25rem'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-image--medium-feature'),
      styles: Styles(raw: {'width': '100%', 'max-width': '18.75rem'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-image--large-feature'),
      styles: Styles(raw: {'width': '100%', 'max-height': '25rem'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-image--header'),
      styles: Styles(raw: {'width': '100%', 'height': '12.5rem'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final variant = scope.string('variant') ?? 'mediumFeature';
    final fit = scope.string('fit') ?? 'fill';

    return img(
      src: scope.string('url') ?? '',
      alt: scope.string('description') ?? '',
      classes: 'a2ui-image a2ui-image--${_cssName(variant)}',
      styles: Styles(raw: {'object-fit': _cssName(fit)}),
    );
  }
}

String _cssName(String value) => value.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '-${match.group(0)!.toLowerCase()}',
);
