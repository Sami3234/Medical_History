import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/supabase_config.dart';
import 'backup_service.dart';

class AccountExportService {
  static Future<bool> exportAndOpen() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null)
      throw StateError('Please sign in before exporting data.');
    final data = await BackupService().gatherBackupData(userId);
    final root = await getApplicationDocumentsDirectory();
    final file = File(
      '${root.path}${Platform.pathSeparator}medical_history_export_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    final result = await OpenFilex.open(file.path, type: 'application/json');
    return result.type == ResultType.done;
  }
}
