import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:genui_jaspr_example/prompt.dart';
import 'package:genui_jaspr_example/server/chat_path.dart';
import 'package:shelf/shelf.dart';

/// The agent that answers the user, with the conversation's history.
///
/// A Genkit agent keeps each session's messages in its [store] and sends them
/// to the model on every turn, so the model remembers the UI it built when
/// the user's interaction with it comes back. The browser holds only a
/// session id. In memory here: sessions last as long as the process.
/// `FileSessionStore` from `package:genkit/io.dart` is the one-line change
/// to survive a restart.
///
/// The [model] is a parameter so a test can stand in for Gemini with one that
/// replays a canned reply.
Agent<dynamic> chatAgent(
  Genkit ai, {
  required ModelRef<dynamic> model,
  SessionStore? store,
}) {
  return ai.defineAgent<dynamic, dynamic, dynamic>(
    name: 'chat',
    model: model,
    system: a2uiSystemPrompt,
    store: store ?? InMemorySessionStore(),
  );
}

/// Serves [agent] over HTTP in the shape Genkit's client speaks.
///
/// The wire format, streaming, and the mapping of failures onto HTTP statuses
/// all come from `genkit_shelf`, so nothing here has to know how a frame looks.
/// Mount it in front of the page: `main.server.dart` routes everything under
/// [chatPath] here and lets the rest fall through to the rendered app.
///
/// A turn that fails is logged to stderr with its cause and stack trace.
/// `genkit_shelf` tells the browser only "Internal server error", so without
/// this the reason a reply broke would be written down nowhere.
Handler chatHandler(Agent<dynamic> agent) {
  final turn = shelfHandler(_withFailureLogging(agent.action));
  final snapshot = shelfHandler(agent.getSnapshotDataAction);
  final abort = shelfHandler(agent.abortAgentAction);

  return (Request request) => switch (request.url.path) {
    chatPath => turn(request),
    '$chatPath/getSnapshot' => snapshot(request),
    '$chatPath/abort' => abort(request),
    _ => Response.notFound('No such route.'),
  };
}

/// The agent's turn [action], writing any failure to stderr.
///
/// The failure has to be caught here, around the action itself. A model call
/// that breaks does not throw out of the agent: the turn ends with its error in
/// [AgentOutput.error], and `genkit_shelf` then sends the browser a frame that
/// hides the cause. The error still carries the original exception at this
/// point, so this is the last place it can be written down. Genkit keeps the
/// exception that caused a failure but not the stack trace it was thrown with,
/// so a stack is logged only when that exception is an [Error], which carries
/// its own. A model plugin's crash, such as the null check Gemini's recitation
/// stop trips, is one.
///
/// Genkit's [Action] has no `copyWith`, so the wrapper copies each field.
/// Anything it leaves out is lost to `genkit_shelf`.
Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>
_withFailureLogging(
  Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit> action,
) {
  return Action(
    name: action.name,
    actionType: action.actionType,
    description: action.description,
    inputSchema: action.inputSchema,
    outputSchema: action.outputSchema,
    streamSchema: action.streamSchema,
    initSchema: action.initSchema,
    metadata: action.metadata,
    fn: (input, context) async {
      final output = await action.fn(input, context);
      final error = output.error;
      if (error != null) {
        final cause = error.details;
        _logFailure(
          '${error.status}: ${error.message}',
          // With nothing underneath, Genkit fills the details in with the
          // message itself, which would only repeat the summary.
          cause: cause == error.message ? null : cause,
          stackTrace: cause is Error ? cause.stackTrace : null,
        );
      }
      return output;
    },
  );
}

void _logFailure(String summary, {Object? cause, StackTrace? stackTrace}) {
  stderr.writeln(
    [
      'Chat turn failed: $summary',
      if (cause != null) 'Cause: $cause',
      ?stackTrace,
    ].join('\n'),
  );
}
