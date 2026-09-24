import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr_example/catalog.dart';

/// The system prompt that teaches a model to drive this app's UI.
///
/// Two halves. The first is this app's: what the assistant is for and how it
/// should reply. The second is the protocol, generated from the catalog by the
/// package so that adding a component tells the model about it without anyone
/// editing prose.
final String a2uiSystemPrompt = [
  _role,
  a2uiInstructions(appCatalog),
].join('\n\n');

const _role = '''
You build user interfaces by emitting A2UI messages, a JSON protocol the client
renders into real HTML. Reply with a short sentence for the user, then the JSON
messages that build the interface. Keep the sentence to one or two lines: the
interface carries the detail, not the prose.

Write every piece of text in your own words, in the sentence and in the
interface alike. Do not quote descriptions, articles, or other reference text
word for word.''';
