import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

import 'package:genui_jaspr/src/transport/generation_events.dart';

/// Turns a model's text stream into a stream of prose and A2UI messages.
///
/// A model writes both in one channel, and its chunks split wherever the
/// network happens to break them, often in the middle of a JSON object. This
/// buffers until a message is complete, so a surface can be updated as soon
/// as one arrives rather than after the whole response.
///
/// A stream that ends part-way through a message, because a safety filter or
/// a token limit stopped the model or the call failed, reports the fragment as
/// an [A2uiValidationException] rather than showing it as prose.
class A2uiParserTransformer
    extends StreamTransformerBase<String, GenerationEvent> {
  /// Creates an [A2uiParserTransformer].
  const A2uiParserTransformer();

  @override
  Stream<GenerationEvent> bind(Stream<String> stream) =>
      _ParserStream(stream).stream;
}

class _ParserStream {
  _ParserStream(Stream<String> input) {
    _controller = StreamController<GenerationEvent>(
      onListen: () {
        _subscription = input.listen(
          _onData,
          onError: _controller.addError,
          onDone: _onDone,
          cancelOnError: false,
        );
      },
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: () => _subscription?.cancel(),
    );
  }

  late final StreamController<GenerationEvent> _controller;
  StreamSubscription<String>? _subscription;
  String _buffer = '';

  /// Whether the last thing emitted was a message.
  ///
  /// Models often separate consecutive messages with a blank line. After a
  /// message, whitespace is that separator rather than prose worth showing.
  bool _lastEventWasMessage = false;

  Stream<GenerationEvent> get stream => _controller.stream;

  void _onData(String chunk) {
    _buffer += chunk;
    _processBuffer();
  }

  void _onDone() {
    final leftover = _buffer;
    _buffer = '';
    if (_isUnfinishedMessage(leftover)) {
      // The model stopped part-way through a message, cut off by a safety
      // filter, a token limit, or a failed call. Printed as prose it would
      // put raw JSON in front of the user, so it is reported as the broken
      // message it is.
      _controller.addError(
        A2uiValidationException(
          'The reply ended part-way through an A2UI message',
          json: leftover,
        ),
      );
    } else if (leftover.isNotEmpty &&
        !(_lastEventWasMessage && leftover.trim().isEmpty)) {
      // Whatever is left is prose, unless it is only the whitespace a model
      // puts after its last message, which the separator rule drops
      // everywhere else.
      _emitText(leftover);
    }
    unawaited(_controller.close());
  }

  /// Whether [leftover], what the buffer still holds when the stream ends, is
  /// the start of a message rather than prose.
  ///
  /// Besides a possible message, which opens with a fence or a brace, the
  /// buffer can hold back a partial fence marker or the whitespace after a
  /// message. Neither is a message, and both are left to the prose rule. A
  /// `json` fence says it is a message outright. A brace or any other fence
  /// counts only once it names a message, so a reply that ends on a stray
  /// brace or an unrelated code block still shows it.
  bool _isUnfinishedMessage(String leftover) {
    if (leftover.startsWith('```json')) return true;
    if (!leftover.startsWith('```') && !leftover.startsWith('{')) return false;
    return _messageKeys.any((key) => leftover.contains('"$key"'));
  }

  void _processBuffer() {
    while (_buffer.isNotEmpty) {
      if (_consumeFenced()) continue;
      if (_consumeBareObject()) continue;
      if (_awaitMoreInput()) break;
    }
  }

  /// Consumes a ```` ```json ```` block, if the buffer holds a complete one.
  bool _consumeFenced() {
    final found = _findFenced(_buffer);
    if (found == null) return false;

    try {
      final Object? decoded = jsonDecode(found.content);
      if (decoded == null) return false;
      _emitTextBefore(found.start);
      _emitDecoded(decoded);
    } on FormatException {
      // The fence closed around something that is not JSON. Show it as
      // prose and move past it, rather than waiting for input that will
      // never fix it.
      _emitTextBefore(found.start);
      _emitText(found.original);
    }
    _buffer = _buffer.substring(found.end);
    return true;
  }

  /// Consumes a bare JSON object at the start of the buffer, for models that
  /// emit messages without fencing them.
  bool _consumeBareObject() {
    final found = _findBalancedObject(_buffer);
    if (found == null) return false;

    try {
      final Object? decoded = jsonDecode(found.content);
      if (decoded == null) return false;
      _emitTextBefore(found.start);
      _emitDecoded(decoded);
    } on FormatException {
      _emitTextBefore(found.start);
      _emitText(found.original);
    }
    _buffer = _buffer.substring(found.end);
    return true;
  }

  /// Decides what to do with a buffer holding no complete message.
  ///
  /// Returns true when the parser should stop and wait for more input.
  bool _awaitMoreInput() {
    final start = _firstPossibleMessageStart();

    if (start == -1) {
      // A chunk can end part-way through a fence marker, leaving one or two
      // backticks that a search for the full marker will not find. Hold that
      // fragment back, or it surfaces as prose and the message that follows it
      // is never recognised.
      final partial = _trailingBacktickCount();
      if (partial > 0) {
        final prefix = _buffer.substring(0, _buffer.length - partial);
        _buffer = _buffer.substring(_buffer.length - partial);
        // The separator rule applies here too. Without it, the blank line
        // before a fence is shown as prose whenever a chunk happens to end
        // inside the marker, so the same reply reads differently depending
        // on chunk size.
        if (!(_lastEventWasMessage && prefix.trim().isEmpty)) {
          _emitText(prefix);
        }
        return true;
      }

      // Nothing here could become a message.
      if (_lastEventWasMessage && _buffer.trim().isEmpty) {
        // Hold the separator, in case the stream ends and it turns out to
        // be all that is left.
        return true;
      }
      _emitText(_buffer);
      _buffer = '';
      return true;
    }

    if (start > 0) {
      final prefix = _buffer.substring(0, start);
      _buffer = _buffer.substring(start);
      if (!(_lastEventWasMessage && prefix.trim().isEmpty)) {
        _emitText(prefix);
      }
      return false;
    }

    // The buffer opens with something that may become a message. Wait.
    return true;
  }

  /// How many trailing backticks could be the start of a fence marker.
  ///
  /// Only one or two, because three would have been found as a complete marker.
  int _trailingBacktickCount() {
    if (_buffer.endsWith('``')) return 2;
    if (_buffer.endsWith('`')) return 1;
    return 0;
  }

  int _firstPossibleMessageStart() {
    final fence = _buffer.indexOf('```');
    final brace = _buffer.indexOf('{');
    if (fence == -1) return brace;
    if (brace == -1) return fence;
    return fence < brace ? fence : brace;
  }

  /// Emits the buffer up to [index] as prose, unless it is only the whitespace
  /// separating two messages.
  ///
  /// Every path that consumes a message routes its preceding text through
  /// here, so the separator rule holds no matter whether the message was
  /// already complete when it arrived or had to be buffered first. Without
  /// that, the same reply reads differently depending on how the network
  /// split it.
  void _emitTextBefore(int index) {
    if (index <= 0) return;
    final prefix = _buffer.substring(0, index);
    if (_lastEventWasMessage && prefix.trim().isEmpty) return;
    _emitText(prefix);
  }

  void _emitText(String text) {
    final cleaned = text
        .replaceAll('<a2ui_message>', '')
        .replaceAll('</a2ui_message>', '');
    // Nothing was emitted, so the separator rule still applies to whatever
    // comes next. Clearing the flag here would let a blank line through.
    if (cleaned.isEmpty) return;
    _lastEventWasMessage = false;
    _controller.add(TextEvent(cleaned));
  }

  void _emitDecoded(Object decoded) {
    if (decoded is Map<String, Object?>) {
      _emitOne(decoded);
    } else if (decoded is List) {
      for (final Object? item in decoded) {
        if (item is Map<String, Object?>) _emitOne(item);
      }
    }
  }

  /// The top-level keys that mark a payload as an attempted A2UI message.
  ///
  /// `version` counts, so a versioned payload that is otherwise malformed is
  /// still treated as a broken message rather than quietly shown as prose.
  static const _messageKeys = {
    'version',
    'createSurface',
    'updateComponents',
    'updateDataModel',
    'deleteSurface',
  };

  void _emitOne(Map<String, Object?> json) {
    try {
      _controller.add(A2uiMessageEvent(_parse(json)));
      _lastEventWasMessage = true;
      return;
    } on Object catch (error) {
      if (json.keys.any(_messageKeys.contains)) {
        _controller.addError(
          error is A2uiValidationException
              ? error
              : A2uiValidationException(
                  'Failed to parse A2UI message',
                  json: json,
                  cause: error,
                ),
        );
      } else {
        // Unrelated JSON the model happened to write. Show it.
        _controller.add(TextEvent(jsonEncode(json)));
      }
      _lastEventWasMessage = false;
    }
  }

  A2uiMessage _parse(Map<String, Object?> json) {
    try {
      return A2uiMessage.fromJson(json);
    } on A2uiValidationError catch (error) {
      final message = error.message.contains("'version'")
          ? 'A2UI message must have version "v0.9"'
          : error.message;
      throw A2uiValidationException(message, json: json, cause: error);
    }
  }

  static final _fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');

  _Found? _findFenced(String text) {
    final match = _fencePattern.firstMatch(text);
    if (match == null) return null;
    return _Found(
      match.start,
      match.end,
      match.group(1) ?? '',
      match.group(0) ?? '',
    );
  }

  /// Finds a complete JSON object at the start of [input], respecting braces
  /// inside strings and escapes so a message containing `}` in a value is not
  /// cut short.
  _Found? _findBalancedObject(String input) {
    if (!input.startsWith('{')) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = 0; i < input.length; i++) {
      final character = input[i];

      if (escaped) {
        escaped = false;
        continue;
      }
      if (character == r'\') {
        escaped = true;
        continue;
      }
      if (character == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (character == '{') {
        depth++;
      } else if (character == '}') {
        depth--;
        if (depth == 0) {
          final object = input.substring(0, i + 1);
          return _Found(0, i + 1, object, object);
        }
      }
    }
    return null;
  }
}

class _Found {
  _Found(this.start, this.end, this.content, this.original);

  final int start;
  final int end;

  /// The JSON itself, without any fence around it.
  final String content;

  /// Everything consumed, fence included, for emitting as prose on failure.
  final String original;
}
