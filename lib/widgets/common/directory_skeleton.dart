import 'package:flutter/material.dart';

import './parts.dart';
import './data_table.dart';
import '../../main.dart';

/// Loading placeholder for a directory screen: a title, a KPI row and a table.
///
/// Lives here rather than in one feature because four features render it.
class DirectorySkeleton extends StatelessWidget {
  const DirectorySkeleton({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        const SizedBox(height: 20),
        KpiRow(
          cards: [for (var i = 0; i < 4; i++) const SkeletonPanel(lines: 2)],
        ),
        const SizedBox(height: 16),
        const SkeletonPanel(lines: 6, height: 320),
      ],
    );
  }
}
