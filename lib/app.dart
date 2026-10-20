import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/onboarding/launch_flow.dart';

bool isPaymentReturnLink(Uri? uri) =>
  uri?.scheme == 'buildhive' &&
  uri?.host == 'payment-return' &&
  const {'success', 'cancelled'}.contains(uri?.queryParameters['payment_return']) &&
  (uri?.queryParameters['order_id']?.isNotEmpty ?? false);

class BuildHiveApp extends StatefulWidget {
  const BuildHiveApp({
    super.key,
    required this.backendConfigured,
    this.backendInitialization,
    this.initialTab = 0,
  });
  final bool backendConfigured;
  final Future<bool>? backendInitialization;
  final int initialTab;

  @override
  State<BuildHiveApp> createState() => _BuildHiveAppState();
}

class _BuildHiveAppState extends State<BuildHiveApp> {
  StreamSubscription<Uri>? _linkSubscription;
  late int _initialTab;
  late bool _backendConfigured;
  late bool _backendInitializationPending;
  bool _backendInitializationFailed = false;
  String? _backendInitializationError;

  @override
  void initState() {
    super.initState();
    _initialTab = widget.initialTab;
    _backendConfigured = widget.backendConfigured;
    final backendInitialization = widget.backendInitialization;
    _backendInitializationPending = backendInitialization != null;
    if (backendInitialization != null) {
      unawaited(_finishBackendInitialization(backendInitialization));
    }
    try {
      final appLinks = AppLinks();
      _linkSubscription = appLinks.uriLinkStream.listen((uri) {
        if (isPaymentReturnLink(uri)) setState(() => _initialTab = 3);
      });
      unawaited(_readInitialLink(appLinks));
    } catch (error, stackTrace) {
      debugPrint('App link setup failed: $error\n$stackTrace');
    }
  }

  Future<void> _finishBackendInitialization(Future<bool> initialization) async {
    try {
      final configured = await initialization;
      if (mounted) {
        setState(() {
          _backendConfigured = configured;
          _backendInitializationPending = false;
        });
      }
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _backendInitializationPending = false;
          _backendInitializationFailed = true;
          _backendInitializationError = error.toString();
        });
      }
      debugPrint('Supabase initialization failed: $error\n$stackTrace');
    }
  }

  Future<void> _readInitialLink(AppLinks appLinks) async {
    try {
      final uri = await appLinks.getInitialLink();
      if (mounted && isPaymentReturnLink(uri)) {
        setState(() => _initialTab = 3);
      }
    } catch (error, stackTrace) {
      debugPrint('Initial app link lookup failed: $error\n$stackTrace');
    }
  }

  @override
  void didUpdateWidget(covariant BuildHiveApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _initialTab = widget.initialTab;
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BUILDHIVE',
        debugShowCheckedModeBanner: false,
        theme: buildHiveTheme,
        builder: (context, child) => SafeArea(
          child: child ?? const SizedBox.shrink(),
        ),
        home: LaunchFlow(
          backendConfigured: _backendConfigured,
          backendInitializationPending: _backendInitializationPending,
          backendInitializationFailed: _backendInitializationFailed,
          backendInitializationError: _backendInitializationError,
          initialTab: _initialTab,
        ),
      );
}
