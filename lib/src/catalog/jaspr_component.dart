import 'package:a2ui_core/a2ui_core.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Everything a builder needs to render one A2UI component.
///
/// The [props] are already resolved: data bindings have been read, function
/// calls evaluated, and actions turned into callbacks. A builder reads values
/// out of the map and never resolves a binding itself.
final class ComponentScope {
  /// Creates a [ComponentScope].
  const ComponentScope({
    required this.id,
    required this.instanceId,
    required this.type,
    required this.props,
    required this.theme,
    required this.buildChild,
    required this.buildChildren,
    required this.reportError,
  });

  /// This component's id within its surface.
  final String id;

  /// A key for this rendered instance, unique across the whole page.
  ///
  /// [id] is only unique within one surface, and a component repeated by a
  /// template renders once per row under the same [id]. Derive DOM `id`s and
  /// radio group `name`s from this instead, so two surfaces, or two rows,
  /// never share one. It is built from the surface id, [id] and the row's
  /// data-model path, so the server and the hydrated client agree on it.
  /// Treat it as opaque: its format is the renderer's to change.
  final String instanceId;

  /// The component type, as named in the catalog.
  final String type;

  /// The component's resolved properties.
  final Map<String, dynamic> props;

  /// The surface's theme, as sent with `createSurface`.
  final Map<String, dynamic> theme;

  /// Renders a single child by its component id.
  ///
  /// Used by components whose schema names one child, such as `Button`.
  final Component Function(String componentId) buildChild;

  /// Renders a resolved `children` property.
  ///
  /// The binder resolves such a property into a list of child references,
  /// which may come either from a literal list of ids or from a template
  /// repeated over a path in the data model. Both arrive here in the same
  /// shape. Most builders want [children] instead, which reads the property
  /// for them.
  final List<Component> Function(Object? childrenProp) buildChildren;

  /// Reports something that went wrong inside this component.
  ///
  /// The error reaches the surface and, through it, whoever is listening for
  /// errors to send back to the model. Actions obtained through [action] report
  /// their own failures, so a builder only needs this for problems it detects
  /// itself.
  final void Function(Object error) reportError;

  /// Renders the children named by the property [key].
  ///
  /// Used by containers such as `Row` and `Column`, whose schema has a
  /// `children` list.
  List<Component> children([String key = 'children']) =>
      buildChildren(props[key]);

  /// Reads [key] from [props] as a string, or null when absent.
  String? string(String key) {
    final Object? value = props[key];
    return value == null ? null : '$value';
  }

  /// Reads [key] from [props] as a callback, or null when absent.
  ///
  /// A property whose schema describes an action resolves to a function. The
  /// returned callback never throws: a failure inside the action, such as a
  /// call to a function the catalog does not have, is passed to [reportError]
  /// instead, so a broken action cannot take down the page from inside a click
  /// handler.
  Future<void> Function()? action(String key) {
    final Object? value = props[key];
    if (value is! Future<void> Function()) return null;
    return () async {
      try {
        await value();
      } on Object catch (error) {
        reportError(error);
      }
    };
  }

  /// Writes back to whatever the property named [key] is bound to.
  ///
  /// Present only when the model bound the property to a data-model path, which
  /// is what makes an input two-way. A field bound to a literal has no setter,
  /// and is therefore read-only by the model's own choosing.
  ///
  /// `NaN` is written as null. A number input reports `NaN` while its text is
  /// not a number, such as when it is empty or holds a lone minus sign, and the
  /// data model is sent to the model as JSON, which has no encoding for it.
  void Function(Object?)? setter(String key) {
    final name = 'set${key[0].toUpperCase()}${key.substring(1)}';
    final Object? write = props[name];
    if (write is! void Function(Object?)) return null;
    return (Object? value) =>
        write(value is double && value.isNaN ? null : value);
  }

  /// Whether this component's `checks` currently pass.
  ///
  /// Components without `checks` are always valid, so the absence of the
  /// property reads as valid rather than as a failure.
  bool get isValid => props['isValid'] != false;

  /// The messages for the `checks` that are currently failing.
  List<String> get validationErrors {
    final Object? value = props['validationErrors'];
    if (value is! List) return const [];
    return value.map((error) => '$error').toList();
  }
}

/// Renders a component from its resolved properties.
typedef ComponentBuilder = Component Function(ComponentScope scope);

/// A catalog entry: a component's A2UI API, how to render it, and how it looks.
///
/// A component is its own [ComponentApi]: it declares the [name] and the
/// [schema] that decides how each property binds, alongside the Jaspr sides,
/// [build] and [styles]:
///
/// ```dart
/// class DividerComponent extends JasprComponent {
///   const DividerComponent();
///
///   @override
///   String get name => 'Divider';
///
///   @override
///   Schema get schema => Schema.object(properties: {});
///
///   @override
///   Component build(ComponentScope scope) => hr(classes: 'a2ui-divider');
///
///   @override
///   List<StyleRule> get styles => const [
///     StyleRule(
///       selector: Selector('.a2ui-divider'),
///       styles: Styles(raw: {'border': 'none', 'height': '1px'}),
///     ),
///   ];
/// }
/// ```
///
/// To render a component whose API is defined elsewhere, such as the minimal
/// catalog's in `a2ui_core`, extend [ExternalApiJasprComponent] instead. For a
/// one-off, or in a test, [JasprComponent.inline] takes the parts directly
/// without a class of their own.
abstract class JasprComponent implements ComponentApi {
  /// A constructor for subclasses to call.
  const JasprComponent();

  /// A component from its [api] and a [build] closure.
  ///
  /// Takes [styles] too, so a catalog extended this way carries rules for what
  /// [build] emits the same way one extended with a subclass does. Without it
  /// an inline component would be the one kind a derived bundle could not
  /// account for.
  const factory JasprComponent.inline(
    ComponentApi api,
    ComponentBuilder build, {
    List<StyleRule> styles,
  }) = _InlineJasprComponent;

  /// Renders the component from its resolved properties.
  Component build(ComponentScope scope);

  /// The default rules for the CSS classes [build] emits.
  ///
  /// A component owns the appearance of its own markup, so a catalog can
  /// gather a complete stylesheet from whatever components it happens to hold
  /// rather than from a list someone maintains alongside it. Override this to
  /// style a component; leave it to emit classes a host stylesheet supplies.
  ///
  /// The rules this package ships read their colours from custom properties a
  /// surface publishes from the theme the model sent with `createSurface`, so
  /// a model can choose an accent at runtime while the rules stay static. Each
  /// `var()` carries a fallback, so an untouched theme still renders sensibly.
  List<StyleRule> get styles => const [];
}

/// A component that renders an API defined somewhere else.
///
/// The minimal catalog's APIs come from `a2ui_core`, which is also where any
/// other renderer of that catalog gets them. Wrapping the same [api] rather
/// than restating its schema keeps what the model is told it may send and
/// what this renders from drifting apart. Subclasses pass the API up and
/// supply [build] and, if they style their markup, [styles]:
///
/// ```dart
/// class TextComponent extends ExternalApiJasprComponent {
///   TextComponent() : super(MinimalTextApi());
///
///   @override
///   Component build(ComponentScope scope) =>
///       p([Component.text(scope.string('text') ?? '')]);
/// }
/// ```
abstract class ExternalApiJasprComponent extends JasprComponent {
  /// Creates a component that renders [api].
  const ExternalApiJasprComponent(this.api);

  /// The protocol definition this component renders.
  final ComponentApi api;

  @override
  String get name => api.name;

  @override
  Schema get schema => api.schema;
}

final class _InlineJasprComponent extends ExternalApiJasprComponent {
  const _InlineJasprComponent(super.api, this._build, {this.styles = const []});

  @override
  final List<StyleRule> styles;

  final ComponentBuilder _build;

  @override
  Component build(ComponentScope scope) => _build(scope);
}
