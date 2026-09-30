import 'package:flutter/foundation.dart';

/// Tenant (organization) identity for the multi-tenant platform.
///
/// Every tenant-scoped request carries [Tenant.id]. The rule the whole
/// platform depends on: a principal signed into tenant A must never receive
/// tenant B's data.
///
/// SECURITY: the client-side tenant id is a *convenience*, not an isolation
/// boundary. It tells the API which tenant the user is acting in; the server
/// must derive the authoritative tenant from the session token and reject any
/// request whose claimed tenant does not match. A client that sets its own
/// tenant header can otherwise read every tenant on the platform.
@immutable
class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    this.plan = 'Enterprise',
    this.region = 'ap-south-1',
    this.slug = '',
  });

  /// Workspace name used at sign-in (`<slug>.oneenterprise.io`).
  final String slug;

  /// Stable tenant identifier, sent as `X-Tenant-Id`.
  final String id;

  /// Display name, shown in the header's tenant indicator.
  final String name;

  /// Subscription tier this tenant is on.
  final String plan;

  /// Data residency region — which regional deployment holds its records.
  final String region;

  /// Short label for the header chip when space is tight.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.characters(2);
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is Tenant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tenant($id, $name)';
}

extension on String {
  /// First [n] characters, upper-cased, without risking a range error on a
  /// short string.
  String characters(int n) =>
      substring(0, n > length ? length : n).toUpperCase();
}
