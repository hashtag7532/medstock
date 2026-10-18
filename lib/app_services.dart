import 'dart:io';

import 'package:path/path.dart' as p;

import 'data/app_database.dart';
import 'data/medicine_repository.dart';
import 'data/report_repository.dart';
import 'data/schedule_repository.dart';
import 'services/claude_client.dart';
import 'services/claude_label_reader.dart';
import 'services/dose_notifications.dart';
import 'services/dose_service.dart';
import 'services/extraction_service.dart';
import 'services/lab_report_reader.dart';
import 'services/prescription_reader.dart';

/// Everything screens need, created once at startup.
class AppServices {
  AppServices._({
    required this.medicines,
    required this.reports,
    required this.doses,
    required this.extraction,
    this.labelReader,
    this.prescriptions,
    this.labReports,
  });

  final MedicineRepository medicines;
  final ReportRepository reports;
  final DoseService doses;
  final ExtractionService extraction;

  /// AI readers; null when no CLAUDE_API_KEY was provided.
  final ClaudeLabelReader? labelReader;
  final PrescriptionReader? prescriptions;
  final LabReportReader? labReports;

  bool get hasAi => labelReader != null;

  static Future<AppServices> create() async {
    final storage = await AppStorage.open();
    const key = String.fromEnvironment('CLAUDE_API_KEY');
    final claude = key.isEmpty ? null : ClaudeClient(apiKey: key);
    final labelReader = claude == null ? null : ClaudeLabelReader(claude);
    final medicines = MedicineRepository(storage.db, storage.labelPhotos);
    final doses = DoseService(
      ScheduleRepository(storage.db),
      medicines,
      DoseNotifications(File(p.join(storage.supportDir.path, 'dose_responses.jsonl'))),
    );
    return AppServices._(
      medicines: medicines,
      reports: ReportRepository(storage.db, storage.reportFiles),
      doses: doses,
      extraction: ExtractionService(claude: labelReader),
      labelReader: labelReader,
      prescriptions: claude == null ? null : PrescriptionReader(claude),
      labReports: claude == null ? null : LabReportReader(claude),
    );
  }
}
