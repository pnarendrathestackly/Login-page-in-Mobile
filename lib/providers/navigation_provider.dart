import 'package:flutter/foundation.dart';

import '../dashboard.dart';

/// The one place sidebar/navigation UI state lives.
///
/// The *selected* section is deliberately NOT stored here: the URL owns it,
/// and the router feeds it in. Keeping a second copy is exactly how a sidebar
/// highlight drifts out of sync with the address bar. What this holds is the
/// state the URL cannot express — collapsed rail, open drawer, expanded groups.
class NavigationProvider extends ChangeNotifier {
  DashboardSection _section = DashboardSection.overview;
  bool _sidebarExpanded = true;
  bool _drawerOpen = false;

  /// Currently active destination, mirrored from the route.
  DashboardSection get selectedSection => _section;

  /// The group heading that contains the active item.
  SidebarGroup get selectedGroup => _section.group;

  /// Desktop rail: true = full sidebar, false = icon-only.
  bool get isSidebarExpanded => _sidebarExpanded;

  /// Mobile drawer visibility.
  bool get isMobileDrawerOpen => _drawerOpen;

  /// Collapsed sidebar groups. Absent means expanded, so a new group shows
  /// its items by default rather than needing to be registered here first.
  final Set<SidebarGroup> _collapsedGroups = {};

  bool isGroupExpanded(SidebarGroup group) => !_collapsedGroups.contains(group);

  /// Called by the router when the route changes, so the highlight follows the
  /// URL rather than the tap. Deep links and browser back stay in sync.
  void syncWithRoute(DashboardSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }

  void toggleSidebar() {
    _sidebarExpanded = !_sidebarExpanded;
    notifyListeners();
  }

  /// Collapsed platform modules, by module id. Absent means expanded, so a
  /// newly registered module shows its pages by default.
  ///
  /// Modules start collapsed instead: with fifteen of them, an all-expanded
  /// sidebar would be unusable. [_expandedModules] holds the open ones.
  final Set<String> _expandedModules = {};

  bool isModuleExpanded(String moduleId) => _expandedModules.contains(moduleId);

  void toggleModule(String moduleId) {
    if (!_expandedModules.remove(moduleId)) _expandedModules.add(moduleId);
    notifyListeners();
  }

  /// Opens the module containing the active route, so a deep link or a browser
  /// back lands with its module already expanded rather than the user having to
  /// hunt for where they are.
  void revealModule(String moduleId) {
    if (_expandedModules.add(moduleId)) notifyListeners();
  }

  void toggleGroup(SidebarGroup group) {
    if (!_collapsedGroups.remove(group)) _collapsedGroups.add(group);
    notifyListeners();
  }

  void openDrawer() => _setDrawer(true);
  void closeDrawer() => _setDrawer(false);

  void _setDrawer(bool open) {
    if (_drawerOpen == open) return;
    _drawerOpen = open;
    notifyListeners();
  }
}
