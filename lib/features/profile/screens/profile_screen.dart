import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../auth.dart';
import '../../../main.dart';
import '../../../widgets.dart';
import '../../../widgets/common/data_table.dart';
import '../../../widgets/common/dialogs.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../../widgets/common/parts.dart';
import '../../../widgets/sidebar/app_sidebar.dart';

/// The signed-in user's profile.
///
/// Identity (name, email, role) comes from the session — nothing here is
/// hardcoded. The employment details below it are workspace metadata a real
/// backend would return alongside the account.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.activity,
    required this.loading,
  });

  final AuthUser user;

  /// Recent actions by this person, from the shared activity feed.
  final List<Activity> activity;
  final bool loading;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Editable workspace profile. Seeded from the session where the session
  // knows the value, and held locally until a profile API exists to persist it.
  late Map<String, String> _details = {
    'Phone': '+91 98450 11234',
    'Job title': widget.user.role,
    'Department': 'Platform',
    'Employee ID': 'EMP-1001',
    'Location': 'Bengaluru, India',
    'Time zone': 'Asia/Kolkata (GMT+5:30)',
    'Joining date': '14 Mar 2022',
  };

  Future<void> _edit() async {
    final values = await showFormDialog(
      context,
      title: 'Edit Profile',
      subtitle: 'Update your workspace details.',
      submitLabel: 'Save changes',
      fields: [
        FormFieldSpec(
          label: 'Phone',
          icon: Icons.phone_outlined,
          initial: _details['Phone']!,
          keyboardType: TextInputType.phone,
        ),
        FormFieldSpec(
          label: 'Job title',
          icon: Icons.badge_outlined,
          initial: _details['Job title']!,
        ),
        FormFieldSpec(
          label: 'Department',
          icon: Icons.apartment_outlined,
          initial: _details['Department']!,
        ),
        FormFieldSpec(
          label: 'Location',
          icon: Icons.place_outlined,
          initial: _details['Location']!,
        ),
        FormFieldSpec(
          label: 'Time zone',
          icon: Icons.schedule_outlined,
          initial: _details['Time zone']!,
        ),
      ],
    );
    if (values == null || !mounted) return;
    setState(() => _details = {..._details, ...values});
    if (mounted) showToast(context, 'Profile updated.');
  }

  static const _photoTypes = ['png', 'jpg', 'jpeg'];
  static const _maxPhotoBytes = 5 * 1024 * 1024;

  Future<void> _changePhoto() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _photoTypes,
      );
    } catch (_) {
      if (mounted) {
        showToast(context, 'Unable to open the file picker.', isError: true);
      }
      return;
    }
    if (file == null || !mounted) return; // cancelled
    final ext = (file.extension ?? '').toLowerCase().replaceAll('.', '');
    if (!_photoTypes.contains(ext)) {
      showToast(context, 'Unsupported file format. Use a PNG or JPG image.',
          isError: true);
      return;
    }
    if ((await file.length() ?? 0) > _maxPhotoBytes) {
      if (mounted) {
        showToast(context, 'File size exceeds the 5MB limit.', isError: true);
      }
      return;
    }
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (mounted) {
        showToast(context, 'File upload failed. Please try again.',
            isError: true);
      }
      return;
    }
    profilePhotos.value = {...profilePhotos.value, widget.user.email: bytes};
    if (mounted) showToast(context, 'Profile photo updated.');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    // Only this person's entries from the shared feed.
    final mine = [
      for (final a in widget.activity)
        if (a.actor == user.name) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Profile',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your account and workspace details.',
          style: TextStyle(fontSize: 14.5, color: kMuted),
        ),
        const SizedBox(height: 20),

        // --- Header card -----------------------------------------------------
        Panel(
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 620;
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: profilePhotos,
                        builder: (context, photos, _) {
                          final photo = photos[user.email];
                          return photo == null
                              ? InitialsAvatar(name: user.name, radius: 34)
                              : CircleAvatar(
                                  radius: 34,
                                  backgroundImage: MemoryImage(photo),
                                );
                        },
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: kSurfaceElevated,
                          shape: const CircleBorder(
                            side: BorderSide(color: kBorder),
                          ),
                          child: InkWell(
                            onTap: _changePhoto,
                            customBorder: const CircleBorder(),
                            child: const Tooltip(
                              message: 'Change profile photo',
                              child: Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 14,
                                  color: kIndigo,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_details['Job title']} · ${_details['Department']}',
                          style: const TextStyle(fontSize: 14, color: kMuted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(
                              icon: Icons.mail_outline,
                              text: user.email,
                            ),
                            _Chip(
                              icon: Icons.place_outlined,
                              text: _details['Location']!,
                            ),
                            const StatusPill(
                              label: 'Active',
                              color: kSuccess,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final editButton = FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: kIndigo,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );

              return narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 16),
                        editButton,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 16),
                        editButton,
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 16),

        // --- Detail sections -------------------------------------------------
        LayoutBuilder(
          builder: (context, c) {
            final personal = _InfoPanel(
              title: 'Personal Information',
              rows: {
                'Full name': user.name,
                'Employee ID': _details['Employee ID']!,
                'Location': _details['Location']!,
              },
            );
            final contact = _InfoPanel(
              title: 'Contact Information',
              rows: {
                'Email': user.email,
                'Phone': _details['Phone']!,
                'Time zone': _details['Time zone']!,
              },
            );
            final professional = _InfoPanel(
              title: 'Professional Information',
              rows: {
                'Job title': _details['Job title']!,
                'Department': _details['Department']!,
                'Joining date': _details['Joining date']!,
              },
            );
            final account = _InfoPanel(
              title: 'Account Information',
              rows: {
                'Role': user.role,
                'Two-step verification': 'Enabled',
                'Account status': 'Active',
              },
            );

            if (c.maxWidth < 900) {
              return Column(
                children: [
                  personal,
                  const SizedBox(height: 16),
                  contact,
                  const SizedBox(height: 16),
                  professional,
                  const SizedBox(height: 16),
                  account,
                ],
              );
            }
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: personal),
                    const SizedBox(width: 16),
                    Expanded(child: contact),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: professional),
                    const SizedBox(width: 16),
                    Expanded(child: account),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // --- Recent activity -------------------------------------------------
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Recent Activity',
                subtitle: 'Your latest actions across the platform.',
              ),
              const SizedBox(height: 8),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Skeleton(height: 34, radius: 10),
                      SizedBox(height: 10),
                      Skeleton(height: 34, radius: 10),
                    ],
                  ),
                )
              else if (mine.isEmpty)
                const EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No recent activity',
                  message: 'Actions you take across the platform appear here.',
                )
              else
                for (final a in mine)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: kIndigo.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(a.icon, size: 16, color: kIndigo),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You ${a.description}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: kInk,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                relativeTime(a.at),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kInset,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kMuted),
          const SizedBox(width: 6),
          // Flexible: an email or full time-zone name can be wider than the
          // chip's share of a phone-width row.
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: kInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value list inside a panel — the repeated shape on this page.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 6),
          for (final (i, entry) in rows.entries.indexed) ...[
            if (i > 0) const Divider(color: kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              // Wraps on narrow panels: a fixed label column plus a long value
              // (an email, a time zone) does not fit a phone-width card.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 2,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 13, color: kMuted),
                  ),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
