import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/widgets/common/dialogs.dart';

String iso(DateTime d) => d.toIso8601String().split('T').first;

void main() {
  final today = DateTime.now();

  test('dates must exist on the calendar', () {
    expect(validateIsoDate('2026-02-30'),
        '2026-02-30 is not a real calendar date.');
    expect(validateIsoDate('2026-13-01'), 'Month must be from 01 to 12.');
    expect(validateIsoDate('15-10-2026'), contains('YYYY-MM-DD'));
    expect(validateIsoDate('2028-02-29'), isNull); // leap year
    expect(parseIsoDate('2026-02-30'), isNull);
  });

  test('due date cannot be in the past', () {
    final past = iso(today.subtract(const Duration(days: 1)));
    expect(validateDueDate(past, {}), 'Due date cannot be in the past.');
    expect(validateDueDate(iso(today), {}), isNull);
  });

  test('leave end is checked against its start', () {
    final form = {'From (YYYY-MM-DD)': iso(today)};
    final before = iso(today.subtract(const Duration(days: 1)));
    expect(validateLeaveEnd(before, form),
        'End date cannot be before the start date.');
    expect(validateLeaveEnd(iso(today), form), isNull);
    expect(validateLeaveEnd(iso(today.add(const Duration(days: 200))), form),
        contains('180 days'));
  });

  test('numbers say what is wrong, per field', () {
    expect(validateDurationHours('abc'),
        'Duration must be a number, using digits only.');
    expect(validateDurationHours('2.5'),
        'Duration must be a whole number, without decimals.');
    expect(validateDurationHours('0'), 'Duration must be at least 1.');
    expect(validateDurationHours('900'), 'Duration cannot be more than 500.');
    expect(validateDecimalRating('6'), 'Rating must be between 1 and 5.');
    expect(validateDecimalRating('3.55'), contains('one decimal place'));
    expect(validatePercent('101'), 'Progress cannot be more than 100.');
  });

  test('check-out must follow check-in', () {
    final form = {'Check-in (HH:MM)': '09:30'};
    expect(validateCheckOut('09:00', form), contains('later than check-in'));
    expect(validateCheckOut('18:00', form), isNull);
    expect(validateTime('24:00'), 'Hour must be from 00 to 23.');
  });

  testWidgets('each invalid field shows its own message, no shared banner',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showFormDialog(
            context,
            title: 'Create',
            subtitle: '',
            fields: const [
              FormFieldSpec(
                  label: 'Due (YYYY-MM-DD)',
                  icon: Icons.event,
                  validator: validateIsoDate),
              FormFieldSpec(
                  label: 'Duration (hours)',
                  icon: Icons.schedule,
                  validator: validateDurationHours,
                  keyboardType: TextInputType.number),
              FormFieldSpec(label: 'Title', icon: Icons.title),
            ],
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '2026-02-30');
    // Letters are blocked outright in a number field.
    await tester.enterText(fields.at(1), 'x0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
        find.text('2026-02-30 is not a real calendar date.'), findsOneWidget);
    expect(find.text('Duration must be at least 1.'), findsOneWidget);
    expect(find.text('Title is required.'), findsOneWidget);
    expect(find.text('Please correct the highlighted fields.'), findsNothing);
  });
}
