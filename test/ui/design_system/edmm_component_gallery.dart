import 'package:edmm/ui/core/widgets/edmm_ambient_backdrop.dart';
import 'package:edmm/ui/core/widgets/edmm_filter_pill.dart';
import 'package:edmm/ui/core/widgets/edmm_icon_action.dart';
import 'package:edmm/ui/core/widgets/edmm_section_label.dart';
import 'package:edmm/ui/core/widgets/edmm_surface.dart';
import 'package:edmm/ui/core/widgets/edmm_timecode.dart';
import 'package:flutter/material.dart';

class EdmmComponentGallery extends StatelessWidget {
  const EdmmComponentGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return EdmmAmbientBackdrop(
      variant: EdmmAmbientBackdropVariant.catalogEdge,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const EdmmSectionLabel(label: 'SURFACES', isHeader: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final variant in EdmmSurfaceVariant.values)
                  SizedBox(
                    width: 120,
                    height: 56,
                    child: EdmmSurface(
                      variant: variant,
                      child: Center(child: Text(variant.name)),
                    ),
                  ),
                const SizedBox(
                  width: 120,
                  height: 56,
                  child: EdmmSurface(
                    variant: EdmmSurfaceVariant.raised,
                    tone: EdmmSurfaceTone.rose,
                    child: Center(child: Text('rose')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const EdmmSectionLabel(label: 'ACTIONS', isHeader: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                EdmmIconAction(
                  label: 'Play',
                  icon: Icons.play_arrow,
                  onPressed: () {},
                ),
                EdmmIconAction(
                  label: 'Selected',
                  icon: Icons.check_circle_outline,
                  selectedIcon: Icons.check_circle,
                  selected: true,
                  onPressed: () {},
                ),
                const EdmmIconAction(
                  label: 'Unavailable',
                  icon: Icons.block,
                  onPressed: null,
                ),
                EdmmIconAction(
                  label: 'Prominent play',
                  icon: Icons.play_arrow,
                  emphasis: EdmmIconActionEmphasis.prominent,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            const EdmmSectionLabel(label: 'FILTERS', isHeader: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                EdmmFilterPill(
                  label: 'Pop',
                  count: 12,
                  selected: true,
                  onPressed: () {},
                ),
                EdmmFilterPill(
                  label: 'EDM',
                  count: 8,
                  selected: false,
                  onPressed: () {},
                ),
                const EdmmFilterPill(
                  label: 'Recent',
                  count: 3,
                  selected: false,
                  onPressed: null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const EdmmSectionLabel(label: '재생 시간', isHeader: true),
            const SizedBox(height: 8),
            const EdmmTimecode(
              value: Duration(hours: 1, minutes: 2, seconds: 3),
              semanticLabel: '1 hour 2 minutes 3 seconds',
            ),
          ],
        ),
      ),
    );
  }
}
