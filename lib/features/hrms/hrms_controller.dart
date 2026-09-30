import 'services/hrms_audit.dart';
import 'services/hrms_repository.dart';

/// Holds the one [HrmsRepository] and the one [HrmsAuditLog] for the HRMS
/// section, so every HRMS screen reads and writes the same in-memory store and
/// records to the same audit trail.
///
/// Created once by the dashboard shell and passed down. Not a provider —
/// there's a single consumer subtree and passing it explicitly keeps the
/// dependency visible.
class HrmsController {
  HrmsController({HrmsRepository? repository, this.actor = 'System'})
      : repo = repository ?? DemoHrmsRepository();

  final HrmsRepository repo;
  final HrmsAuditLog audit = HrmsAuditLog();

  /// The signed-in user's name, stamped onto every audit entry.
  final String actor;

  void log({
    required String action,
    required String entity,
    required String entityId,
    required String summary,
  }) =>
      audit.record(
        actor: actor,
        action: action,
        entity: entity,
        entityId: entityId,
        summary: summary,
      );
}

/// CSV text for [rows] with [headers]. Values are quoted and internal quotes
/// doubled, per RFC 4180.
///
/// ponytail: returns the text; it does not save a file. A frontend-only Flutter
/// build has no portable download API — wire this to `dart:html` anchor
/// download on web, or a share/save plugin on mobile, when a target exists.
String toCsv(List<String> headers, Iterable<List<Object?>> rows) {
  String cell(Object? v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  final buffer = StringBuffer()..writeln(headers.map(cell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(cell).join(','));
  }
  return buffer.toString();
}

/// `$62,000` — whole-currency, thousands-separated.
String money(int amount) {
  final digits = amount.abs().toString();
  final withSeparators = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '${amount < 0 ? '-' : ''}\$$withSeparators';
}

/// `9:04 AM` style clock, or `—` for null.
String clock(DateTime? t) {
  if (t == null) return '—';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}
