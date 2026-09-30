import 'package:flutter/material.dart';

/// The app's design tokens and the single [ThemeData] built from them.
///
/// Light enterprise theme: pale-blue shell, white cards, thin borders, blue
/// primary accent. Every colour in the app comes from here —
/// `main.dart` re-exports these so the ~40 files that `import 'main.dart'`
/// pick them up without changing their imports.
///
/// The five original token names (kIndigo/kInk/kMuted/kBorder/kCanvas) keep
/// their names and their *roles* — accent, primary text, secondary text,
/// border, app background — only their values changed. That is what makes the
/// light switch a token edit rather than a rewrite.

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

/// Brand accent — primary actions, active nav, focus, primary chart series.
/// Named `kIndigo` for continuity with the ~40 existing call sites; the value
/// is the brand blue.
const kIndigo = Color(0xFF2563EB);
const kPrimaryHover = Color(0xFF1D4FD8);
const kPrimaryPressed = Color(0xFF1E40AF);
const kPrimaryMuted = Color(0xFFA9C2F7);

/// Text/icon colour to place *on* a filled primary surface.
const kOnPrimary = Color(0xFFFFFFFF);

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/// App background behind the floating surfaces.
const kCanvas = Color(0xFFEFF5FE);

/// Deepest background — behind the shell, and `onPrimary` text.
const kCanvasDeep = Color(0xFFDCE9FB);

/// Main surface: cards, panels, the sidebar's raised areas.
const kSurface = Color(0xFFFFFFFF);

/// Elevated surface: hovered rows, nested cards, dialogs, tooltips.
const kSurfaceElevated = Color(0xFFF5F8FE);

/// Secondary surface — also the default border value.
const kSurfaceSecondary = Color(0xFFE6EDF7);

/// Inset wells: read-only detail blocks, table sub-rows, code/meta panels.
const kInset = Color(0xFFF7FAFF);

/// Form-field fill.
const kFieldFill = Color(0xFFFFFFFF);

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

/// Primary text.
const kInk = Color(0xFF1B2432);

/// High-emphasis text — page titles, KPI values.
const kInkStrong = Color(0xFF0B1220);

/// Secondary text and icons.
const kMuted = Color(0xFF64748B);

/// Tertiary text — section labels, axis ticks, captions, placeholders.
const kMutedStrong = Color(0xFF94A3B8);

// ---------------------------------------------------------------------------
// Borders
// ---------------------------------------------------------------------------

/// Hairline borders and dividers.
const kBorder = Color(0xFFE2E8F0);

/// Stronger border — secondary buttons, input hover, tooltip edges.
const kBorderStrong = Color(0xFFCBD5E1);

// ---------------------------------------------------------------------------
// Semantic
// ---------------------------------------------------------------------------

const kSuccess = Color(0xFF16A34A);
const kWarning = Color(0xFFD97706);
const kDanger = Color(0xFFDC2626);
const kInfo = Color(0xFF0EA5E9);
const kPurple = Color(0xFF7C3AED);
const kTeal = Color(0xFF0D9488);

/// Neutral status — inactive, cancelled, retired, not-started, on-hold.
const kNeutral = Color(0xFF94A3B8);

/// Tinted background for a semantic colour, for badges and inset callouts.
/// One helper instead of a muted constant per semantic colour.
Color semanticTint(Color c) => c.withValues(alpha: .14);

// ---------------------------------------------------------------------------
// Charts
// ---------------------------------------------------------------------------

/// The global visualization palette. Every chart draws from this list in
/// order, so no chart invents its own colours.
const kChartSeries = <Color>[kIndigo, kInfo, kPurple, kTeal];

/// Chart grid lines — deliberately near-invisible.
const kChartGrid = kSurfaceSecondary;

/// Unfilled track: progress bars, donut remainder, inactive segments.
const kTrack = Color(0xFFE6EDF7);

/// Namespaced aliases for code that prefers `AppColors.primary` over the bare
/// constants. Same values — pick whichever reads better at the call site.
abstract final class AppColors {
  static const primary = kIndigo;
  static const primaryHover = kPrimaryHover;
  static const primaryPressed = kPrimaryPressed;
  static const primaryMuted = kPrimaryMuted;
  static const onPrimary = kOnPrimary;

  /// Deprecated alias kept so existing `AppColors.indigo` call sites compile.
  static const indigo = kIndigo;

  static const canvas = kCanvas;
  static const canvasDeep = kCanvasDeep;
  static const surface = kSurface;
  static const surfaceElevated = kSurfaceElevated;
  static const surfaceSecondary = kSurfaceSecondary;
  static const inset = kInset;
  static const fieldFill = kFieldFill;

  static const ink = kInk;
  static const inkStrong = kInkStrong;
  static const muted = kMuted;
  static const mutedStrong = kMutedStrong;

  static const border = kBorder;
  static const borderStrong = kBorderStrong;

  static const success = kSuccess;
  static const warning = kWarning;
  static const danger = kDanger;
  static const info = kInfo;
  static const purple = kPurple;
  static const teal = kTeal;
  static const neutral = kNeutral;
}

/// The one [ThemeData] the app runs on.
///
/// `AppTheme.dark` is kept as an alias so existing call sites compile; both
/// getters return the same light theme.
abstract final class AppTheme {
  static ThemeData get dark => light;

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: kIndigo,
      onPrimary: kOnPrimary,
      secondary: kInfo,
      onSecondary: kOnPrimary,
      surface: kSurface,
      onSurface: kInk,
      surfaceContainerHighest: kSurfaceElevated,
      error: kDanger,
      onError: kOnPrimary,
      outline: kBorder,
      outlineVariant: kBorderStrong,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: kCanvas,
      canvasColor: kCanvas,
      dividerColor: kBorder,
      fontFamily: 'Roboto',

      // Dividers are hairlines, not spacers — height stays where each call
      // site sets it.
      dividerTheme: const DividerThemeData(color: kBorder, thickness: 1),

      iconTheme: const IconThemeData(color: kMuted),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: kIndigo,
        selectionColor: Color(0x332563EB),
        selectionHandleColor: kIndigo,
      ),

      // Consistent field height and the blue focus ring the spec asks for.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kFieldFill,
        hintStyle: const TextStyle(color: kMutedStrong),
        labelStyle: const TextStyle(color: kMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kIndigo, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDanger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
      ),

      // Panels, not floating cards: a border does the work a shadow used to.
      cardTheme: CardThemeData(
        color: kSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kBorder),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: kSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kBorderStrong),
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: kCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: kSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: kBorderStrong),
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(kSurfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: kBorderStrong),
            ),
          ),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: kSurfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorderStrong),
        ),
        textStyle: const TextStyle(color: kInk, fontSize: 12),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: kSurfaceElevated,
        contentTextStyle: const TextStyle(color: kInk),
        actionTextColor: kIndigo,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kBorderStrong),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: kSurfaceElevated,
        side: const BorderSide(color: kBorder),
        labelStyle: const TextStyle(color: kInk, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kIndigo,
        linearTrackColor: kTrack,
        circularTrackColor: kTrack,
      ),

      // Blue only when on; the thumb stays white so "off" reads as off
      // without relying on colour alone.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kOnPrimary : kSurface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kIndigo : kSurfaceSecondary,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kIndigo : kBorderStrong,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? kIndigo : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(kOnPrimary),
        side: const BorderSide(color: kBorderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? kIndigo : kBorderStrong,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return kPrimaryPressed;
            if (s.contains(WidgetState.hovered)) return kPrimaryHover;
            return kIndigo;
          }),
          foregroundColor: const WidgetStatePropertyAll(kOnPrimary),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) =>
                s.contains(WidgetState.hovered) ? kSurfaceElevated : kSurface,
          ),
          foregroundColor: const WidgetStatePropertyAll(kInk),
          side: const WidgetStatePropertyAll(BorderSide(color: kBorderStrong)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(kMuted),
          overlayColor: WidgetStatePropertyAll(kIndigo.withValues(alpha: .08)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        textColor: kInk,
        iconColor: kMuted,
        selectedColor: kIndigo,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: kIndigo,
        unselectedLabelColor: kMuted,
        indicatorColor: kIndigo,
        dividerColor: kBorder,
      ),
    );
  }
}
