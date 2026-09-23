import 'package:a2ui_core/a2ui_core.dart' hide FormatStringFunction;
import 'package:genui_jaspr/src/catalog/basic/components/audio_player.dart';
import 'package:genui_jaspr/src/catalog/basic/components/card.dart';
import 'package:genui_jaspr/src/catalog/basic/components/check_box.dart';
import 'package:genui_jaspr/src/catalog/basic/components/choice_picker.dart';
import 'package:genui_jaspr/src/catalog/basic/components/date_time_input.dart';
import 'package:genui_jaspr/src/catalog/basic/components/divider.dart';
import 'package:genui_jaspr/src/catalog/basic/components/icon.dart';
import 'package:genui_jaspr/src/catalog/basic/components/image.dart';
import 'package:genui_jaspr/src/catalog/basic/components/list.dart';
import 'package:genui_jaspr/src/catalog/basic/components/modal.dart';
import 'package:genui_jaspr/src/catalog/basic/components/slider.dart';
import 'package:genui_jaspr/src/catalog/basic/components/tabs.dart';
import 'package:genui_jaspr/src/catalog/basic/components/video.dart';
import 'package:genui_jaspr/src/catalog/basic/functions/boolean.dart';
import 'package:genui_jaspr/src/catalog/basic/functions/format.dart';
import 'package:genui_jaspr/src/catalog/basic/functions/open_url.dart';
import 'package:genui_jaspr/src/catalog/basic/functions/validation.dart';
import 'package:genui_jaspr/src/catalog/jaspr_component.dart';
import 'package:genui_jaspr/src/catalog/minimal/components/button.dart';
import 'package:genui_jaspr/src/catalog/minimal/components/column.dart';
import 'package:genui_jaspr/src/catalog/minimal/components/row.dart';
import 'package:genui_jaspr/src/catalog/minimal/components/text.dart';
import 'package:genui_jaspr/src/catalog/minimal/components/text_field.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The complete pinned A2UI v0.9 basic catalog, rendered as HTML.
///
/// The catalog always includes the package's 59 built-in Material SVG paths,
/// because its official catalog ID promises the standard `Icon` component.
class BasicJasprCatalog extends Catalog<JasprComponent> {
  /// Creates the complete catalog with the built-in icon renderer.
  BasicJasprCatalog({
    String? locale,
    UrlOpener? urlOpener,
  }) : super(
         id: catalogId,
         components: _components(),
         functions: _functions(locale: locale, urlOpener: urlOpener),
         themeSchema: _themeSchema,
       );

  /// The exact catalog id published by the pinned A2UI v0.9 schema.
  static const catalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';
}

List<JasprComponent> _components() => [
  TextComponent(),
  const ImageComponent(),
  const IconComponent(),
  const VideoComponent(),
  const AudioPlayerComponent(),
  RowComponent(),
  ColumnComponent(),
  const ListComponent(),
  const CardComponent(),
  const TabsComponent(),
  const ModalComponent(),
  const DividerComponent(),
  ButtonComponent(),
  TextFieldComponent(),
  const CheckBoxComponent(),
  const ChoicePickerComponent(),
  const SliderComponent(),
  const DateTimeInputComponent(),
];

List<FunctionImplementation> _functions({
  required String? locale,
  required UrlOpener? urlOpener,
}) => [
  RequiredFunction(),
  RegexFunction(),
  LengthFunction(),
  NumericFunction(),
  EmailFunction(),
  FormatStringFunction(),
  FormatNumberFunction(locale: locale),
  FormatCurrencyFunction(locale: locale),
  FormatDateFunction(locale: locale),
  PluralizeFunction(locale: locale),
  OpenUrlFunction(opener: urlOpener),
  AndFunction(),
  OrFunction(),
  NotFunction(),
];

final _themeSchema = Schema.object(
  properties: {
    'primaryColor': Schema.string(pattern: r'^#[0-9a-fA-F]{6}$'),
    'iconUrl': Schema.string(format: 'uri'),
    'agentDisplayName': Schema.string(),
  },
  additionalProperties: true,
);
