@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/modal.dart';
import 'package:genui_jaspr/src/catalog/basic/components/tabs.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

import '../support/basic_catalog_fixtures.dart';
import '../support/harness.dart';

({SurfaceModel<JasprComponent> surface, List<A2uiClientAction> actions})
modalSurface() {
  final catalog = MinimalJasprCatalog().copyWith(add: [const ModalComponent()]);
  final actions = <A2uiClientAction>[];
  final surface = buildSurfaceModel(
    modalFixtureComponents(),
    catalog: catalog,
    onAction: actions.add,
  );
  return (
    surface: surface,
    actions: actions,
  );
}

SurfaceModel<JasprComponent> surfaceWithTabs() {
  final catalog = MinimalJasprCatalog().copyWith(add: [const TabsComponent()]);
  return buildSurfaceModel(tabsFixtureComponents(), catalog: catalog);
}

void main() {
  testClient('opens natively and closes from its explicit control', (
    tester,
  ) async {
    final (:surface, :actions) = modalSurface();
    tester.pumpComponent(Surface(surface: surface));
    var dialog = web.document.querySelector('dialog')! as web.HTMLDialogElement;

    expect(dialog.open, isFalse);
    await tester.dispatchEvent(
      find.ancestor(
        of: find.text('Open details'),
        matching: find.tag('button'),
      ),
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    dialog = web.document.querySelector('dialog')! as web.HTMLDialogElement;
    expect(dialog.open, isTrue);
    expect(actions.map((action) => action.name), ['opened']);

    await tester.click(
      find.ancestor(of: find.text('Close'), matching: find.tag('button')),
    );
    expect(dialog.open, isFalse);
  });

  testClient('the native cancel-to-close path keeps renderer state in sync', (
    tester,
  ) async {
    final (:surface, :actions) = modalSurface();
    tester.pumpComponent(Surface(surface: surface));
    var dialog = web.document.querySelector('dialog')! as web.HTMLDialogElement;

    await tester.dispatchEvent(
      find.ancestor(
        of: find.text('Open details'),
        matching: find.tag('button'),
      ),
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    dialog = web.document.querySelector('dialog')! as web.HTMLDialogElement;
    expect(dialog.open, isTrue);

    expect(dialog.has('requestClose'), isTrue);
    dialog.callMethod<JSAny?>('requestClose'.toJS);
    await Future<void>.delayed(Duration.zero);
    expect(dialog.open, isFalse);
    expect(actions.map((action) => action.name), ['opened']);
  });

  testClient('clicking a tab renders only its matching child', (tester) async {
    final surface = surfaceWithTabs();

    tester.pumpComponent(Surface(surface: surface));
    expect(find.text('First panel'), findsOneComponent);
    expect(find.text('Second panel'), findsNothing);

    await tester.click(find.tag('button').at(1));

    expect(find.text('First panel'), findsNothing);
    expect(find.text('Second panel'), findsOneComponent);
  });

  testClient('arrow, Home, and End keys move selection and focus', (
    tester,
  ) async {
    final surface = surfaceWithTabs();
    tester.pumpComponent(Surface(surface: surface));

    void expectSelectedTab(int selectedIndex) {
      for (var index = 0; index < 2; index++) {
        final tab = web.document.getElementById('main:root-tab-$index')!;
        expect(
          tab.getAttribute('tabindex'),
          index == selectedIndex ? '0' : '-1',
        );
        expect(
          tab.getAttribute('aria-selected'),
          index == selectedIndex ? 'true' : 'false',
        );
      }
      expect(web.document.activeElement?.id, 'main:root-tab-$selectedIndex');
    }

    await tester.dispatchEvent(
      find.tag('button').first,
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'ArrowRight'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(find.text('Second panel'), findsOneComponent);
    expectSelectedTab(1);

    await tester.dispatchEvent(
      find.tag('button').at(1),
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'Home')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(find.text('First panel'), findsOneComponent);
    expectSelectedTab(0);

    await tester.dispatchEvent(
      find.tag('button').first,
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'End')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(find.text('Second panel'), findsOneComponent);
    expectSelectedTab(1);

    await tester.dispatchEvent(
      find.tag('button').at(1),
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowDown')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(find.text('First panel'), findsOneComponent);
    expectSelectedTab(0);

    await tester.dispatchEvent(
      find.tag('button').first,
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowLeft')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(find.text('Second panel'), findsOneComponent);
    expectSelectedTab(1);

    await tester.dispatchEvent(
      find.tag('button').at(1),
      web.KeyboardEvent('keydown', web.KeyboardEventInit(key: 'ArrowUp')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(find.text('First panel'), findsOneComponent);
    expectSelectedTab(0);
  });
}
