import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'data/app_database.dart';
import 'data/medicine_repository.dart';
import 'data/report_repository.dart';
import 'data/schedule_repository.dart';
import 'services/api_client.dart';
import 'services/claude_client.dart';
import 'services/claude_label_reader.dart';
import 'services/dose_notifications.dart';
import 'services/dose_service.dart';
import 'services/extraction_service.dart';
import 'services/lab_report_reader.dart';
import 'services/prescription_reader.dart';
import 'services/sync_service.dart';

/// Everything screens need for the signed-in user, created at sign-in.
class AppServices {
  AppServices._({
    required this.user,
    required this.storage,
    required this.medicines,
    required this.reports,
    required this.doses,
    required this.sync,
    required this.extraction,
    this.labelReader,
    this.prescriptions,
    this.labReports,
  });

  final User user;
  final AppStorage storage;
  final MedicineRepository medicines;
  final ReportRepository reports;
  final DoseService doses;
  final SyncService sync;
  final ExtractionService extraction;

  /// AI readers; null when no CLAUDE_API_KEY was provided.
  final ClaudeLabelReader? labelReader;
  final PrescriptionReader? prescriptions;
  final LabReportReader? labReports;

  bool get hasAi => labelReader != null;

  static Future<AppServices> create(User user) async {
    final storage = await AppStorage.open(user.uid);
    const key = String.fromEnvironment('CLAUDE_API_KEY');
    final claude = key.isEmpty ? null : ClaudeClient(apiKey: key);
    final labelReader = claude == null ? null : ClaudeLabelReader(claude);
    final medicines = MedicineRepository(storage);
    final doses = DoseService(
      ScheduleRepository(storage),
      medicines,
      DoseNotifications(File(p.join(storage.supportDir.path, 'dose_responses.jsonl'))),
    );
    final sync = SyncService(
      storage,
      ApiClient(AppConfig.apiBaseUrl, () => user.getIdToken()),
      onRemoteChanges: doses.refreshAfterSync,
    );
    return AppServices._(
      user: user,
      storage: storage,
      medicines: medicines,
      reports: ReportRepository(storage),
      doses: doses,
      sync: sync,
      extraction: ExtractionService(claude: labelReader),
      labelReader: labelReader,
      prescriptions: claude == null ? null : PrescriptionReader(claude),
      labReports: claude == null ? null : LabReportReader(claude),
    );
  }

  Future<void> dispose() async {
    sync.dispose();
    await doses.shutdown();
    await storage.close();
  }
}
