@TestOn('browser')
library;

import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr_example/catalog.dart';
import 'package:genui_jaspr_example/chat.dart';
import 'package:jaspr_test/client_test.dart';

/// A model reply carrying one A2UI message, fenced the way the parser expects.
String fenced(String json) => '```json\n$json\n```\n';

/// What the user is shown when a reply fails, whatever the cause.
const plainFailureText =
    'The model stopped before finishing. Try again, or ask a different way.';

void main() {
  group('ChatView in a browser', () {
    testClient('typing and sending renders the streamed reply', (tester) async {
      final prompts = <String>[];
      tester.pumpComponent(
        ChatView(
          send: (prompt) {
            prompts.add(prompt);
            return Stream.fromIterable(['Hello ', 'there']);
          },
        ),
      );

      await tester.input(find.tag('input'), value: 'hi');
      await tester.click(find.tag('button'));

      expect(prompts, ['hi']);
      expect(find.text('Hello there'), findsOneComponent);
    });

    testClient('a click in a generated surface becomes the next turn', (
      tester,
    ) async {
      final prompts = <String>[];
      tester.pumpComponent(
        ChatView(
          send: (prompt) {
            prompts.add(prompt);
            if (prompts.length > 1) {
              return Stream.fromIterable(['Done.']);
            }
            return Stream.fromIterable([
              'Here you go.\n',
              fenced(
                '{"version":"v0.9","createSurface":{"surfaceId":"s",'
                '"catalogId":"${appCatalog.id}",'
                '"sendDataModel":true}}',
              ),
              fenced(
                '{"version":"v0.9","updateComponents":{"surfaceId":"s",'
                '"components":['
                '{"id":"root","component":"Button","child":"label",'
                '"action":{"event":{"name":"submit"}}},'
                '{"id":"label","component":"Text","text":"Do it"}]}}',
              ),
            ]);
          },
        ),
      );

      await tester.input(find.tag('input'), value: 'make a button');
      await tester.click(find.tag('button'));

      expect(find.text('Do it'), findsOneComponent);

      await tester.click(
        find.ancestor(of: find.text('Do it'), matching: find.tag('button')),
      );

      // The interaction reaches the model as the protocol's action message.
      expect(prompts, hasLength(2));
      expect(prompts.first, 'make a button');
      expect(prompts.last, contains('"action"'));
      expect(prompts.last, contains('"name":"submit"'));
      expect(find.text('Submitted "submit"'), findsOneComponent);
      expect(find.text('Done.'), findsOneComponent);
    });

    testClient('a message the model got wrong is shown in its turn', (
      tester,
    ) async {
      tester.pumpComponent(
        ChatView(
          send: (prompt) => Stream.fromIterable([
            'Trying.\n',
            fenced('{"version":"v0.8","createSurface":{"surfaceId":"s"}}'),
          ]),
        ),
      );

      await tester.input(find.tag('input'), value: 'anything');
      await tester.click(find.tag('button'));

      expect(find.textContaining('Trying.'), findsOneComponent);
      expect(find.textContaining('v0.9'), findsOneComponent);
    });

    testClient('a failing request is reported, not rendered as a turn', (
      tester,
    ) async {
      tester.pumpComponent(
        ChatView(
          send: (prompt) =>
              Stream<String>.error(StateError('model unavailable')),
        ),
      );

      await tester.input(find.tag('input'), value: 'hi');
      await tester.click(find.tag('button'));

      expect(find.text(plainFailureText), findsOneComponent);
      // The raw failure is for developers, in the console, not for the user.
      expect(find.textContaining('model unavailable'), findsNothing);
      // The user's own turn stays; the failed reply leaves no empty bubble.
      expect(find.text('hi'), findsOneComponent);
      expect(find.byType(Surface), findsNothing);
    });

    testClient('a reply cut off mid-message keeps its prose, not the JSON', (
      tester,
    ) async {
      // What Gemini does when its recitation filter stops a reply: the prose
      // arrives, the message starts, and then the call fails.
      tester.pumpComponent(
        ChatView(
          send: (prompt) async* {
            yield 'Here is Paris.\n\n```json\n';
            yield '{"version":"v0.9","updateComponents":{"surfaceId":"s",'
                '"components":[{"id":"root","component":"Text",'
                '"text":"The 12th-';
            throw StateError('GenkitException: Internal server error');
          },
        ),
      );

      await tester.input(find.tag('input'), value: 'Tell me about Paris');
      await tester.click(find.tag('button'));

      expect(find.textContaining('Here is Paris.'), findsOneComponent);
      expect(find.textContaining('ended part-way'), findsOneComponent);
      expect(find.text(plainFailureText), findsOneComponent);
      expect(find.textContaining('updateComponents'), findsNothing);
      expect(find.textContaining('GenkitException'), findsNothing);
    });
  });
}
