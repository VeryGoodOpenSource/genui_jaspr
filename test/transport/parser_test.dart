// Several fixtures below are JSON payloads built from adjacent string
// literals joined with no space, so they match the wire format exactly.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:test/test.dart';

/// Feeds [chunks] through the parser exactly as they arrive, so a test can put
/// the split anywhere it likes.
Future<List<GenerationEvent>> parse(List<String> chunks) {
  return Stream.fromIterable(
    chunks,
  ).transform(const A2uiParserTransformer()).toList();
}

/// As [parse], collecting errors alongside events so a test can see both, and
/// failing the source with [thenFail] after the last chunk when it is given.
Future<({List<GenerationEvent> events, List<Object> errors})> parseAll(
  List<String> chunks, {
  Object? thenFail,
}) async {
  final source = StreamController<String>();
  final events = <GenerationEvent>[];
  final errors = <Object>[];
  final done = Completer<void>();
  source.stream
      .transform(const A2uiParserTransformer())
      .listen(events.add, onError: errors.add, onDone: done.complete);
  chunks.forEach(source.add);
  if (thenFail != null) source.addError(thenFail);
  await source.close();
  await done.future;
  return (events: events, errors: errors);
}

List<String> textsOf(List<GenerationEvent> events) => events
    .whereType<TextEvent>()
    .map((event) => event.text.trim())
    .where((text) => text.isNotEmpty)
    .toList();

/// Every piece of prose joined back together, however the parser split it.
String proseOf(List<GenerationEvent> events) =>
    events.whereType<TextEvent>().map((event) => event.text).join();

List<A2uiMessage> messagesOf(List<GenerationEvent> events) =>
    events.whereType<A2uiMessageEvent>().map((event) => event.message).toList();

const createSurfaceJson = '''
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"c","sendDataModel":true}}''';

void main() {
  group('A2uiParserTransformer', () {
    test('parses a fenced message arriving in one chunk', () async {
      final events = await parse(['```json\n$createSurfaceJson\n```']);

      final messages = messagesOf(events);
      expect(messages, hasLength(1));
      expect(messages.single, isA<CreateSurfaceMessage>());
      expect((messages.single as CreateSurfaceMessage).surfaceId, 'main');
    });

    test('parses a message split across chunk boundaries', () async {
      // The split lands inside the JSON, which is the case that makes buffering
      // necessary at all.
      const whole = '```json\n$createSurfaceJson\n```';
      final events = await parse([
        whole.substring(0, 20),
        whole.substring(20, 45),
        whole.substring(45),
      ]);

      expect(messagesOf(events), hasLength(1));
    });

    test('parses a message split one character at a time', () async {
      const whole = '```json\n$createSurfaceJson\n```';
      final events = await parse(whole.split(''));

      expect(messagesOf(events), hasLength(1));
      expect(textsOf(events), isEmpty);
    });

    test('holds back a chunk that ends inside the fence marker', () async {
      // A boundary here is the awkward case: a search for the full marker finds
      // nothing, so a naive parser shows the stray backticks as prose and then
      // fails to recognise the message.
      final events = await parse([
        'Here you go.\n``',
        '`json\n$createSurfaceJson\n```',
      ]);

      expect(messagesOf(events), hasLength(1));
      expect(textsOf(events), ['Here you go.']);
    });

    test('separates prose around a message from the message itself', () async {
      final events = await parse([
        'Here is a form for you.\n',
        '```json\n$createSurfaceJson\n```',
        '\nLet me know if that works.',
      ]);

      expect(messagesOf(events), hasLength(1));
      expect(textsOf(events), [
        'Here is a form for you.',
        'Let me know if that works.',
      ]);
    });

    test('parses several messages from one stream', () async {
      const update = '''
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[{"id":"root","component":"Text","text":"hi"}]}}''';

      final events = await parse([
        '```json\n$createSurfaceJson\n```\n',
        '```json\n$update\n```',
      ]);

      final messages = messagesOf(events);
      expect(messages, hasLength(2));
      expect(messages[0], isA<CreateSurfaceMessage>());
      expect(messages[1], isA<UpdateComponentsMessage>());
    });

    test(
      'drops the whitespace a model leaves after its last message',
      () async {
        final events = await parse(['```json\n$createSurfaceJson\n```\n\n']);

        expect(events.whereType<TextEvent>(), isEmpty);
        expect(messagesOf(events), hasLength(1));
      },
    );

    test('keeps prose that follows the last message', () async {
      final events = await parse(['```json\n$createSurfaceJson\n```\nDone.']);

      expect(textsOf(events), ['Done.']);
    });

    test('parses a bare message with no fence', () async {
      final events = await parse([createSurfaceJson]);

      expect(messagesOf(events), hasLength(1));
    });

    test('does not end an object at a brace inside a string value', () async {
      // Model-written copy contains braces and quotes. Counting braces without
      // tracking string state would cut the message short here.
      const json =
          '{"version":"v0.9","updateComponents":{"surfaceId":"main",'
          '"components":[{"id":"root","component":"Text",'
          r'"text":"a } brace and a \" quote"}]}}';

      final events = await parse([json]);

      final messages = messagesOf(events);
      expect(messages, hasLength(1));
      expect(
        (messages.single as UpdateComponentsMessage).components.single['text'],
        'a } brace and a " quote',
      );
    });

    test('treats prose with no message as text', () async {
      final events = await parse(['Just talking, no UI this time.']);

      expect(messagesOf(events), isEmpty);
      expect(textsOf(events), ['Just talking, no UI this time.']);
    });

    test('passes through JSON that is not an A2UI message as text', () async {
      final events = await parse(['```json\n{"unrelated":true}\n```']);

      expect(messagesOf(events), isEmpty);
      expect(textsOf(events), ['{"unrelated":true}']);
    });

    test('reports a malformed A2UI message as an error', () async {
      final stream = Stream.fromIterable([
        '```json\n{"version":"v0.9","createSurface":{}}\n```',
      ]).transform(const A2uiParserTransformer());

      await expectLater(stream, emitsError(isA<A2uiValidationException>()));
    });

    test(
      'emits unparseable fenced content as text rather than stalling',
      () async {
        final events = await parse(['```json\n{not valid json at all\n```']);

        expect(messagesOf(events), isEmpty);
        expect(textsOf(events), isNotEmpty);
      },
    );

    test('emits unparseable unfenced content as text', () async {
      // Balanced braces, so the parser takes it for a bare message and only
      // finds out it is not JSON once it tries to decode it.
      final events = await parse(['{not json, just braces}']);

      expect(messagesOf(events), isEmpty);
      expect(textsOf(events), ['{not json, just braces}']);
    });

    group('a stream that ends part-way through a message', () {
      // A model cut off by a safety filter or a token limit stops mid-object.
      // The fragment is a broken message, not prose, so it is reported rather
      // than printed, and the prose before it is kept.
      const fragment =
          '{"version":"v0.9","updateComponents":{"surfaceId":"s",'
          '"components":[{"id":"root","component":"Text","text":"The 12th-';

      test('reports an unclosed fenced message and keeps the prose', () async {
        final outcome = await parseAll(['Here you go.\n\n```json\n$fragment']);

        expect(textsOf(outcome.events), ['Here you go.']);
        expect(outcome.errors, [isA<A2uiValidationException>()]);
      });

      test('reports an unfinished bare message and keeps the prose', () async {
        final outcome = await parseAll(['Here you go: ', fragment]);

        expect(textsOf(outcome.events), ['Here you go:']);
        expect(outcome.errors, [isA<A2uiValidationException>()]);
      });

      test('reports a fenced one after a failure of the source', () async {
        final failure = StateError('the model call broke');
        final outcome = await parseAll([
          'Here you go.\n\n```json\n',
          fragment,
        ], thenFail: failure);

        expect(textsOf(outcome.events), ['Here you go.']);
        expect(outcome.errors, [
          same(failure),
          isA<A2uiValidationException>(),
        ]);
      });

      test('reports a bare one after a failure of the source', () async {
        final failure = StateError('the model call broke');
        final outcome = await parseAll([
          'Here you go: ',
          fragment,
        ], thenFail: failure);

        expect(textsOf(outcome.events), ['Here you go:']);
        expect(outcome.errors, [
          same(failure),
          isA<A2uiValidationException>(),
        ]);
      });

      test('reports an unclosed plain fence holding a message', () async {
        final outcome = await parseAll(['```\n$fragment']);

        expect(textsOf(outcome.events), isEmpty);
        expect(outcome.errors, [isA<A2uiValidationException>()]);
      });

      test('keeps a trailing brace in prose as text', () async {
        final outcome = await parseAll(['Wrap the value in {']);

        expect(proseOf(outcome.events), 'Wrap the value in {');
        expect(outcome.errors, isEmpty);
      });

      test('keeps an unclosed code fence that is not A2UI as text', () async {
        final outcome = await parseAll(['Try this:\n```dart\nvoid main() {']);

        expect(proseOf(outcome.events), 'Try this:\n```dart\nvoid main() {');
        expect(outcome.errors, isEmpty);
      });
    });

    test('parses every message in a JSON array', () async {
      const arrayOfMessages =
          '```json\n[$createSurfaceJson,'
          '{"version":"v0.9","deleteSurface":{"surfaceId":"main"}}]\n```';
      final events = await parse([arrayOfMessages]);

      final messages = messagesOf(events);
      expect(messages, hasLength(2));
      expect(messages.first, isA<CreateSurfaceMessage>());
      expect(messages.last, isA<DeleteSurfaceMessage>());
    });

    test('skips array entries that are not objects', () async {
      final events = await parse([
        '```json\n[$createSurfaceJson, 42, null]\n```',
      ]);

      expect(messagesOf(events), hasLength(1));
    });

    test(
      'reports the version it was given when the version is wrong',
      () async {
        const wrongVersionMessage =
            '```json\n{"version":"v0.8",'
            '"deleteSurface":{"surfaceId":"main"}}\n```';
        final stream = Stream.fromIterable([
          wrongVersionMessage,
        ]).transform(const A2uiParserTransformer());

        // The underlying message names the version it actually saw.
        // Replacing it with the generic "must have a version field" text
        // would hide that.
        await expectLater(
          stream,
          emitsError(
            isA<A2uiValidationException>().having(
              (error) => error.message,
              'message',
              contains("got 'v0.8'"),
            ),
          ),
        );
      },
    );

    test('pauses and resumes the source while the output is paused', () async {
      final input = StreamController<String>();
      final events = <GenerationEvent>[];
      final subscription = input.stream
          .transform(const A2uiParserTransformer())
          .listen(events.add);

      input.add('Thinking. ');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));

      subscription.pause();
      input.add('```json\n$createSurfaceJson\n```');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1), reason: 'paused output must not be fed');

      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<A2uiMessageEvent>(), hasLength(1));

      await input.close();
      await subscription.cancel();
    });
  });

  group('A2uiValidationException', () {
    test('prints only its message when there is nothing underneath', () {
      final error = A2uiValidationException('Bad message');

      expect(error.toString(), 'A2uiValidationException: Bad message');
    });

    test('prints the cause and the payload when it has them', () {
      final error = A2uiValidationException(
        'Bad message',
        json: {'version': 'v0.8'},
        cause: 'the underlying complaint',
      );

      expect(
        error.toString(),
        'A2uiValidationException: Bad message\n'
        'Cause: the underlying complaint\n'
        'JSON: {version: v0.8}',
      );
    });
  });
}
