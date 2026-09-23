// `print` keeps each compile-time reachability fixture observable.
// ignore_for_file: avoid_print

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/jaspr.dart';

/// Renders every component in [catalog] and prints every rule it declares.
///
/// Both halves matter. A fixture that only read `styles` would leave each
/// component's `build` unreachable, so a marker's absence would prove nothing
/// about catalog code, only about style code.
void exercise(Catalog<JasprComponent> catalog) {
  print('${catalog.id}:${catalog.components.length}');
  for (final component in catalog.components.values) {
    print(component.build(_scope(component.name)));
  }
  for (final rule in catalog.styles) {
    print(rule.toCss());
  }
}

ComponentScope _scope(String type) => ComponentScope(
  id: 'x',
  instanceId: 'main:x',
  type: type,
  props: {
    'text': 'x',
    'label': 'L',
    'options': const [
      {'label': 'Red', 'value': 'red'},
    ],
    'value': 'red',
  },
  theme: const {},
  buildChild: (_) => const Component.empty(),
  buildChildren: (_) => const [],
  reportError: print,
);
