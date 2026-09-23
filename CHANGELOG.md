## 0.1.0

First release. Renders A2UI generative user interfaces in Jaspr, building on
`a2ui_core` for the protocol runtime.

- `GenUiConversation` owns the surfaces of one conversation and turns each model
  reply into a `Stream<GenUiEvent>`: `GenUiText` for prose, `GenUiSurface` for
  each surface the model opens, and `GenUiError` for each message it got wrong.
  Actions, later errors, and deleted surfaces reach the app through the
  `onAction`, `onError`, and `onSurfaceDeleted` callbacks. `receiveMessages`
  takes A2UI that arrives already parsed, and `actionText` composes the text a
  chat app sends the model after an interaction.
- `ReplyBuilder` folds a reply's events into a `Reply` and rebuilds as they
  arrive, built on Jaspr's `StreamBuilderBase`, with `onComplete` for the
  finished reply. Outside a component, `Stream<GenUiEvent>.replies` and
  `.reply` do the same fold.
- `a2uiActionMessage`, `a2uiErrorMessage`, and `clientErrorFrom` produce the
  client-to-server envelopes the protocol defines.
- `a2uiInstructions` writes the protocol half of a system prompt from a catalog,
  so the model is told exactly what the renderer can draw. Its `allowUpdates`
  flag matches the two ways `receive` can treat surface ids.
- `Surface` renders a surface and fills in as messages arrive, with `placeholder`
  and `fallback` builders for the moments before a root exists and for a
  component the catalog cannot render.
- `MinimalJasprCatalog` renders the five components of the A2UI minimal catalog,
  `TextComponent`, `RowComponent`, `ColumnComponent`, `ButtonComponent`, and
  `TextFieldComponent`. Schemas and the catalog id come from `a2ui_core`
  unchanged. `JasprComponent` is the base class for a component of your own,
  declaring its name and schema alongside `build`. `ExternalApiJasprComponent`
  renders an API defined elsewhere, as the minimal components do with
  `a2ui_core`'s. `copyWith` derives a catalog from an existing one.
- `ComponentScope` hands a builder its resolved properties, its children, and a
  way to report errors. An action obtained through it never throws out of a
  click handler. Its `instanceId` is unique to each rendered instance across
  the page, so DOM ids and radio group names derived from it stay distinct
  between surfaces and between rows of a template.
- `JasprComponent.styles` declares the default rules for the classes a
  component emits, and the `styles` getter `JasprCatalogComposition` adds to a
  `Catalog<JasprComponent>` gathers them, so a catalog derived with `copyWith`
  carries the right bundle. `JasprComponent.inline` takes them too.
  Surface-level markup is left unstyled for the app to own. A surface publishes
  its theme as CSS custom properties.
- `A2uiParserTransformer` turns a model's text stream into prose and A2UI
  messages, buffering across chunk boundaries, for apps that want the raw events.
- The example app serves a server-rendered shell with the conversation as a
  `@client` component, and a Genkit agent served by `genkit_shelf` that keeps
  each conversation's history in a session store.
