import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:universal_web/web.dart' as web;

/// `Modal`'s API from the A2UI v0.9 basic catalog.
class ModalApi extends ComponentApi {
  @override
  String get name => 'Modal';

  @override
  Schema get schema => Schema.object(
    properties: {
      'trigger': CommonSchemas.componentId,
      'content': CommonSchemas.componentId,
    },
    required: ['trigger', 'content'],
  );
}

/// Opens one child in a native HTML dialog when its trigger child is clicked.
class ModalComponent extends JasprComponent {
  /// Creates a [ModalComponent].
  ModalComponent();

  @override
  final ComponentApi api = ModalApi();

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-modal'),
      styles: Styles(raw: {'display': 'contents'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-modal__trigger'),
      styles: Styles(raw: {'display': 'inline-block'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-modal__dialog'),
      styles: Styles(
        raw: {
          'box-sizing': 'border-box',
          'width': 'min(32rem, calc(100% - 2rem))',
          'max-height': 'calc(100% - 2rem)',
          'padding': '1rem',
          'color': 'inherit',
          'background': 'var(--a2ui-surface-color, #ffffff)',
          'border': '1px solid var(--a2ui-border-color, #c4c7c5)',
          'border-radius': '0.5rem',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-modal__dialog::backdrop'),
      styles: Styles(raw: {'background': 'rgb(0 0 0 / 45%)'}),
    ),
    StyleRule(
      selector: Selector('.a2ui-modal__close'),
      styles: Styles(
        raw: {
          'float': 'right',
          'font': 'inherit',
          'cursor': 'pointer',
        },
      ),
    ),
    StyleRule(
      selector: Selector('.a2ui-modal__content'),
      styles: Styles(raw: {'clear': 'both'}),
    ),
  ];

  @override
  Component build(ComponentScope scope) {
    final triggerId = scope.string('trigger');
    final contentId = scope.string('content');

    return _Modal(
      id: scope.instanceId,
      trigger: triggerId == null
          ? const Component.empty()
          : scope.buildChild(triggerId),
      content: contentId == null
          ? const Component.empty()
          : scope.buildChild(contentId),
    );
  }
}

class _Modal extends StatefulComponent {
  const _Modal({
    required this.id,
    required this.trigger,
    required this.content,
  });

  final String id;
  final Component trigger;
  final Component content;

  @override
  State<_Modal> createState() => _ModalState();
}

class _ModalState extends State<_Modal> {
  final _dialog = GlobalNodeKey<web.HTMLDialogElement>();
  var _isOpen = false;

  // A browser owns the dialog node and dispatches the trigger and native close
  // events. The browser suite covers all three paths, including renderer state
  // after explicit and native dismissal.
  // coverage:ignore-start
  void _open() {
    _dialog.currentNode?.showModal();
    setState(() => _isOpen = true);
  }

  void _openFromClick(web.Event _) => _open();

  void _close() {
    _dialog.currentNode?.close();
    setState(() => _isOpen = false);
  }

  void _onNativeClose(web.Event _) {
    if (_isOpen && mounted) setState(() => _isOpen = false);
  }
  // coverage:ignore-end

  @override
  Component build(BuildContext context) {
    return div([
      div(
        [component.trigger],
        classes: 'a2ui-modal__trigger',
        events: {'click': _openFromClick},
      ),
      dialog(
        [
          button(
            const [Component.text('Close')],
            classes: 'a2ui-modal__close',
            type: ButtonType.button,
            onClick: _close,
            attributes: const {'aria-label': 'Close dialog'},
          ),
          div([component.content], classes: 'a2ui-modal__content'),
        ],
        key: _dialog,
        id: '${component.id}-dialog',
        classes: 'a2ui-modal__dialog',
        open: _isOpen,
        events: {'close': _onNativeClose},
      ),
    ], classes: 'a2ui-modal');
  }
}
