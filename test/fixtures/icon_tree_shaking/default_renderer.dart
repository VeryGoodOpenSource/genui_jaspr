// `print` keeps each compile-time reachability fixture observable.
// ignore_for_file: avoid_print

import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/jaspr.dart';

void main() {
  final icon = IconComponent();
  final name = DateTime.now().millisecondsSinceEpoch == 0
      ? 'add'
      : 'accountCircle';
  print(icon.build(_scope(name)));
}

ComponentScope _scope(String name) => ComponentScope(
  id: 'icon',
  instanceId: 'main:icon',
  type: 'Icon',
  props: {'name': name},
  theme: const {},
  buildChild: (_) => const Component.empty(),
  buildChildren: (_) => const [],
  reportError: print,
);
