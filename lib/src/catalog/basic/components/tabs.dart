import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:universal_web/web.dart' as web;

/// `Tabs`' API from the A2UI v0.9 basic catalog.
class TabsApi extends ComponentApi {
  @override
  String get name => 'Tabs';

  @override
  Schema get schema => Schema.object(
    properties: {
      'tabs': Schema.list(
        minItems: 1,
        items: Schema.object(
          properties: {
            'title': CommonSchemas.dynamicString,
            'child': CommonSchemas.componentId,
          },
          required: ['title', 'child'],
          additionalProperties: false,
        ),
      ),
    },
    required: ['tabs'],
  );
}

/// Shows one child at a time behind a row of tab buttons.
class TabsComponent extends JasprComponent {
  /// Creates a [TabsComponent].
  TabsComponent();

  @override
  final ComponentApi api = TabsApi();

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-tabs'),
      styles: Styles(raw: {'min-width': '0'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-tabs__list'),
      styles: Styles(
        raw: {
          'display': 'flex',
          'gap': '0.25rem',
          'border-bottom': '1px solid var(--a2ui-border-color, #c4c7c5)',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-tabs__tab'),
      styles: Styles(
        raw: {
          'font': 'inherit',
          'padding': '0.5rem 0.75rem',
          'background': 'transparent',
          'border': '0',
          'border-bottom': '2px solid transparent',
          'cursor': 'pointer',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-tabs__tab--selected'),
      styles: Styles(
        raw: {
          'color': 'var(--a2ui-primary-color, #1a73e8)',
          'border-bottom-color': 'currentColor',
          'font-weight': '600',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-tabs__panel'),
      styles: Styles(raw: {'padding-top': '0.75rem'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final rawTabs = scope.props['tabs'];
    final tabs = rawTabs is List
        ? [
            for (final rawTab in rawTabs)
              if (rawTab is Map)
                _Tab(
                  title: '${rawTab['title'] ?? ''}',
                  childId: '${rawTab['child'] ?? ''}',
                ),
          ]
        : const <_Tab>[];

    return _Tabs(
      id: scope.instanceId,
      tabs: tabs,
      buildChild: scope.buildChild,
    );
  }
}

final class _Tab {
  const _Tab({required this.title, required this.childId});

  final String title;
  final String childId;
}

class _Tabs extends StatefulComponent {
  const _Tabs({
    required this.id,
    required this.tabs,
    required this.buildChild,
  });

  final String id;
  final List<_Tab> tabs;
  final Component Function(String componentId) buildChild;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  final _tabKeys = <int, GlobalNodeKey<web.HTMLButtonElement>>{};
  var _selectedIndex = 0;

  @override
  void didUpdateComponent(_Tabs oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (_selectedIndex >= component.tabs.length) _selectedIndex = 0;
  }

  void Function(web.Event) _keyHandler(int index) {
    // Only a real browser dispatches keyboard events and owns focus. The
    // browser suite verifies the selected panel, roving focus, and each
    // navigation-key family.
    // coverage:ignore-start
    return (event) {
      final keyboardEvent = event as web.KeyboardEvent;
      final lastIndex = component.tabs.length - 1;
      final nextIndex = switch (keyboardEvent.key) {
        'ArrowRight' || 'ArrowDown' => (index + 1) % component.tabs.length,
        'ArrowLeft' || 'ArrowUp' =>
          (index - 1 + component.tabs.length) % component.tabs.length,
        'Home' => 0,
        'End' => lastIndex,
        _ => null,
      };
      if (nextIndex == null) return;

      keyboardEvent.preventDefault();
      setState(() => _selectedIndex = nextIndex);
      Timer.run(() {
        if (!mounted) return;
        _tabKeys[nextIndex]?.currentNode?.focus();
      });
    };
    // coverage:ignore-end
  }

  @override
  Component build(BuildContext context) {
    final tabs = component.tabs;
    if (tabs.isEmpty) return const Component.empty();

    final selectedTab = tabs[_selectedIndex];
    final selectedTabId = '${component.id}-tab-$_selectedIndex';
    final selectedPanelId = '${component.id}-panel-$_selectedIndex';

    return div([
      div(
        [
          for (var index = 0; index < tabs.length; index++)
            button(
              [Component.text(tabs[index].title)],
              key: _tabKeys.putIfAbsent(
                index,
                GlobalNodeKey<web.HTMLButtonElement>.new,
              ),
              id: '${component.id}-tab-$index',
              classes: index == _selectedIndex
                  ? 'a2ui-tabs__tab a2ui-tabs__tab--selected'
                  : 'a2ui-tabs__tab',
              type: ButtonType.button,
              onClick: () => setState(() => _selectedIndex = index),
              events: {'keydown': _keyHandler(index)},
              attributes: {
                'role': 'tab',
                'aria-selected': '${index == _selectedIndex}',
                'aria-controls': '${component.id}-panel-$index',
                'tabindex': index == _selectedIndex ? '0' : '-1',
              },
            ),
        ],
        classes: 'a2ui-tabs__list',
        attributes: const {'role': 'tablist'},
      ),
      div(
        [component.buildChild(selectedTab.childId)],
        id: selectedPanelId,
        classes: 'a2ui-tabs__panel',
        attributes: {'role': 'tabpanel', 'aria-labelledby': selectedTabId},
      ),
    ], classes: 'a2ui-tabs');
  }
}
