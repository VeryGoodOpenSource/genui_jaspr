import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Plays audio from an A2UI-provided URL using the browser's native controls.
class AudioPlayerComponent extends JasprComponent {
  /// Creates an [AudioPlayerComponent].
  const AudioPlayerComponent();

  @override
  String get name => 'AudioPlayer';

  /// The schema from the A2UI v0.9 basic catalog.
  @override
  Schema get schema => Schema.object(
    properties: {
      'url': CommonSchemas.dynamicString,
      'description': CommonSchemas.dynamicString,
    },
    required: ['url'],
  );

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-audio-player'),
      styles: Styles(raw: {'display': 'block', 'width': '100%'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    return audio(
      const [],
      src: scope.string('url') ?? '',
      controls: true,
      classes: 'a2ui-audio-player',
      attributes: {'aria-label': ?scope.string('description')},
    );
  }
}
