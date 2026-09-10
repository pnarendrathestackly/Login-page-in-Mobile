import 'package:flutter/material.dart';

import './data_table.dart';

/// Search → filter → sort → page, in one place.
///
/// All four directory pages drive their table through this, so the pipeline is
/// implemented and fixed once rather than four times.
///
/// ponytail: client-side because the demo collections are a dozen rows. When
/// the data outgrows memory, move [visible] behind a query-parameterised
/// endpoint — the widget API above it need not change.
mixin ListViewState<W extends StatefulWidget, T> on State<W> {
  String query = '';
  int? sortColumn;
  bool ascending = true;
  int page = 0;

  /// Rows per page.
  int get pageSize => 8;

  /// The full, unfiltered collection.
  List<T> get source;

  /// Columns, so sorting can reach each column's `sortBy`.
  List<TableColumn<T>> get columns;

  /// True when [row] matches the current search text.
  bool matchesQuery(T row, String q);

  /// Extra per-page filters (status, role, priority…). Default: keep all.
  bool matchesFilters(T row) => true;

  /// Rows after search and filters, before paging.
  List<T> get filtered {
    final q = query.toLowerCase();
    final rows = [
      for (final row in source)
        if ((q.isEmpty || matchesQuery(row, q)) && matchesFilters(row)) row,
    ];

    final index = sortColumn;
    if (index != null && index < columns.length) {
      final key = columns[index].sortBy;
      if (key != null) {
        rows.sort((a, b) {
          final c = key(a).compareTo(key(b));
          return ascending ? c : -c;
        });
      }
    }
    return rows;
  }

  int get pageCount => (filtered.length / pageSize).ceil().clamp(1, 9999);

  /// The rows actually rendered — the current page of [filtered].
  List<T> get visible {
    final rows = filtered;
    // Clamped: deleting or filtering can strand the view past the last page.
    final start = (page * pageSize).clamp(0, rows.length);
    final end = (start + pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  /// Any narrowing active — drives the "no matches" vs "no data" empty state.
  bool get isFiltering => query.isNotEmpty || hasActiveFilters;

  /// Overridden by pages that add their own dropdowns.
  bool get hasActiveFilters => false;

  void setQuery(String value) => setState(() {
        query = value;
        page = 0; // a new search always starts at the first page
      });

  /// Toggles direction when the same column is tapped again.
  void toggleSort(int index) => setState(() {
        if (sortColumn == index) {
          ascending = !ascending;
        } else {
          sortColumn = index;
          ascending = true;
        }
        page = 0;
      });

  void setPage(int value) => setState(() => page = value);

  /// Resets paging after a filter changes; call from dropdown handlers.
  void onFilterChanged(VoidCallback apply) => setState(() {
        apply();
        page = 0;
      });
}
