import 'package:flutter/material.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'core/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: SupabaseConfig.url,
  );
  const key = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: SupabaseConfig.publishableKey,
  );
  final query = Uri.base.queryParameters;
  final backendInitialization = Backend.initializeIfConfigured(
    url: url,
    key: key,
  );
  runApp(BuildHiveApp(
    backendConfigured: false,
    backendInitialization: backendInitialization,
    initialTab: const {'success', 'cancelled'}
                .contains(query['payment_return']) &&
            (query['order_id']?.isNotEmpty ?? false)
        ? 3
        : 0,
  ));
}
