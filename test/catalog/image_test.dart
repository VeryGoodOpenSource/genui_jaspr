import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/image.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/render.dart';

Future<String> renderImage(
  Map<String, dynamic> extra, {
  Map<String, Object?> data = const {},
}) async => normalizeHtml(
  await renderSurface(
    [
      {'id': 'root', 'component': 'Image', ...extra},
    ],
    data: data,
    catalog: MinimalJasprCatalog().copyWith(add: [const ImageComponent()]),
  ),
);

void main() {
  group('Image', () {
    test('exposes the A2UI v0.9 API', () {
      const component = ImageComponent();

      expect(component.name, 'Image');
      expect(
        component.schema.value,
        Schema.object(
          properties: {
            'url': CommonSchemas.dynamicString,
            'description': CommonSchemas.dynamicString,
            'fit': Schema.string(
              enumValues: ['contain', 'cover', 'fill', 'none', 'scaleDown'],
            ),
            'variant': Schema.string(
              enumValues: [
                'icon',
                'avatar',
                'smallFeature',
                'mediumFeature',
                'largeFeature',
                'header',
              ],
            ),
          },
          required: ['url'],
        ).value,
      );
    });

    test('renders bound image content with the documented defaults', () async {
      expect(
        await renderImage(
          {
            'url': {'path': '/photo/url'},
            'description': {'path': '/photo/description'},
          },
          data: {
            '/photo/url': '/ada.png',
            '/photo/description': 'Ada Lovelace',
          },
        ),
        '<img class="a2ui-image a2ui-image--medium-feature" '
        'style="object-fit: fill" alt="Ada Lovelace" src="/ada.png"/>',
      );
    });

    test('maps every fit and size variant onto CSS', () async {
      for (final (variant, className) in const [
        ('icon', 'icon'),
        ('avatar', 'avatar'),
        ('smallFeature', 'small-feature'),
        ('mediumFeature', 'medium-feature'),
        ('largeFeature', 'large-feature'),
        ('header', 'header'),
      ]) {
        final html = await renderImage({
          'url': '/photo.png',
          'variant': variant,
        });
        expect(html, contains('a2ui-image--$className'));
      }

      for (final (fit, cssValue) in const [
        ('contain', 'contain'),
        ('cover', 'cover'),
        ('fill', 'fill'),
        ('none', 'none'),
        ('scaleDown', 'scale-down'),
      ]) {
        final html = await renderImage({'url': '/photo.png', 'fit': fit});
        expect(html, contains('object-fit: $cssValue'));
      }
    });
  });
}
