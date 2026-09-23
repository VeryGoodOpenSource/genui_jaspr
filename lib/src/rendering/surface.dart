import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:genui_jaspr/src/conversation/client_messages.dart';
import 'package:genui_jaspr/src/rendering/narrowed_schema.dart';
import 'package:genui_jaspr/src/rendering/signal_builder.dart';
import 'package:genui_jaspr/src/rendering/theme_properties.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Builds what a surface shows while it has no root component yet.
typedef SurfacePlaceholderBuilder = Component Function(BuildContext context);

/// Builds what stands in for a component the surface cannot render.
///
/// [message] says why: the catalog has no entry for the component's type, or
/// the surface has no component with the id a parent referred to.
typedef SurfaceFallbackBuilder =
    Component Function(BuildContext context, String message);

/// The id of the component a surface renders as the root of its tree.
///
/// Fixed by the protocol: nothing appears until a component with this id
/// exists.
const String rootComponentId = 'root';

/// Renders an A2UI surface.
///
/// A surface arrives empty and fills in as messages are applied, so this
/// renders [placeholder], or nothing, until its root component exists and then
/// appears on its own.
class Surface extends StatefulComponent {
  /// Creates a [Surface] rendering [surface].
  const Surface({
    required this.surface,
    this.placeholder,
    this.fallback,
    super.key,
  });

  /// The surface to render. Owned by the caller, not disposed here.
  final SurfaceModel<JasprComponent> surface;

  /// Shown while the surface has no root component, such as during the moment
  /// between `createSurface` arriving and the components that follow it.
  ///
  /// Nothing is shown when this is null.
  final SurfacePlaceholderBuilder? placeholder;

  /// Shown in place of a component that cannot be rendered.
  ///
  /// By default a visible notice is rendered, which is right while developing
  /// and may not be what an end user should see. Return an empty component to
  /// hide such gaps, or something that fits the app.
  final SurfaceFallbackBuilder? fallback;

  @override
  State<Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<Surface> {
  @override
  void initState() {
    super.initState();
    _listen(component.surface);
  }

  @override
  void didUpdateComponent(Surface oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.surface != component.surface) {
      _stopListening(oldComponent.surface);
      _listen(component.surface);
    }
  }

  void _listen(SurfaceModel<JasprComponent> surface) {
    surface.componentsModel.onCreated.addListener(_onComponentsChanged);
    surface.componentsModel.onDeleted.addListener(_onComponentsChanged);
  }

  void _stopListening(SurfaceModel<JasprComponent> surface) {
    surface.componentsModel.onCreated.removeListener(_onComponentsChanged);
    surface.componentsModel.onDeleted.removeListener(_onComponentsChanged);
  }

  /// Components are added and removed while a response streams in, so the tree
  /// has to be reconsidered whenever the set changes.
  void _onComponentsChanged(Object? _) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopListening(component.surface);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final hasRoot =
        component.surface.componentsModel.get(rootComponentId) != null;

    // The surface root carries the theme as custom properties, so the static
    // stylesheet can react to colours the model chose at runtime.
    return div(
      [
        if (hasRoot)
          _SurfaceOptions(
            fallback: component.fallback,
            child: A2uiComponent(
              surface: component.surface,
              componentId: rootComponentId,
            ),
          )
        else if (component.placeholder != null)
          component.placeholder!(context),
      ],
      classes: 'a2ui-surface',
      styles: themeProperties(component.surface.theme),
    );
  }
}

/// Carries a [Surface]'s options down to every [A2uiComponent] beneath it,
/// so a nested component can find the fallback without every level passing it
/// along.
class _SurfaceOptions extends InheritedComponent {
  const _SurfaceOptions({required this.fallback, required super.child});

  final SurfaceFallbackBuilder? fallback;

  static SurfaceFallbackBuilder? fallbackOf(BuildContext context) {
    return context
        .dependOnInheritedComponentOfExactType<_SurfaceOptions>()
        ?.fallback;
  }

  @override
  bool updateShouldNotify(_SurfaceOptions oldComponent) =>
      oldComponent.fallback != fallback;
}

/// Renders one component of a surface, and through its children the subtree
/// beneath it.
///
/// [Surface] renders one of these for the root component, and containers
/// render one per child through `ComponentScope`. Use it directly only to
/// render a single component outside its surface's tree.
///
/// Each instance owns a [GenericBinder] for its component. The binder resolves
/// the component's raw properties into concrete values and republishes them
/// whenever the data they depend on changes, which is what makes a surface
/// reactive without the renderer tracking dependencies itself.
class A2uiComponent extends StatefulComponent {
  /// Creates an [A2uiComponent] rendering [componentId] within [surface].
  const A2uiComponent({
    required this.surface,
    required this.componentId,
    this.basePath = '/',
    super.key,
  });

  /// The surface the component belongs to.
  final SurfaceModel<JasprComponent> surface;

  /// The id of the component to render, within [surface].
  final String componentId;

  /// The data-model path children resolve against.
  ///
  /// A component repeated over a list is rendered once per element, each with a
  /// base path pointing at its own element, so relative bindings inside the
  /// template resolve to the right row.
  final String basePath;

  @override
  State<A2uiComponent> createState() => _A2uiComponentState();
}

class _A2uiComponentState extends State<A2uiComponent> {
  GenericBinder? _binder;
  JasprComponent? _entry;
  ComponentModel? _model;
  Set<String> _narrowed = const {};

  @override
  void initState() {
    super.initState();
    _bind();
    _watchForReplacement(component.surface);
  }

  @override
  void didUpdateComponent(A2uiComponent oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.componentId != component.componentId ||
        oldComponent.basePath != component.basePath ||
        oldComponent.surface != component.surface) {
      if (oldComponent.surface != component.surface) {
        _stopWatching(oldComponent.surface);
        _watchForReplacement(component.surface);
      }
      _unbind();
      _bind();
    }
  }

  void _watchForReplacement(SurfaceModel<JasprComponent> surface) {
    surface.componentsModel.onCreated.addListener(_onComponentCreated);
    surface.componentsModel.onDeleted.addListener(_onComponentDeleted);
  }

  void _stopWatching(SurfaceModel<JasprComponent> surface) {
    surface.componentsModel.onCreated.removeListener(_onComponentCreated);
    surface.componentsModel.onDeleted.removeListener(_onComponentDeleted);
  }

  /// Re-binds when this component's model is replaced rather than edited.
  ///
  /// Changing a component's type is applied by removing it and adding a
  /// fresh model under the same id. The id did not change, so nothing else
  /// here would notice, and this would keep rendering the previous type
  /// against a model that is no longer in the surface.
  void _onComponentCreated(ComponentModel model) {
    if (model.id != component.componentId || model == _model) return;
    if (!mounted) return;
    setState(() {
      _unbind();
      _bind();
    });
  }

  void _onComponentDeleted(String id) {
    if (id != component.componentId || !mounted) return;
    // Only drop the binding. A replacement usually follows in the same message,
    // and the create handler picks it up.
    setState(_unbind);
  }

  void _bind() {
    final model = component.surface.componentsModel.get(component.componentId);
    if (model == null) return;
    _model = model;

    final entry = component.surface.catalog.components[model.type];
    if (entry == null) return;
    _entry = entry;

    final narrowed = narrowSchema(entry.schema, model.properties);
    _narrowed = narrowed.narrowed;
    model.onUpdated.addListener(_onModelUpdated);
    _binder = GenericBinder(
      ComponentContext(component.surface, model, basePath: component.basePath),
      narrowed.schema,
    );
  }

  /// Re-binds when an update moves a list-or-binding property between a
  /// literal list and a binding.
  ///
  /// The binder re-resolves an edited component on its own, but against the
  /// schema it was built with, which was narrowed for the previous value. A
  /// property that became a literal list would keep resolving as one opaque
  /// value, and one that became a binding would never be watched.
  void _onModelUpdated(ComponentModel model) {
    final entry = _entry;
    if (entry == null || !mounted) return;
    final narrowed = narrowSchema(entry.schema, model.properties).narrowed;
    if (narrowed.length == _narrowed.length &&
        narrowed.containsAll(_narrowed)) {
      return;
    }
    setState(() {
      _unbind();
      _bind();
    });
  }

  void _unbind() {
    _model?.onUpdated.removeListener(_onModelUpdated);
    _binder?.dispose();
    _binder = null;
    _entry = null;
    _model = null;
    _narrowed = const {};
  }

  @override
  void dispose() {
    _stopWatching(component.surface);
    _unbind();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final model = _model;
    if (model == null) {
      return _missing(
        context,
        'No component with id "${component.componentId}".',
      );
    }

    final entry = _entry;
    final binder = _binder;
    if (entry == null || binder == null) {
      // The model asked for a component this catalog does not implement. Say so
      // in the page rather than throwing, so one unknown component does not
      // take down the surrounding surface.
      return _missing(context, 'Unknown component "${model.type}".');
    }

    return SignalBuilder<Map<String, dynamic>>(
      signal: binder.resolvedProps,
      builder: (context, props) => entry.build(
        ComponentScope(
          id: component.componentId,
          instanceId: _instanceId,
          type: model.type,
          props: props,
          theme: component.surface.theme,
          buildChild: _buildChild,
          buildChildren: _buildChildren,
          reportError: _reportError,
        ),
      ),
    );
  }

  /// Joins the parts that together identify this instance, each encoded so a
  /// separator inside one part cannot make two different instances collide.
  /// The root data-model path is left off, so a component outside any
  /// template reads as just its surface and id.
  String get _instanceId => [
    component.surface.id,
    component.componentId,
    if (component.basePath != '/') component.basePath,
  ].map(Uri.encodeComponent).join(':');

  Component _buildChild(String componentId) {
    return A2uiComponent(
      surface: component.surface,
      componentId: componentId,
      basePath: component.basePath,
    );
  }

  List<Component> _buildChildren(Object? childrenProp) {
    if (childrenProp is! List) return const [];
    final children = <Component>[];
    for (final Object? entry in childrenProp) {
      if (entry is ChildNode) {
        children.add(
          A2uiComponent(
            surface: component.surface,
            componentId: entry.id,
            basePath: entry.basePath,
          ),
        );
      } else if (entry != null) {
        children.add(_buildChild('$entry'));
      }
    }
    return children;
  }

  /// Hands an error to the surface, which is where a `GenUiConversation`
  /// listens for them.
  void _reportError(Object error) {
    unawaited(
      component.surface.dispatchError(
        clientErrorFrom(error, surfaceId: component.surface.id),
      ),
    );
  }

  Component _missing(BuildContext context, String message) {
    final fallback = _SurfaceOptions.fallbackOf(context);
    if (fallback != null) return fallback(context, message);
    return div(
      [Component.text(message)],
      classes: 'a2ui-missing',
      attributes: const {'role': 'alert'},
    );
  }
}
