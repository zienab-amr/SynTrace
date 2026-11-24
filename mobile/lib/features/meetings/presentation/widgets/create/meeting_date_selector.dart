import 'package:flutter/material.dart';

class MeetingDateSelector extends StatelessWidget {
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  const MeetingDateSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(2000);

    final initialDate = value.isAfter(now)
        ? now
        : value.isBefore(firstDate)
        ? firstDate
        : value;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
    );

    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );

    if (time == null || !context.mounted) return;

    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (result.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting date cannot be in the future.')),
      );
      return;
    }

    onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    final date = localizations.formatMediumDate(value);

    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value));

    return InkWell(
      onTap: enabled ? () => _selectDate(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          enabled: enabled,
          labelText: 'Meeting Date & Time',
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
          border: const OutlineInputBorder(),
        ),
        child: Text('$date • $time'),
      ),
    );
  }
}
