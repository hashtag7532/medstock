import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const actionTaken = 'taken';
const actionSkipped = 'skipped';
const actionStopped = 'stopped';
const _darwinCategory = 'dose';

/// A button press on a dose reminder, waiting to be applied.
class QueuedResponse {
  const QueuedResponse(this.scheduleId, this.doseKey, this.action);

  final int scheduleId;

  /// Local dose time as ISO string (see `doseKey`).
  final String doseKey;
  final String action;
}

/// Called by the plugin in a separate background engine when a reminder
/// button is pressed while the app isn't running. It only appends to the
/// queue file (plain dart:io, no plugins); the app applies it on next start
/// or resume.
@pragma('vm:entry-point')
Future<void> onBackgroundDoseResponse(NotificationResponse response) => DoseNotifications.enqueue(response);

class DoseNotifications {
  DoseNotifications(this._queueFile);

  final File _queueFile;
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Set by the dose service: process the queue now (app in foreground).
  VoidCallback? onResponse;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // India-first app: a sensible default if the zone can't be read.
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(_darwinCategory, actions: [
              DarwinNotificationAction.plain(actionTaken, 'Yes, taken'),
              DarwinNotificationAction.plain(actionSkipped, 'Skipped'),
              DarwinNotificationAction.plain(actionStopped, 'Stopped taking',
                  options: {DarwinNotificationActionOption.destructive}),
            ]),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) async {
        await enqueue(response);
        onResponse?.call();
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundDoseResponse,
    );
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: true) ?? false;
  }

  Future<void> scheduleDose({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required int scheduleId,
    required String doseKey,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      title: title,
      body: body,
      payload: jsonEncode({'q': _queueFile.path, 's': scheduleId, 't': doseKey}),
      // A few minutes' slack is fine for a dose reminder and avoids the
      // exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_reminders',
          'Dose reminders',
          channelDescription: 'Reminders to take your medicines',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: [
            AndroidNotificationAction(actionTaken, 'Yes, taken'),
            AndroidNotificationAction(actionSkipped, 'Skipped'),
            AndroidNotificationAction(actionStopped, 'Stopped taking'),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: _darwinCategory),
      ),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// Cancels scheduled reminders; reminders already showing stay visible.
  Future<void> cancelAllPending() => _plugin.cancelAllPendingNotifications();

  /// Appends a button press to the queue named in the payload.
  static Future<void> enqueue(NotificationResponse response) async {
    final action = response.actionId;
    final payload = response.payload;
    if (action == null || payload == null) return; // tapped the body: just opens the app
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final line = jsonEncode({'s': data['s'], 't': data['t'], 'a': action});
    await File(data['q'] as String).writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  /// Takes everything queued so far. Renames first so presses arriving
  /// meanwhile go to a fresh file and aren't lost.
  Future<List<QueuedResponse>> drainQueue() async {
    if (!await _queueFile.exists()) return const [];
    final taken = await _queueFile.rename('${_queueFile.path}.${DateTime.now().microsecondsSinceEpoch}');
    final lines = await taken.readAsLines();
    await taken.delete();
    return [
      for (final line in lines.where((l) => l.trim().isNotEmpty))
        if (jsonDecode(line) case {'s': final int s, 't': final String t, 'a': final String a}) QueuedResponse(s, t, a),
    ];
  }
}
