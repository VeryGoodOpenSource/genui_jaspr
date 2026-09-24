# genui_jaspr

Render [A2UI](https://a2ui.org) generative user interfaces in
[Jaspr](https://jaspr.site), so your web app can offer a generative UI without
shipping Flutter web.

## What generative UI is

Ask a chat assistant to help you book a flight and you get a wall of text: a
list of options to read, questions to answer by typing, and a summary you have
to check by hand. Everything the app knows how to display, its date pickers and
forms and lists, sits unused next to the chat box, because the model can only
produce prose.

Generative UI lets the model answer with an interface instead. The app publishes
a catalog of components it knows how to render, and the model composes them at
runtime: a form with the right fields, a quiz, a checklist, a set of options as
buttons. What the user types or picks flows back to the model on the next turn,
so the conversation continues through the UI rather than around it. The model
never writes code and never draws anything the catalog does not offer, so what
appears on screen is always something the app chose to make possible.

A2UI is the protocol for this. A model emits small JSON messages that open a
surface, fill it with components, and update the data behind them, and the
client sends back the user's actions and entries. Flutter has an A2UI renderer in
the [`genui`](https://github.com/flutter/genui/tree/main/packages/genui) package.
This package is the Jaspr counterpart: the same messages, rendered to real HTML,
so headings are headings, inputs are inputs, and the browser supplies its own
keyboards, validation, and focus handling. Both build on
[`a2ui_core`](https://pub.dev/packages/a2ui_core), the pure Dart protocol
runtime, so they speak exactly the same messages.

## What it gives you

- `GenUiConversation` owns the surfaces a model builds and everything the user
  types into them. Hand it each reply as a stream of text and it gives you back
  a stream of events: the prose, each surface the model opens, and each
  mistake it makes.
- `ReplyBuilder` folds that stream into a `Reply` and rebuilds as it arrives,
  and `Surface` renders each surface and keeps rendering as messages land, so a
  form appears while the model is still writing it.
- `BasicJasprCatalog`, with all 18 components, all 14 functions, and the theme
  from the A2UI standard catalog. `MinimalJasprCatalog` remains available when
  five components and one small string function are enough.
- A `styles` getter on any `Catalog<JasprComponent>`, added by the
  `JasprCatalogComposition` extension, which gathers the default rules of the
  components that catalog holds. Use them, extend them, or replace them. A
  catalog derived with `copyWith` carries the rules for what it actually has.
- `a2uiInstructions`, which writes the protocol half of your system prompt from
  the catalog, so what the model is told it may send and what the renderer can
  draw cannot drift apart.
- `actionText`, which gives you exactly what to send the model when the user
  presses a generated button, in the shape the protocol defines, with what the
  user entered alongside.

## Getting started

Add the package, and `a2ui_core` for the protocol types you will meet in
callbacks:

```sh
dart pub add genui_jaspr a2ui_core
```

Pick your catalog once and hold it. The styles you ship and the components the
renderer can draw both come from it, so one value is what keeps them in step:

```dart
final catalog = BasicJasprCatalog();

runApp(Document(styles: [...catalog.styles, ...myStyles], body: MyApp()));
```

The package styles the components and nothing else. The surface wrapper
(`.a2ui-surface`) and the renderer's missing-component fallback (`.a2ui-missing`)
belong to no component, so their appearance is yours to set.

Then create one conversation and render its replies. This runs in the browser,
under a `@client` component, because a generated surface only exists once the
model has answered.

One thing this package does not do is call a model. The component below takes
a `send` function that returns the model's reply as a stream of text chunks, and
what that function does is yours to decide. In the sample app it is Genkit's
browser client talking to a Genkit agent behind a server route, so the API key
stays on the server and the agent keeps the conversation's history:

```dart
final AgentChat<dynamic> chat = remoteAgent(url: '/api/chat').chat();

Stream<String> send(String prompt) => chat
    .sendStream(text: prompt)
    .stream
    .map((chunk) => chunk.text)
    .where((text) => text.isNotEmpty);
```

That is [`example/lib/chat.dart`](example/lib/chat.dart) on the browser side and
[`example/lib/server/chat_agent.dart`](example/lib/server/chat_agent.dart) on the
server side. Anything that yields the text as it arrives will do in its place: a
`fetch` to your own endpoint, a different SDK, or a canned stream in a test.

```dart
import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';

class ChatView extends StatefulComponent {
  const ChatView({required this.send, super.key});

  /// Sends a prompt to the model and streams its reply back as text chunks.
  /// See above for where this comes from.
  final Stream<String> Function(String prompt) send;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final GenUiConversation _conversation;
  /// One event stream per model turn. ReplyBuilder folds each into a Reply.
  final List<Stream<GenUiEvent>> _events = [];

  @override
  void initState() {
    super.initState();
    _conversation = GenUiConversation(
      catalogs: [catalog],
      // A button in a generated surface was pressed. Tell the model.
      onAction: (action) => _ask(_conversation.actionText(action)),
    );
  }

  void _ask(String prompt) {
    final Stream<GenUiEvent> events = _conversation.receive(component.send(prompt));
    setState(() => _events.add(events));
  }

  @override
  Component build(BuildContext context) {
    return div([
      for (final events in _events)
        // Folds the events into a Reply as they arrive, so this re-renders as
        // the model writes.
        ReplyBuilder(
          events: events,
          builder: (context, reply) => div([
            // The model's own words, outside any surface.
            p([Component.text(reply.text)]),
            // The UI it built.
            for (final surface in reply.surfaces) Surface(surface: surface),
          ]),
        ),
    ]);
  }

  @override
  void dispose() {
    _conversation.dispose();
    super.dispose();
  }
}
```

That's the whole loop. The user asks, the model answers, and a press on a
generated button comes back through `onAction` as the next prompt.

A reply has two parts, and the snippet renders them differently on purpose. The
model's conversational words, "Here's a short form to get started", are prose
the model wrote outside any surface, so they arrive in `reply.text` and the app
shows them however its transcript looks, here as a paragraph. The UI the model
built arrives as surfaces, and only `Surface` renders those, so a surface holds
exactly what the model put on screen and nothing the app added around it. If you
would rather the model said nothing outside the UI, tell it so in your system
prompt and skip the paragraph.

## Usage

### Choosing a catalog

`BasicJasprCatalog()` implements the complete pinned A2UI v0.9 standard
catalog. Its one constructor always includes `Icon`, backed by a private table
of the 59 names that catalog permits,
rendered as inline 24px SVG using `currentColor`. It does not load a font, make
a network request, or add an icon package to your app at runtime. It is the
`catalog` the snippets above build.

Constructing that catalog keeps all 59 paths, because any standard `Icon`
message can arrive at runtime. `MinimalJasprCatalog()` remains the
five-component option and does not include `Icon`. Importing this package or
using only the minimal catalog means the built-in icon paths are tree-shaken
from a production web build; a compiler regression test protects that boundary.

The standard `openUrl` function accepts any valid URI, as the protocol
specifies. Pass `urlOpener` when the host application needs to allow only
particular schemes or domains. The injected callback runs synchronously in the
user action and also makes navigation straightforward to test:

```dart
final catalog = BasicJasprCatalog(
  urlOpener: (uri) {
    if (uri.scheme == 'https') openTrustedUrl(uri);
  },
);
```

### Teaching the model the protocol

The model has to be told how to speak A2UI to your app, and it has to be told
exactly which components exist. `a2uiInstructions` writes that half of the
system prompt from the catalog. You write the other half, which is what your
assistant is for and how it should sound:

```dart
final systemPrompt = [
  'You help people plan trips. Reply with a sentence, then the UI.',
  a2uiInstructions(catalog),
].join('\n\n');
```

It imports nothing from Jaspr, so it runs on the server that holds your prompt
just as well as in the browser.

### Following a reply

`receive` returns a `Stream<GenUiEvent>`, single-subscription and lazy, so
nothing is parsed until something listens. Three kinds of event arrive:
`GenUiText` carries a piece of prose, `GenUiSurface` carries a surface the model
has just opened, once, and `GenUiError` carries a message the model got wrong,
such as a component the catalog lacks, a surface created twice, or a message cut
off when the reply ended, already in the shape `a2uiErrorMessage` sends back to
the model. The stream carries on after a `GenUiError`. A failure of the model
call itself is an error on the stream, which then ends.

`ReplyBuilder` is the fold most apps want: it turns the events into a `Reply`
with `text`, `surfaces`, `errors`, `failure`, and `isComplete`, and rebuilds its
subtree on each event. Keep the stream in state and hand the same instance to
the builder on every build, since a new instance makes it resubscribe and a
reply can only be listened to once. The builder is that one listener, so when
something else needs to know how the reply ended, such as a transcript
re-enabling its composer, give the builder an `onComplete` callback rather than
subscribing a second time. Like every stream builder in Jaspr it runs only in
the browser, which is where a reply exists anyway.

Outside a component, the same fold is an extension on the stream:
`events.replies` is a `Stream<Reply>` with one snapshot per event, and
`events.reply` is a `Future<Reply>` of the finished one. Neither throws; a
failed model call arrives as `Reply.failure`.

Actions, errors raised after a reply has ended, and surfaces the model deletes
are single events rather than sequences, so they reach the app through the
conversation's `onAction`, `onError`, and `onSurfaceDeleted` callbacks.

Pass `surfaceId` to `receive` to render each reply into a surface your app
names. A model that reuses an id across turns then cannot overwrite an earlier
answer, which is what a chat transcript wants, and it pairs with the default
`a2uiInstructions`, which tells the model to open a new surface every reply.
Leave `surfaceId` out to let the model manage surface ids itself, and pass
`allowUpdates: true` to `a2uiInstructions` so it knows it may revise a surface
from an earlier turn.

A backend that delivers A2UI already parsed, such as an A2A agent, goes through
`receiveMessages` instead. The protocol runtime is a public field,
`conversation.processor`, for anything the conversation does not cover.

### Adding a component

A component is a `JasprComponent`. It is its own `a2ui_core` API, so one class
declares the name, the schema that decides how each property binds, a `build`
method that turns resolved properties into HTML, and the style rules for the
classes that `build` emits:

```dart
class DividerComponent extends JasprComponent {
  const DividerComponent();

  @override
  String get name => 'Divider';

  @override
  Schema get schema => Schema.object(properties: {});

  @override
  Component build(ComponentScope scope) => hr(classes: 'a2ui-divider');

  @override
  List<StyleRule> get styles => const [
    StyleRule(
      selector: Selector('.a2ui-divider'),
      styles: Styles(raw: {'border': 'none', 'height': '1px'}),
    ),
  ];
}
```

Declaring `styles` next to the `build` that emits the class is what keeps a
catalog's bundle complete. Leave it out and the component still renders; it just
contributes no rules, and a host stylesheet supplies them instead.

Then derive a catalog. Give the copy its own id, since that id is what the model
is told to target, and `a2uiInstructions` will describe the new component from
its schema:

```dart
final catalog = MinimalJasprCatalog().copyWith(
  id: 'com.example.catalog',
  add: [const DividerComponent()],
);
```

`catalog.styles` now carries the divider's rule along with the minimal
components'. That is the point of deriving the bundle from the catalog rather
than writing it out: there is no second list to remember to update.

When the API is defined somewhere else, extend `ExternalApiJasprComponent` and
pass it up instead of restating its schema. The minimal catalog's components do
this with the API classes `a2ui_core` ships, so what the model is told it may
send and what the renderer draws come from the same definition:

```dart
class TextComponent extends ExternalApiJasprComponent {
  TextComponent() : super(MinimalTextApi());

  @override
  Component build(ComponentScope scope) =>
      p([Component.text(scope.string('text') ?? '')]);
}
```

`build` gets a `ComponentScope` with the properties already resolved: data
bindings read, function calls evaluated, actions turned into callbacks. Read a
value with `scope.string`, children with `scope.children()`, and the callback
behind an action property with `scope.action`, which reports a failure to the
surface instead of throwing out of a click handler. For a one-off, or in a test,
`JasprComponent.inline(api, build, styles: rules)` takes the parts as arguments
without a class of their own. `styles` is optional and defaults to none.

A component the catalog does not implement renders a visible notice rather than
throwing, so one unknown component does not take down the surface around it.
`Surface.fallback` replaces that notice with whatever fits your app, and
`Surface.placeholder` fills the moment between a surface being created and its
components arriving.

### Styling

Components emit stable class names, all prefixed `a2ui-`. Two kinds of styling
are deliberately kept apart:

- Layout the model chose per component, such as `justify` and `align`, is written
  inline, because it varies per instance and cannot live in a stylesheet.
- Appearance goes through class names, so a catalog's `styles` can be replaced
  wholesale without touching the renderer. A component declares the rules for
  the classes it emits, which is how the bundle stays correct for any catalog.

A surface publishes the theme from its `createSurface` message as CSS custom
properties on its root element, kebab-cased and `--a2ui-` prefixed. So
`{"primaryColor": "#0b57d0"}` arrives as `--a2ui-primary-color`, which is how a
static stylesheet reacts to a colour the model picked at runtime.

### Rendering on the server

The renderer reaches the DOM only through `universal_web`, the same stubs Jaspr
uses, so it compiles on the server. A generated surface still cannot be
server-rendered in any useful way, because it only exists once the model has
answered something the user did. Render the shell on the server and let a
`@client` component own the conversation, which is what the example does.

## Running the sample app

The example is a Jaspr app with a server-rendered shell, the chat as a `@client`
component, and the model behind a Genkit agent on the server, so the API key
never reaches the browser and the agent keeps each conversation's history.

```sh
dart pub global activate jaspr_cli
export GEMINI_API_KEY=...              # or GOOGLE_API_KEY
cd example
dart run build_runner build            # generates the client and server options
jaspr serve
```

Then open http://localhost:8080 and ask for something: "a signup form", "a
three-question quiz", "a checklist for moving house".

It uses `gemini-3.5-flash-lite`. Set `MODEL` to try another:

```sh
MODEL=gemini-3.5-flash jaspr serve
```

The example's own [README](example/README.md) walks through its pieces.

## Contributing

Issues and pull requests are welcome at
https://github.com/brianegan/genui_jaspr. [CONTRIBUTING.md](CONTRIBUTING.md)
has the test commands and explains how the suites fit together.

- A2UI protocol: https://a2ui.org
- Jaspr: https://jaspr.site
- Flutter's genui: https://github.com/flutter/genui
