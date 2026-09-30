import 'package:flutter/material.dart';

import '../../main.dart';

/// A rounded, colour-coded tile behind a sidebar icon.
///
/// The sidebar used to draw bare monochrome glyphs, which made every row read
/// the same and gave the rail no visual anchor. Each destination now carries
/// its own hue, and the tile is shaded to sit slightly proud of the surface:
/// a top-light gradient, a darker rim, an outer drop shadow and a one-pixel
/// inner highlight along the top edge — the cheap, flat-design way to suggest
/// depth without an image asset per icon.
///
/// ponytail: one widget used by both the workspace menu and the module tree,
/// rather than a bespoke decoration at each call site. The two sidebars are
/// the same visual language and must stay that way.
class SidebarIconChip extends StatelessWidget {
  const SidebarIconChip({
    super.key,
    this.icon,
    this.logoAsset,
    required this.color,
    this.selected = false,
    this.size = 30,
  }) : assert(icon != null || logoAsset != null,
            'a chip needs either an icon or a logo');

  /// Glyph drawn inside the tile. Null when [logoAsset] carries the mark.
  final IconData? icon;

  /// Bundled PNG drawn inside the tile, for modules that ship real artwork.
  /// Takes precedence over [icon], which then acts as the decode fallback.
  final String? logoAsset;

  /// The destination's hue. Drives the whole chip, so one colour per item is
  /// all a call site has to supply.
  final Color color;

  /// Selected rows get a fully saturated chip; the rest stay tinted, so the
  /// active item still wins without the palette turning into noise.
  final bool selected;

  /// Outer tile size. The glyph is scaled from this.
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.3;

    // Selected: solid colour with white glyph. Idle: a pale wash of the same
    // hue with the glyph in full strength, so the row keeps its identity
    // without competing with the selection.
    final gradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_lift(color, .18), color],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(color.withValues(alpha: .16), kSurface),
              Color.alphaBlend(color.withValues(alpha: .28), kSurface),
            ],
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        // Rim: a slightly darker edge reads as the tile's own thickness.
        border: Border.all(
          color: selected ? _shade(color, .12) : color.withValues(alpha: .34),
          width: 0.8,
        ),
        boxShadow: [
          // Cast shadow — the tile sitting above the rail.
          BoxShadow(
            color: color.withValues(alpha: selected ? .38 : .18),
            blurRadius: selected ? 8 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Top-edge highlight: the lit face of a raised surface. A hairline
          // is enough — anything thicker reads as a border, not a sheen.
          Positioned(
            top: 1,
            left: radius * 0.6,
            right: radius * 0.6,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: selected ? .45 : .7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          if (logoAsset != null)
            Padding(
              // The logos are square PNGs with their own internal padding, so
              // they need less inset than a Material glyph to read the same
              // size inside the tile.
              padding: EdgeInsets.all(size * 0.14),
              child: Image.asset(
                logoAsset!,
                fit: BoxFit.contain,
                // A missing or corrupt asset falls back to the glyph rather
                // than leaving an empty tile.
                errorBuilder: (_, __, ___) => Icon(
                  icon ?? Icons.widgets_outlined,
                  size: size * 0.55,
                  color: selected ? kOnPrimary : _shade(color, .1),
                ),
              ),
            )
          else
            Icon(
              icon,
              size: size * 0.55,
              color: selected ? kOnPrimary : _shade(color, .1),
            ),
        ],
      ),
    );
  }

  /// Lightens towards white — the lit corner of the gradient.
  static Color _lift(Color c, double amount) =>
      Color.lerp(c, Colors.white, amount)!;

  /// Darkens towards black — the rim and the idle glyph.
  static Color _shade(Color c, double amount) =>
      Color.lerp(c, Colors.black, amount)!;
}

/// Stable per-destination hues.
///
/// Keyed by a string so both sidebars can look one up without sharing an enum:
/// the workspace menu passes a [DashboardSection] name, the module tree a
/// module id or page slug. Anything unknown falls back to the brand colour,
/// so a new destination is never colourless.
Color sidebarHue(String key) {
  final hue = _hues[key];
  if (hue != null) return hue;
  // Deterministic spread for keys with no explicit hue: the same slug always
  // lands on the same colour, so the rail does not reshuffle between builds.
  return _palette[key.hashCode.abs() % _palette.length];
}

/// The colours destinations are drawn from. Deliberately a small, harmonious
/// set — a rail of sixteen unrelated hues reads as clutter.
const List<Color> _palette = [
  Color(0xFF2563EB), // blue
  Color(0xFF7C3AED), // violet
  Color(0xFF0D9488), // teal
  Color(0xFFDB2777), // pink
  Color(0xFFEA580C), // orange
  Color(0xFF0EA5E9), // sky
  Color(0xFF16A34A), // green
  Color(0xFF9333EA), // purple
  Color(0xFFCA8A04), // amber
  Color(0xFF4F46E5), // indigo
];

/// Explicit hues where the colour should carry meaning — money is green,
/// alerts are amber, security is red — rather than being spread by hash.
const Map<String, Color> _hues = {
  // --- Workspace menu (DashboardSection names) ---
  'overview': Color(0xFF2563EB),
  'users': Color(0xFF7C3AED),
  'customers': Color(0xFF0D9488),
  'projects': Color(0xFFEA580C),
  'tasks': Color(0xFF16A34A),
  'reports': Color(0xFF0EA5E9),
  'notifications': Color(0xFFCA8A04),
  'messages': Color(0xFFDB2777),
  'profile': Color(0xFF4F46E5),
  'settings': Color(0xFF64748B),
  'help': Color(0xFF9333EA),

  // --- Platform modules (module ids) ---
  'admin': Color(0xFF64748B),
  'hrms': Color(0xFF7C3AED),
  'crm': Color(0xFF2563EB),
  'erp': Color(0xFFEA580C),
  'finance': Color(0xFF16A34A),
  'workflow': Color(0xFF0EA5E9),
  'documents': Color(0xFFCA8A04),
  'subscriptions': Color(0xFFDB2777),
  'revenue': Color(0xFF059669),
  'ai': Color(0xFF9333EA),
  'calendar': Color(0xFF4F46E5),
  'integrations': Color(0xFF0D9488),
  'search': Color(0xFF0284C7),
  'security': Color(0xFFDC2626),
};
