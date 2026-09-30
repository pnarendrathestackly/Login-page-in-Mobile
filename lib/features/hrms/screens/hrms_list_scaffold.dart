import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/directory_skeleton.dart';
import '../../../widgets/common/list_view_state.dart';
import '../../../widgets/common/parts.dart';
import '../../../widgets/common/sections.dart';
import '../../dashboard/models/dashboard_models.dart';

/// Everything a concrete HRMS list screen has to supply. Keeps the shared
/// pipeline (search → filter → sort → page → table → pagination → states) in
/// one place so the nine screens don't each re-implement it.
abstract class HrmsListDelegate<T> {
  const HrmsListDelegate();

  String get title;
  String get description;

  /// Full collection from state. Re-read on every build.
  List<T> get rows;
  bool get loading;
  String? get error;
  VoidCallback get onRetry;

  List<TableColumn<T>> get columns;
  Widget cardBuilder(T row);
  bool matchesQuery(T row, String q);
  String get searchHint;

  /// KPI cards computed from [rows].
  List<Widget> kpis(List<T> rows);

  /// Filter dropdowns; empty for screens without any.
  List<Widget> filters() => const [];
  bool get hasActiveFilters => false;
  bool matchesFilters(T row) => true;

  /// Primary action button (Add …), or null.
  Widget? primaryAction() => null;

  /// Called when the "no data yet" empty state's action is tapped.
  VoidCallback? get onEmptyAction => null;
  String? get emptyActionLabel => null;
  IconData get emptyIcon => Icons.inbox_outlined;
}

/// Renders a [HrmsListDelegate]. The concrete screen is a [StatefulWidget] that
/// mixes in [ListViewState] and returns `HrmsListView(delegate: this)` from
/// build — see `employees_screen.dart` for the pattern.
class HrmsListView<T> extends StatelessWidget {
  const HrmsListView({
    super.key,
    required this.delegate,
    required this.state,
  });

  final HrmsListDelegate<T> delegate;
  final ListViewState<StatefulWidget, T> state;

  // The concrete screens mix `ListViewState<TheirScreen, T>` into their State
  // and pass `this`; that satisfies `ListViewState<StatefulWidget, T>` because
  // `TheirScreen extends StatefulWidget`. Kept as a named param rather than a
  // second type variable to keep the call site short.

  @override
  Widget build(BuildContext context) {
    if (delegate.error != null) {
      return DirectoryScaffold(
        title: delegate.title,
        description: delegate.description,
        kpis: const [],
        child: ErrorState(message: delegate.error!, onRetry: delegate.onRetry),
      );
    }
    if (delegate.loading) return DirectorySkeleton(title: delegate.title);

    return DirectoryScaffold(
      title: delegate.title,
      description: delegate.description,
      action: delegate.primaryAction(),
      kpis: delegate.kpis(delegate.rows),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableToolbar(
            search: SearchBox(
              hint: delegate.searchHint,
              onChanged: state.setQuery,
            ),
            filters: delegate.filters(),
          ),
          const SizedBox(height: 18),
          if (state.visible.isEmpty)
            EmptyState(
              icon: state.isFiltering ? Icons.search_off : delegate.emptyIcon,
              title: state.isFiltering
                  ? 'No matching records'
                  : 'Nothing here yet',
              message: state.isFiltering
                  ? 'Try a different search term or clear the filters.'
                  : 'Records you add will appear here.',
              actionLabel: state.isFiltering ? null : delegate.emptyActionLabel,
              onAction: state.isFiltering ? null : delegate.onEmptyAction,
            )
          else ...[
            RecordTable<T>(
              rows: state.visible,
              columns: delegate.columns,
              sortColumn: state.sortColumn,
              ascending: state.ascending,
              onSort: state.toggleSort,
              cardBuilder: delegate.cardBuilder,
            ),
            Pagination(
              page: state.page,
              pageCount: state.pageCount,
              total: state.filtered.length,
              onPage: state.setPage,
            ),
          ],
        ],
      ),
    );
  }
}

/// A small text-in-a-cell helper matching the directory tables' muted style.
Widget hrmsMuted(String s) => Text(
      s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(fontSize: 13, color: kMuted),
    );

/// The "Add X" primary button, styled like the one on the Users page.
Widget hrmsAddButton(String label, VoidCallback onTap) => FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: kIndigo,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

/// Builds a KPI card without a trend indicator (most HRMS counts don't trend).
Widget hrmsKpi(String label, String value, IconData icon, String caption) =>
    KpiCard(
      kpi: Kpi(
        label: label,
        value: value,
        icon: icon,
        changePercent: null,
        caption: caption,
      ),
    );
