import 'package:flutter/material.dart';

import '../../../auth.dart';
import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/dialogs.dart';
import '../../../widgets/common/parts.dart';

/// Workspace and account settings, grouped into tabs.
///
/// ponytail: preferences live in widget state only — there is no settings
/// endpoint to persist them to, and inventing one would fake durability the
/// app does not have. Each toggle is ready to call a real API when it exists.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.user,
    required this.controller,
  });

  final AuthUser user;

  /// Existing auth controller — sign-out and session actions run through it.
  final AuthController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _Tab {
  general('General', Icons.tune_outlined),
  account('Account', Icons.person_outline),
  notifications('Notifications', Icons.notifications_none),
  security('Security', Icons.lock_outline),
  appearance('Appearance', Icons.palette_outlined),
  roles('Roles', Icons.admin_panel_settings_outlined),
  danger('Danger Zone', Icons.warning_amber_outlined);

  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SettingsPageState extends State<SettingsPage> {
  _Tab _tab = _Tab.general;

  // General
  String _language = 'English (UK)';
  String _timeZone = 'Asia/Kolkata (GMT+5:30)';
  String _dateFormat = 'DD MMM YYYY';

  // Notifications
  final _notify = {
    'Email notifications': true,
    'Task assignments and updates': true,
    'Project status changes': true,
    'Customer account activity': false,
    'System and maintenance alerts': true,
  };

  // Security
  bool _loginAlerts = true;

  // Appearance
  bool _compact = false;

  void _saved(String what) => showToast(context, '$what saved.');

  Future<void> _changePassword() async {
    final values = await showFormDialog(
      context,
      title: 'Change Password',
      subtitle: 'You will stay signed in on this device.',
      submitLabel: 'Update password',
      fields: const [
        FormFieldSpec(
          label: 'Current password',
          icon: Icons.lock_outline,
        ),
        FormFieldSpec(label: 'New password', icon: Icons.lock_reset_outlined),
      ],
    );
    if (values == null || !mounted) return;
    // ponytail: no password endpoint on the demo backend. Reports honestly
    // rather than pretending the change was applied.
    showToast(
      context,
      'Password changes are not connected to a backend yet.',
    );
  }

  Future<void> _signOutEverywhere() async {
    final ok = await confirm(
      context,
      title: 'Sign out of all sessions?',
      message: 'You will be signed out on every device, including this one.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !mounted) return;
    // Runs the existing sign-out; the router returns to login.
    await widget.controller.signOut();
  }

  Future<void> _deactivate() async {
    final ok = await confirm(
      context,
      title: 'Deactivate your account?',
      message: 'Your account will be disabled and you will be signed out. An '
          'administrator can reactivate it later.',
      confirmLabel: 'Deactivate',
    );
    if (!ok || !mounted) return;
    showToast(
      context,
      'Account deactivation is not connected to a backend yet.',
      isError: true,
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await confirm(
      context,
      title: 'Delete your account?',
      message: 'This permanently erases your account, profile and personal '
          'data. It cannot be undone.',
      confirmLabel: 'Delete account',
    );
    if (!ok || !mounted) return;
    showToast(
      context,
      'Account deletion is not connected to a backend yet.',
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Settings',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage your workspace, account and security preferences.',
          style: TextStyle(fontSize: 14.5, color: kMuted),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 860;
            final tabs = _TabList(
              current: _tab,
              vertical: wide,
              onSelect: (t) => setState(() => _tab = t),
            );
            final body = _body();

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tabs, const SizedBox(height: 16), body],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 220, child: tabs),
                const SizedBox(width: 16),
                Expanded(child: body),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _body() => switch (_tab) {
        _Tab.general => _Section(
            title: 'General',
            subtitle: 'Workspace defaults for everyone in this organization.',
            children: [
              _ReadOnlyRow(
                label: 'Application name',
                value: 'TheStackly',
                hint: 'Contact support to rename your workspace.',
              ),
              _ChoiceRow(
                label: 'Language',
                value: _language,
                options: const [
                  'English (UK)',
                  'English (US)',
                  'Deutsch',
                  'Français',
                ],
                onChanged: (v) {
                  setState(() => _language = v);
                  _saved('Language');
                },
              ),
              _ChoiceRow(
                label: 'Time zone',
                value: _timeZone,
                options: const [
                  'Asia/Kolkata (GMT+5:30)',
                  'Europe/London (GMT+0)',
                  'America/New_York (GMT-5)',
                  'Asia/Singapore (GMT+8)',
                ],
                onChanged: (v) {
                  setState(() => _timeZone = v);
                  _saved('Time zone');
                },
              ),
              _ChoiceRow(
                label: 'Date format',
                value: _dateFormat,
                options: const ['DD MMM YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
                onChanged: (v) {
                  setState(() => _dateFormat = v);
                  _saved('Date format');
                },
              ),
            ],
          ),
        _Tab.account => _Section(
            title: 'Account',
            subtitle: 'Your sign-in details and account preferences.',
            children: [
              _ReadOnlyRow(
                label: 'Email address',
                value: widget.user.email,
                hint: 'Used for sign-in and verification codes.',
              ),
              _ReadOnlyRow(label: 'Role', value: widget.user.role),
              _ActionRow(
                label: 'Password',
                description: 'Last changed 3 months ago.',
                actionLabel: 'Change password',
                onTap: _changePassword,
              ),
            ],
          ),
        _Tab.notifications => _Section(
            title: 'Notifications',
            subtitle: 'Choose what you want to be told about.',
            children: [
              for (final entry in _notify.entries)
                _ToggleRow(
                  label: entry.key,
                  value: entry.value,
                  onChanged: (v) {
                    setState(() => _notify[entry.key] = v);
                    _saved('Notification preference');
                  },
                ),
            ],
          ),
        _Tab.security => _Section(
            title: 'Security',
            subtitle: 'Protect your account and review active sessions.',
            children: [
              _ReadOnlyRow(
                label: 'Two-factor authentication',
                value: 'Enabled',
                hint: 'A code is sent to your email at every sign-in.',
              ),
              _ToggleRow(
                label: 'Login alerts',
                description: 'Email me when a new device signs in.',
                value: _loginAlerts,
                onChanged: (v) {
                  setState(() => _loginAlerts = v);
                  _saved('Login alerts');
                },
              ),
              const _SessionRow(
                device: 'Chrome on Windows',
                detail: 'Bengaluru, India · current session',
                current: true,
              ),
              const _SessionRow(
                device: 'Safari on iPhone',
                detail: 'Bengaluru, India · last active 2 days ago',
                current: false,
              ),
              _ActionRow(
                label: 'Active sessions',
                description: 'Sign out everywhere, including this device.',
                actionLabel: 'Sign out all',
                onTap: _signOutEverywhere,
              ),
            ],
          ),
        _Tab.appearance => _Section(
            title: 'Appearance',
            subtitle: 'How the workspace looks for you.',
            children: [
              _ReadOnlyRow(
                label: 'Theme',
                value: 'Light',
                hint: 'A dark theme is not available in this release.',
              ),
              _ToggleRow(
                label: 'Compact layout',
                description: 'Reduce padding to fit more rows on screen.',
                value: _compact,
                onChanged: (v) {
                  setState(() => _compact = v);
                  showToast(
                    context,
                    'Compact layout is not wired into the shell yet.',
                  );
                },
              ),
            ],
          ),
        _Tab.roles => _Section(
            title: 'Roles & Permissions',
            subtitle: 'Who can do what in this workspace.',
            children: const [
              _RoleRow(
                role: 'Administrator',
                members: 1,
                permissions: 'Full access, including billing and user removal',
              ),
              _RoleRow(
                role: 'Project Manager',
                members: 2,
                permissions: 'Create and manage projects, tasks and customers',
              ),
              _RoleRow(
                role: 'Member',
                members: 9,
                permissions: 'View assigned work and update own tasks',
              ),
              _RoleRow(
                role: 'Viewer',
                members: 2,
                permissions: 'Read-only access to dashboards and reports',
              ),
            ],
          ),
        _Tab.danger => _Section(
            title: 'Danger Zone',
            subtitle: 'Irreversible actions. Each one asks for confirmation.',
            danger: true,
            children: [
              _ActionRow(
                label: 'Deactivate account',
                description:
                    'Disable your account. An administrator can restore it.',
                actionLabel: 'Deactivate',
                destructive: true,
                onTap: _deactivate,
              ),
              _ActionRow(
                label: 'Delete account',
                description:
                    'Permanently erase your account and personal data.',
                actionLabel: 'Delete',
                destructive: true,
                onTap: _deleteAccount,
              ),
            ],
          ),
      };
}

/// Tab picker. A vertical rail on desktop, a scrolling strip on narrow views.
class _TabList extends StatelessWidget {
  const _TabList({
    required this.current,
    required this.vertical,
    required this.onSelect,
  });

  final _Tab current;
  final bool vertical;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!vertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _Tab.values) ...[
              _TabButton(
                tab: t,
                selected: t == current,
                onTap: () => onSelect(t),
                compact: true,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
    }
    return Panel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in _Tab.values)
            _TabButton(
              tab: t,
              selected: t == current,
              onTap: () => onSelect(t),
              compact: false,
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final danger = tab == _Tab.danger;
    final accent = danger ? const Color(0xFFDC2626) : kIndigo;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 2),
      child: Material(
        color: selected ? accent.withValues(alpha: .10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Semantics(
            selected: selected,
            button: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: compact && !selected ? kBorder : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 18,
                    color: selected ? accent : kMuted,
                  ),
                  const SizedBox(width: 10),
                  // Flexible in the vertical rail, where a long label would
                  // otherwise overrun the fixed-width column; intrinsic in the
                  // horizontal strip, which scrolls instead.
                  Flexible(
                    fit: compact ? FlexFit.loose : FlexFit.tight,
                    child: Text(
                      tab.label,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? accent : kInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings panel: heading plus a divided list of rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.children,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: danger ? const Color(0xFFDC2626).withValues(alpha: .35) : kBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 6),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(color: kBorder, height: 1),
            child,
          ],
        ],
      ),
    );
  }
}

/// Label + value, for settings that cannot be edited here.
class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: const TextStyle(fontSize: 12.5, color: kMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, color: kMuted),
          ),
        ],
      ),
    );
  }
}

/// Label + dropdown, for settings with a fixed set of choices.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      // Wraps rather than overflowing: option labels such as full time-zone
      // names are wider than a narrow settings panel.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            constraints: const BoxConstraints(maxWidth: 240),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                isExpanded: true,
                borderRadius: BorderRadius.circular(10),
                icon: const Icon(Icons.expand_more, size: 18, color: kMuted),
                style: const TextStyle(fontSize: 13.5, color: kInk),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
                items: [
                  for (final o in options)
                    DropdownMenuItem(
                      value: o,
                      child: Text(o, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + switch.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: const TextStyle(fontSize: 12.5, color: kMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: kIndigo,
          ),
        ],
      ),
    );
  }
}

/// Label + button, for settings that open a dialog.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.description,
    required this.actionLabel,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? const Color(0xFFDC2626) : kIndigo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12.5, color: kMuted),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: .5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.device,
    required this.detail,
    required this.current,
  });

  final String device;
  final String detail;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            current ? Icons.computer_outlined : Icons.phone_iphone_outlined,
            size: 20,
            color: kMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12.5, color: kMuted),
                ),
              ],
            ),
          ),
          if (current)
            const StatusPill(label: 'This device', color: Color(0xFF059669)),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.members,
    required this.permissions,
  });

  final String role;
  final int members;
  final String permissions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  permissions,
                  style: const TextStyle(fontSize: 12.5, color: kMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$members ${members == 1 ? 'member' : 'members'}',
            style: const TextStyle(fontSize: 12.5, color: kMuted),
          ),
        ],
      ),
    );
  }
}
