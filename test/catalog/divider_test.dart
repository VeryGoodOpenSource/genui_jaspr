import 'package:genui_jaspr/genui_jaspr.dart';
import 'package:genui_jaspr/src/catalog/basic/components/divider.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

Future<String> renderDivider(Map<String, dynamic> extra) => renderSurface([
  {'id': 'root', 'component': 'Divider', ...extra},
], catalog: MinimalJasprCatalog().copyWith(add: [const DividerComponent()]));

void main() {
  group('Divider', () {
    test('exposes the A2UI v0.9 API', () {
      const component = DividerComponent();

      expect(component.name, 'Divider');
      expect(
        component.schema.value,
        Schema.object(
          properties: {
            'axis': Schema.string(enumValues: ['horizontal', 'vertical']),
          },
        ).value,
      );
    });

    test('renders a horizontal rule by default', () async {
      expect(await renderDivider({}), '<hr class="a2ui-divider"/>');
    });

    test('marks a vertical divider for vertical styling', () async {
      expect(
        await renderDivider({'axis': 'vertical'}),
        '<hr class="a2ui-divider a2ui-divider--vertical"/>',
      );
    });
  });
}
