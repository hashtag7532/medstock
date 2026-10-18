import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

/// App bar button showing sync status; opens the account sheet.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: services.sync.state,
      builder: (context, state, _) => IconButton(
        tooltip: 'Account and sync',
        icon: Badge(
          isLabelVisible: state == SyncState.offline || state == SyncState.error,
          smallSize: 8,
          child: const Icon(Icons.account_circle_outlined),
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => AccountSheet(services: services),
        ),
      ),
    );
  }
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.services});

  final AppServices services;

  String _status(SyncState state) {
    final last = services.sync.lastSynced;
    final when = last == null
        ? ''
        : ' at ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}, ${formatDay(last)}';
    return switch (state) {
      SyncState.idle => 'Not synced yet',
      SyncState.syncing => 'Syncing...',
      SyncState.synced => 'Backed up$when',
      SyncState.offline => 'Offline: changes are saved on this phone and will sync later',
      SyncState.error => 'Sync failed: ${services.sync.lastError}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<SyncState>(
        valueListenable: services.sync.state,
        builder: (context, state, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(services.user.phoneNumber ?? 'Signed in'),
            subtitle: const Text('Your data is stored under this number'),
          ),
          ListTile(
            leading: Icon(switch (state) {
              SyncState.synced => Icons.cloud_done_outlined,
              SyncState.syncing => Icons.cloud_sync_outlined,
              SyncState.offline || SyncState.error => Icons.cloud_off_outlined,
              SyncState.idle => Icons.cloud_outlined,
            }),
            title: Text(_status(state)),
            trailing: TextButton(
              onPressed: state == SyncState.syncing ? null : services.sync.sync,
              child: const Text('Sync now'),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('Reminders stop on this phone until you sign in again. '
                      'Changes not yet backed up stay on this phone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              Navigator.of(context).pop();
              await services.sync.sync();
              await AuthService.signOut();
            },
          ),
        ]),
      ),
    );
  }
}
