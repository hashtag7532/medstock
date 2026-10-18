import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import '../services/dose_service.dart';
import '../widgets/medicine_widgets.dart';
import 'prescription_screens.dart';
import 'schedule_form_screen.dart';

/// Today's doses, unanswered ones, and running courses.
class DosesScreen extends StatefulWidget {
  const DosesScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<DosesScreen> createState() => _DosesScreenState();
}

class _DosesScreenState extends State<DosesScreen> {
  List<DoseOccurrence> _doses = [];
  List<CourseProgress> _courses = [];
  bool _loading = true;

  DoseService get _service => widget.services.doses;

  @override
  void initState() {
    super.initState();
    _load();
    _service.changes.addListener(_load);
  }

  @override
  void dispose() {
    _service.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final doses = await _service.dosesForToday();
    final courses = await _service.courses();
    if (!mounted) return;
    setState(() {
      _doses = doses;
      _courses = courses;
      _loading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _load();
  }

  Future<void> _addManually() async {
    final medicines = await widget.services.medicines.all();
    if (!mounted) return;
    if (medicines.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add the medicine to your cabinet first.')));
      return;
    }
    final picked = await showModalBottomSheet<Medicine>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Which medicine?')),
          for (final m in medicines)
            ListTile(
              leading: MedicineThumbnail(m, size: 36),
              title: Text(m.brandName),
              subtitle: Text('${m.quantity} ${m.unit} left'),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (picked != null) await _open(ScheduleFormScreen(services: widget.services, medicine: picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = _doses.where((d) => d.status == null && d.at.isBefore(now)).toList();
    final todays = _doses.where((d) => !d.at.isBefore(today) && !overdue.contains(d)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doses'),
        actions: [
          IconButton(tooltip: 'Add a schedule', icon: const Icon(Icons.alarm_add_outlined), onPressed: _addManually),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doses.isEmpty && _courses.isEmpty
              ? _EmptyDoses(onScan: () => _open(PrescriptionScanScreen(services: widget.services)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (overdue.isNotEmpty) ...[
                      _Header('Did you take these?', theme),
                      for (final d in overdue) _DoseCard(d, service: _service),
                      const SizedBox(height: 16),
                    ],
                    _Header('Today', theme),
                    if (todays.isEmpty) const Text('No more doses today.'),
                    for (final d in todays) _DoseCard(d, service: _service),
                    const SizedBox(height: 16),
                    if (_courses.isNotEmpty) _Header('Courses', theme),
                    for (final c in _courses)
                      _CourseCard(
                        c,
                        onTap: () => _open(ScheduleFormScreen(
                          services: widget.services,
                          medicine: c.medicine,
                          existing: c.schedule,
                        )),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Scan prescription'),
        onPressed: () => _open(PrescriptionScanScreen(services: widget.services)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: theme.textTheme.titleMedium));
}

class _DoseCard extends StatelessWidget {
  const _DoseCard(this.dose, {required this.service});

  final DoseOccurrence dose;
  final DoseService service;

  @override
  Widget build(BuildContext context) {
    final m = dose.medicine;
    final s = dose.schedule;
    final time = DoseTime(dose.at.hour, dose.at.minute).label;
    final day = DateTime.now().day == dose.at.day ? time : '${dose.at.day} ${monthNames[dose.at.month - 1]}, $time';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          MedicineThumbnail(m, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text([
                day,
                qty(s.dosePerIntake, m.unit),
                if (s.instructions.isNotEmpty) s.instructions,
              ].join(' · ')),
            ]),
          ),
          switch (dose.status) {
            DoseStatus.taken => const Chip(avatar: Icon(Icons.check, size: 18), label: Text('Taken')),
            DoseStatus.skipped => const Chip(avatar: Icon(Icons.redo, size: 18), label: Text('Skipped')),
            null => Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Skipped',
                  icon: const Icon(Icons.close),
                  onPressed: () => service.respond(dose, DoseStatus.skipped),
                ),
                IconButton.filled(
                  tooltip: 'Yes, taken',
                  icon: const Icon(Icons.check),
                  onPressed: () => service.respond(dose, DoseStatus.taken),
                ),
              ]),
          },
        ]),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard(this.course, {required this.onTap});

  final CourseProgress course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = course.schedule;
    final m = course.medicine;
    final total = s.totalDoses;
    final day = s.dayNumber(DateTime.now()).clamp(1, s.durationDays ?? 1 << 30);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(m.brandName, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(s.isOngoing ? 'Ongoing' : 'Day $day of ${s.durationDays}'),
            ]),
            const SizedBox(height: 4),
            Text('${qty(s.dosePerIntake, m.unit)} at ${s.times.map((t) => t.label).join(', ')}'),
            if (total != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (course.taken + course.skipped) / total),
              const SizedBox(height: 4),
              Text('${course.taken} taken, ${course.skipped} skipped of $total doses',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 4),
            Text(
              course.runsShort
                  ? 'Only ${qty(m.quantity, m.unit)} left; need ${course.unitsNeeded} to finish'
                  : '${qty(m.quantity, m.unit)} left',
              style: TextStyle(color: course.runsShort ? Colors.orange.shade900 : null),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyDoses extends StatelessWidget {
  const _EmptyDoses({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.alarm_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No dose schedules', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Scan a prescription to set up reminders. Each "Yes, taken" reduces what is left in your cabinet.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onScan, child: const Text('Scan prescription')),
        ]),
      ),
    );
  }
}
