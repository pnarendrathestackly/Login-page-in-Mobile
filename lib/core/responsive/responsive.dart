import 'package:flutter/widgets.dart';

/// Form factor for the current viewport.
///
/// One definition of "tablet" for the whole app, so a layout decision made in
/// the header and one made in a page cannot disagree about the same screen.
enum FormFactor { mobile, tablet, desktop }

/// Layout breakpoints, in logical pixels.
///
/// ponytail: plain constants and one extension rather than a responsive
/// framework. Everything the app needs is "which band is this width in", and
/// the values below are the only place that is decided.
abstract final class Breakpoints {
  /// Below this is a phone: single column, drawer navigation.
  static const mobile = 600.0;

  /// At or above this the sidebar is a permanent rail rather than a drawer.
  /// Between [mobile] and here is tablet: collapsible rail, 2-up content.
  static const tablet = 900.0;

  /// At or above this there is room for a search field in the header beside a
  /// permanent sidebar. Below it the search is an icon that expands.
  static const headerSearch = 1180.0;

  /// Wide desktop: room for the sign-out label as well as the icon.
  static const wide = 1600.0;
}

/// Screen-size queries, so widgets ask what kind of screen they are on rather
/// than repeating magic numbers.
///
/// Prefer `LayoutBuilder` when a widget should respond to the space *it* was
/// given (a card in a grid); use these when the decision is genuinely about
/// the whole viewport (navigation shape, header density).
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  FormFactor get formFactor {
    final w = screenWidth;
    if (w < Breakpoints.mobile) return FormFactor.mobile;
    if (w < Breakpoints.tablet) return FormFactor.tablet;
    return FormFactor.desktop;
  }

  bool get isMobile => formFactor == FormFactor.mobile;
  bool get isTablet => formFactor == FormFactor.tablet;
  bool get isDesktop => formFactor == FormFactor.desktop;

  /// The sidebar is a permanent rail rather than a drawer.
  bool get hasPermanentSidebar => screenWidth >= Breakpoints.tablet;

  /// The header has room for a search field rather than an icon.
  bool get hasHeaderSearchField => screenWidth >= Breakpoints.headerSearch;

  /// Pick a value per form factor. [tablet] falls back to [mobile] when a
  /// layout only distinguishes two bands.
  T responsive<T>({required T mobile, T? tablet, required T desktop}) =>
      switch (formFactor) {
        FormFactor.mobile => mobile,
        FormFactor.tablet => tablet ?? mobile,
        FormFactor.desktop => desktop,
      };
}
