import 'package:a2ui_core/a2ui_core.dart';
import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/video.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/render.dart';

void main() {
  group('Video', () {
    test('exposes the A2UI v0.9 API', () {
      const component = VideoComponent();

      expect(component.name, 'Video');
      expect(
        component.schema.value,
        Schema.object(
          properties: {'url': CommonSchemas.dynamicString},
          required: ['url'],
        ).value,
      );
    });

    test('renders a bound URL with native controls', () async {
      final html = normalizeHtml(
        await renderSurface(
          [
            {
              'id': 'root',
              'component': 'Video',
              'url': {'path': '/video/url'},
            },
          ],
          data: {'/video/url': '/demo.mp4'},
          catalog: MinimalJasprCatalog().copyWith(
            add: [const VideoComponent()],
          ),
        ),
      );

      expect(
        html,
        '<video class="a2ui-video" controls src="/demo.mp4"></video>',
      );
    });
  });
}
