import 'package:flutter/painting.dart';

/// Sidebar metrics, shared by the shell and the item rows.
const double kSidebarWidth = 260;
const double kSidebarCollapsedWidth = 76;

// The width at which the sidebar becomes a permanent rail lives in
// core/responsive: see Breakpoints.tablet and context.hasPermanentSidebar.

// Navy rail palette (super-admin shell).
const kRail = Color(0xFF0D1029);
const kRailText = Color(0xFFE4E6F5);
const kRailMuted = Color(0xFF6B7194);
const kRailSelected = Color(0xFF161B4A);
const kRailSelectedBorder = Color(0xFF3B44B8);
const kRailDivider = Color(0xFF1C2150);
