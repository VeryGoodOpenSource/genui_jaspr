import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/choice_picker.dart';

import 'exercise.dart';

void main() => exercise(
  MinimalJasprCatalog().copyWith(add: [const ChoicePickerComponent()]),
);
