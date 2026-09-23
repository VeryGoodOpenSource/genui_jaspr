import 'package:json_schema_builder/json_schema_builder.dart';

/// A component's schema with each list-or-binding property narrowed to the
/// alternative its current value actually takes.
///
/// `a2ui_core`'s binder decides how to resolve a property once, from its
/// schema alone. A property that may be either a literal list or a binding to
/// a whole list, like the reference implementation's `listOrReference`, reads
/// as a binding, and a binding resolves its value as one opaque whole. A
/// literal list would then arrive with every binding inside its elements left
/// unresolved, such as each of `ChoicePicker`'s options' own `label`.
///
/// So wherever the value is a literal list, the binder is handed the list
/// alternative instead, which resolves element by element. A binding or a
/// function call keeps the schema as written and is watched as a whole.
typedef NarrowedSchema = ({Schema schema, Set<String> narrowed});

/// Narrows [schema] against a component's raw [properties].
///
/// The result's `narrowed` names the properties that took their list
/// alternative, so a caller can tell when a later update needs a fresh binder
/// rather than a re-resolve against the old one.
NarrowedSchema narrowSchema(Schema schema, Map<String, dynamic> properties) {
  final narrowed = <String>{};
  final result = _narrow(schema.value, properties, narrowed);
  if (narrowed.isEmpty) return (schema: schema, narrowed: narrowed);
  return (schema: Schema.fromMap(result), narrowed: narrowed);
}

Map<String, Object?> _narrow(
  Map<String, Object?> schema,
  Map<String, dynamic> properties,
  Set<String> narrowed,
) {
  final result = Map<String, Object?>.of(schema);

  // The binder gathers properties from every branch of a combined schema, so
  // the narrowing looks in the same places.
  for (final key in const ['allOf', 'anyOf', 'oneOf']) {
    final branches = schema[key];
    if (branches is List) {
      // A branch that is not a map, such as a boolean schema, has no
      // properties to narrow and passes through as written.
      result[key] = branches
          .map(
            (branch) => branch is Map<String, Object?>
                ? _narrow(branch, properties, narrowed)
                : branch,
          )
          .toList();
    }
  }

  final shape = schema['properties'];
  if (shape is Map<String, Object?>) {
    final next = Map<String, Object?>.of(shape);
    for (final entry in shape.entries) {
      final alternative = _listAlternative(entry.value);
      if (alternative != null && properties[entry.key] is List) {
        next[entry.key] = alternative;
        narrowed.add(entry.key);
      }
    }
    result['properties'] = next;
  }
  return result;
}

/// The literal-list alternative of a property that may also be a binding, or
/// null when [property] is not that shape.
///
/// Requires a genuine data binding among the alternatives, a `path` with no
/// `componentId`. A child list's template also carries a `path`, but it names
/// a component to repeat, and narrowing it away would stop a literal child
/// list from resolving to child references.
Object? _listAlternative(Object? property) {
  if (property is! Map) return null;
  final alternatives = [
    for (final key in const ['anyOf', 'oneOf'])
      if (property[key] case final List<Object?> list) ...list,
  ];
  final list = alternatives.firstWhere(
    (alternative) => alternative is Map && alternative['type'] == 'array',
    orElse: () => null,
  );
  final hasBinding = alternatives.any((alternative) {
    if (alternative is! Map) return false;
    final Object? shape = alternative['properties'];
    return shape is Map &&
        shape.containsKey('path') &&
        !shape.containsKey('componentId');
  });
  return hasBinding ? list : null;
}
