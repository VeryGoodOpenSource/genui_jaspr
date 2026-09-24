import 'package:a2ui_core/a2ui_core.dart';
import 'package:genkit/client.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr_example/catalog.dart';
import 'package:genui_jaspr_example/interaction.dart';
import 'package:genui_jaspr_example/server/chat_path.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/js_interop.dart';
import 'package:universal_web/web.dart' as web;

/// One entry in the transcript: something the user said, or a model's reply.
class Turn {
  /// A turn holding what the user typed.
  Turn.user(this.text) : events = null;

  /// A turn holding a model reply's events.
  Turn.model(this.events) : text = ''; // coverage:ignore-line

  /// The user's text, or the empty string for a model's turn.
  final String text;

  /// The model's reply as a stream of events, which the transcript's
  /// [ReplyBuilder] folds into a [Reply]. Null for the user's turns.
  final Stream<GenUiEvent>? events;
}

/// What the user is shown when a reply fails, whatever the cause.
const String failedTurnMessage =
    'The model stopped before finishing. Try again, or ask a different way.';

/// Streams the model's reply to [prompt] as text chunks.
///
/// The seam [ChatView] is tested at: production passes the genkit client,
/// a browser test passes a fake and never touches the network.
typedef SendPrompt = Stream<String> Function(String prompt);

/// The conversation, running entirely in the browser.
///
/// A generated surface only exists once the model has answered something the
/// user did, so there is nothing for the server to pre-render. The server's
/// job is to hold the API key and stream text back, which it does through
/// the route this talks to.
///
/// A `@client` component's parameters must serialize for hydration, so the
/// injectable send function cannot live here. This stays the param-free client
/// boundary and [ChatView] carries the seam.
@client
class Chat extends StatefulComponent {
  /// Creates the [Chat] client boundary.
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  /// One chat with the agent behind the server route, for the life of the page.
  ///
  /// The agent keeps this session's history on the server, so every turn the
  /// model sees the UI it built earlier and can make sense of an interaction
  /// with it. The browser holds nothing but the session's id, inside [_chat].
  final AgentChat<dynamic> _chat = remoteAgent<dynamic>(
    url: '/$chatPath',
  ).chat();

  @override
  Component build(BuildContext context) {
    return ChatView(
      // Only a live server exercises this: the browser tests hand ChatView a
      // stand-in for the model, and the round-trip test drives the agent from
      // the VM.
      // coverage:ignore-start
      send: (prompt) => _chat
          .sendStream(text: prompt)
          .stream
          .map((chunk) => chunk.text)
          .where((text) => text.isNotEmpty),
      // coverage:ignore-end
    );
  }
}

/// The conversation UI, talking to the model only through [send].
class ChatView extends StatefulComponent {
  /// Creates a [ChatView] that sends prompts through [send].
  const ChatView({required this.send, super.key});

  /// Sends a prompt to the model and streams back its reply.
  final SendPrompt send;

  @override
  State<ChatView> createState() => _ChatViewState();
}

// The `coverage:ignore` markers in this file mark dart2js source-map artifacts:
// the browser suite executes those lines, but dart2js folds them into a
// neighbouring line in its source map, so no platform's line table can
// attribute them. Editing this file can shift which lines fold; move the
// marker with the line. tool/merge_lcov.dart explains how the VM and Chrome
// reports combine.
class _ChatViewState extends State<ChatView> {
  late final GenUiConversation _conversation;

  final List<Turn> _turns = [];
  String _draft = '';
  bool _busy = false;
  String? _error;

  /// Replies are numbered so each renders into its own surface.
  int _replies = 0;

  /// An empty element after the last turn, scrolled into view to follow the
  /// conversation.
  ///
  /// Scrolling to an anchor rather than to a computed offset means the browser
  /// works out the distance, which matters here because a generated surface's
  /// height is not known until it has been laid out.
  final _end = GlobalNodeKey<web.Element>();

  @override
  void initState() {
    super.initState();
    _conversation = GenUiConversation(
      catalogs: [appCatalog],
      onAction: _onSurfaceAction,
    );
  }

  // coverage:ignore-start
  @override
  void dispose() {
    _conversation.dispose();
    super.dispose();
  }
  // coverage:ignore-end

  /// A button in a generated surface was pressed.
  ///
  /// The interaction becomes the next thing the model hears, along with
  /// whatever the user typed into that surface, which the data model already
  /// holds.
  void _onSurfaceAction(A2uiClientAction action) {
    _send(
      _conversation.actionText(action), // coverage:ignore-line
      show: summariseInteraction(action), // coverage:ignore-line
    );
  }

  void _sendDraft() {
    final text = _draft.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _draft = '');
    _send(text, show: text);
  }

  void _send(String prompt, {required String show}) {
    if (_busy) return;

    // Each reply renders into a surface named here rather than one the model
    // invents, so a model that reuses an id cannot overwrite an earlier answer.
    // The ReplyBuilder in the transcript is the stream's one listener; it
    // reports back through [_onReplyComplete] when the reply has ended.
    // coverage:ignore-start
    final events = _conversation.receive(
      component.send(prompt),
      surfaceId: 'reply${_replies++}',
    );
    // coverage:ignore-end

    setState(() {
      _busy = true;
      _error = null;
      _turns
        ..add(Turn.user(show))
        ..add(Turn.model(events));
    });
  }

  /// The model has finished [turn], cleanly or not.
  void _onReplyComplete(Turn turn, Reply reply) {
    setState(() {
      _busy = false;
      final failure = reply.failure;
      if (failure != null) {
        // The browser never learns why a call failed: the server turns every
        // cause into the same 500. So the user gets a plain message, and the
        // failure itself goes to the console for whoever is debugging.
        _error = failedTurnMessage;
        web.console.error('Reply failed: $failure'.toJS);
      }
      // A turn with neither words nor a surface would render as an empty
      // bubble, which is what a failed request used to leave behind.
      if (reply.isEmpty) _turns.remove(turn);
    });
  }

  /// Follows the conversation after the next frame is laid out.
  ///
  /// Reading the DOM before then would measure the previous content. The key
  /// yields null when there is no browser, so this is inert during server
  /// rendering.
  void _followConversation(BuildContext context) {
    context.binding.addPostFrameCallback(() {
      _end.currentNode?.scrollIntoView(
        // coverage:ignore-start
        web.ScrollIntoViewOptions(behavior: 'smooth', block: 'end'),
        // coverage:ignore-end
      );
    });
  }

  @override
  Component build(BuildContext context) {
    _followConversation(context);
    return div([
      div([
        for (final turn in _turns) _turnView(turn),
        if (_busy) const p([Component.text('Thinking...')], classes: 'status'),
        if (_error != null)
          p(
            [Component.text(_error!)],
            classes: 'error',
            attributes: const {'role': 'alert'},
          ),
        div(const [], key: _end, classes: 'transcript__end'),
      ], classes: 'transcript'),
      _composer(),
    ], classes: 'chat');
  }

  Component _turnView(Turn turn) {
    final events = turn.events;
    if (events == null) {
      return div([
        p([Component.text(turn.text)]),
      ], classes: 'turn turn--user');
    }
    // The builder folds the events as they arrive, so the bubble fills in
    // while the model is still writing.
    return ReplyBuilder(
      events: events,
      onComplete: (reply) => _onReplyComplete(turn, reply),
      builder: (context, reply) {
        if (reply.isEmpty) return const Component.empty();
        return div([
          if (reply.text.trim().isNotEmpty) p([Component.text(reply.text)]),
          for (final surface in reply.surfaces) Surface(surface: surface),
          for (final error in reply.errors)
            p([Component.text(error.message)], classes: 'error'),
        ], classes: 'turn turn--model');
      },
    );
  }

  /// The prompt bar, pinned to the bottom of the viewport.
  ///
  /// It is a real form with a submit button, which is what makes Enter send
  /// the prompt. The browser's implicit submission handles the keystroke, so
  /// there is no key handling here, and clicking the button takes the same
  /// path.
  Component _composer() {
    return div([
      form(
        [
          input<String>(
            type: InputType.text,
            value: _draft,
            disabled: _busy,
            attributes: const {
              'placeholder': 'Ask for a form, a quiz, a checklist',
              'autocomplete': 'off',
            },
            onInput: (value) => _draft = value,
            onChange: (value) => _draft = value,
          ),
          button(
            const [Component.text('Send')],
            type: ButtonType.submit,
            disabled: _busy,
          ),
        ],
        classes: 'composer__inner',
        events: {
          'submit': (event) {
            // Without this the browser navigates and the page reloads.
            event.preventDefault();
            _sendDraft();
          },
        },
      ),
    ], classes: 'composer');
  }
}
