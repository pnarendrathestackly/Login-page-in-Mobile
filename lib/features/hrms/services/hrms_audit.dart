import 'package:flutter/foundation.dart';

/// One recorded mutation in the HRMS service.
@immutable
class AuditEntry {
  const AuditEntry({
    required this.at,
    required this.actor,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.summary,
  });

  final DateTime at;

  /// Who did it — the signed-in user's name, or 'System'.
  final String actor;

  /// CREATE / UPDATE / DELETE / APPROVE / REJECT / ASSIGN / …
  final String action;

  /// 'Employee', 'LeaveRequest', 'PayrollRun', …
  final String entity;
  final String entityId;

  /// Human sentence for the activity feed.
  final String summary;
}

/// In-memory audit trail for HRMS mutations.
///
/// Frontend-only: this is not a durable log. A real deployment posts each entry
/// to an audit service. It is a [ChangeNotifier] so the activity panels refresh
/// the moment a mutation records one.
class HrmsAuditLog extends ChangeNotifier {
  final List<AuditEntry> _entries = [];

  /// Newest first.
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  /// Entries for one record, newest first — powers "history" on a detail view.
  List<AuditEntry> forEntity(String entity, String entityId) => [
        for (final e in _entries)
          if (e.entity == entity && e.entityId == entityId) e,
      ];

  void record({
    required String actor,
    required String action,
    required String entity,
    required String entityId,
    required String summary,
  }) {
    _entries.insert(
      0,
      AuditEntry(
        at: DateTime.now(),
        actor: actor,
        action: action,
        entity: entity,
        entityId: entityId,
        summary: summary,
      ),
    );
    notifyListeners();
  }
}
