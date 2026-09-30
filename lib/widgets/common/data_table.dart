import 'package:flutter/material.dart';

import '../../main.dart';
import '../../motion.dart';
import './parts.dart';

/// Reusable directory-page building blocks: search box, filter dropdown,
/// sortable table, responsive card fallback, and pagination.
///
/// Every list page (Users, Customers, Projects, Tasks) is built from these, so
/// filtering and paging behave identically across all four.

/// Debounced search field. Reports the trimmed query as the user types.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 260,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        onChanged: (v) => widget.onChanged(v.trim()),
        style: const TextStyle(fontSize: 14, color: kInk),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          hintStyle: const TextStyle(fontSize: 14, color: kMuted),
          prefixIcon: const Icon(Icons.search, size: 20, color: kMuted),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16, color: kMuted),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: kFieldFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: _border(kBorder),
          enabledBorder: _border(kBorder),
          focusedBorder: _border(kIndigo, 1.5),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Dropdown filter. [value] null means "all".
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Capped and ellipsised: option labels (company names, long statuses)
      // are otherwise wide enough to overflow a phone-width toolbar.
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: kFieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value == null ? kBorder : kIndigo),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(Icons.expand_more, size: 18, color: kMuted),
          style: const TextStyle(fontSize: 13.5, color: kInk),
          onChanged: onChanged,
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text(
                'All $label',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: kMuted),
              ),
            ),
            for (final o in options)
              DropdownMenuItem<T?>(
                value: o,
                child: Text(labelOf(o), overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

/// One column of a [RecordTable].
class TableColumn<T> {
  const TableColumn({
    required this.label,
    required this.cell,
    this.width = const FlexColumnWidth(),
    this.sortBy,
    this.numeric = false,
  });

  final String label;

  /// Builds the cell content for a row.
  final Widget Function(T row) cell;
  final TableColumnWidth width;

  /// Comparable value for sorting. Null makes the column unsortable.
  final Comparable<Object> Function(T row)? sortBy;

  /// Right-aligns the header, for counts and values.
  final bool numeric;
}

/// Sortable, responsive table.
///
/// Above [cardBreakpoint] it renders as a real table; below it, each row
/// becomes a card via [cardBuilder], because a seven-column table is unusable
/// on a phone. Horizontal scrolling is offered in between.
class RecordTable<T> extends StatelessWidget {
  const RecordTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.cardBuilder,
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
    this.cardBreakpoint = 760,
    this.minTableWidth = 900,
  });

  final List<T> rows;
  final List<TableColumn<T>> columns;

  /// Mobile presentation for one row.
  final Widget Function(T row) cardBuilder;

  /// Index into [columns], or null for unsorted.
  final int? sortColumn;
  final bool ascending;
  final ValueChanged<int> onSort;

  final double cardBreakpoint;

  /// Below this the table scrolls horizontally rather than crushing columns.
  final double minTableWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < cardBreakpoint) {
          return Column(
            children: [for (final row in rows) cardBuilder(row)],
          );
        }
        final table = _table(context);
        if (c.maxWidth >= minTableWidth) return table;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minTableWidth, child: table),
          ),
        );
      },
    );
  }

  Widget _table(BuildContext context) {
    return Table(
      columnWidths: {
        for (final (i, col) in columns.indexed) i: col.width,
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            for (final (i, col) in columns.indexed)
              _HeaderCell(
                label: col.label,
                numeric: col.numeric,
                sortable: col.sortBy != null,
                sorted: sortColumn == i,
                ascending: ascending,
                onTap: col.sortBy == null ? null : () => onSort(i),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            children: [
              for (final col in columns)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: col.cell(row),
                ),
            ],
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.numeric,
    required this.sortable,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool numeric;
  final bool sortable;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: sorted ? kIndigo : kMuted,
            ),
          ),
        ),
        if (sortable) ...[
          const SizedBox(width: 4),
          Icon(
            sorted
                ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 13,
            color: sorted ? kIndigo : kMuted,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: sortable
            ? Semantics(
                button: true,
                label: sorted
                    ? '$label, sorted ${ascending ? 'ascending' : 'descending'}'
                    : '$label, tap to sort',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: content,
                  ),
                ),
              )
            : content,
      ),
    );
  }
}

/// Page control. Hidden entirely when everything fits on one page.
class Pagination extends StatelessWidget {
  const Pagination({
    super.key,
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPage,
  });

  /// Zero-based.
  final int page;
  final int pageCount;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            'Page ${page + 1} of $pageCount · $total total',
            style: const TextStyle(fontSize: 12.5, color: kMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: page > 0 ? () => onPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
              ),
              IconButton(
                onPressed: page < pageCount - 1 ? () => onPage(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Row actions shared by every directory table.
class RowActions extends StatelessWidget {
  const RowActions({
    super.key,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    this.extra = const [],
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Additional entries for the overflow menu, e.g. activate/deactivate.
  final List<({String label, IconData icon, VoidCallback onTap})> extra;

  @override
  Widget build(BuildContext context) {
    // Each control is boxed to an exact size: IconButton adds its own
    // visual-density padding on top of `constraints`, which overflows a
    // compact actions column.
    Widget box(Widget child) => SizedBox(width: 32, height: 32, child: child);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        box(IconButton(
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          tooltip: 'View',
          color: kMuted,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
        )),
        box(IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit',
          color: kMuted,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(),
        )),
        MenuAnchor(
          style: const MenuStyle(
            backgroundColor: WidgetStatePropertyAll(kSurfaceElevated),
          ),
          menuChildren: [
            for (final e in extra)
              MenuItemButton(
                onPressed: e.onTap,
                leadingIcon: Icon(e.icon, size: 18, color: kMuted),
                child: Text(e.label, style: const TextStyle(fontSize: 14)),
              ),
            MenuItemButton(
              onPressed: onDelete,
              leadingIcon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: kDanger,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 14, color: kDanger),
              ),
            ),
          ],
          builder: (context, controller, _) => box(IconButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.more_horiz, size: 18),
            tooltip: 'More actions',
            color: kMuted,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
          )),
        ),
      ],
    );
  }
}

/// Small circular initials avatar, used in user and customer rows.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 16});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: kIndigo.withValues(alpha: .12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * .75,
          fontWeight: FontWeight.w700,
          color: kIndigo,
        ),
      ),
    );
  }
}

/// The toolbar above every directory table: search on the left, filters and a
/// primary action on the right. Wraps rather than overflowing on narrow views.
class TableToolbar extends StatelessWidget {
  const TableToolbar({
    super.key,
    required this.search,
    this.filters = const [],
    this.action,
  });

  final Widget search;
  final List<Widget> filters;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        search,
        ...filters,
        if (action != null) action!,
      ],
    );
  }
}

/// Scaffolding every directory page shares: title, description, primary
/// action, KPI row, then the panel holding toolbar + table + pagination.
class DirectoryScaffold extends StatelessWidget {
  const DirectoryScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.kpis,
    required this.child,
    this.action,
  });

  final String title;
  final String description;

  /// Already-built KPI cards.
  final List<Widget> kpis;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14.5, color: kMuted),
                ),
              ],
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 20),
        if (kpis.isNotEmpty) ...[
          KpiRow(cards: kpis),
          const SizedBox(height: 16),
        ],
        FadeIn(delay: Motion.stagger * 2, child: Panel(child: child)),
      ],
    );
  }
}

/// Responsive KPI strip: as many per row as fit, stacking to one on mobile.
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.cards, this.minCardWidth = 210});

  final List<Widget> cards;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        // Fit as many whole cards as the width allows, never more than we have.
        var columns = ((c.maxWidth + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, cards.length);
        // Avoid a lone orphan on the last row (5 cards in 4 columns): pull the
        // count down until the remainder is 0 or at least 2.
        while (columns > 2 &&
            cards.length % columns == 1 &&
            cards.length > columns) {
          columns--;
        }
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, card) in cards.indexed)
              SizedBox(
                width: width,
                child: FadeIn(delay: Motion.stagger * i, child: card),
              ),
          ],
        );
      },
    );
  }
}
