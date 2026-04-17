/// Battery Optimization & OEM Auto-Start Manager
///
/// Handles:
/// 1. Requesting Android battery optimization exemption (system dialog)
/// 2. Detecting OEM (Xiaomi, Samsung, Huawei, etc.) and opening their
///    proprietary auto-start / background manager settings
/// 3. Showing a one-time in-app guide if user hasn't granted exemption
///
/// Call [ensureBackgroundPermissions] after login to trigger the flow.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class BatteryOptimizerService {
  static const _prefKey = 'battery_opt_prompt_count';
  static const _maxPrompts = 3; // Don't annoy the user forever

  /// Main entry point — call after login / on dashboard init
  static Future<void> ensureBackgroundPermissions(BuildContext context) async {
    try {
      // Check if already exempted
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        AppLogger.info(
          LogCategory.lifecycle,
          'Battery optimization already disabled ✓',
        );
        return;
      }

      // Check prompt count
      final prefs = await SharedPreferences.getInstance();
      final promptCount = prefs.getInt(_prefKey) ?? 0;
      if (promptCount >= _maxPrompts) {
        AppLogger.info(
          LogCategory.lifecycle,
          'Battery optimization prompt suppressed (shown $promptCount times)',
        );
        return;
      }

      // Show the in-app explanation dialog FIRST, then trigger system prompt
      if (context.mounted) {
        final userAccepted = await _showExplanationDialog(context);
        if (userAccepted) {
          // Trigger Android system dialog
          final result =
              await Permission.ignoreBatteryOptimizations.request();
          AppLogger.info(
            LogCategory.lifecycle,
            'Battery optimization result: $result',
          );

          // After system dialog, also try OEM auto-start settings
          if (context.mounted) {
            await _handleOemAutoStart(context);
          }
        }
      }

      // Increment prompt counter
      await prefs.setInt(_prefKey, promptCount + 1);
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        'Battery optimization flow error: $e',
      );
    }
  }

  /// Shows a friendly explanation dialog before the system prompt
  static Future<bool> _showExplanationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.shield, color: Colors.green, size: 48),
        title: const Text(
          'Keep Protection Active',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'ElderSaathi needs to run in the background to protect you from scam SMS and calls 24/7.\n\n'
          'Please allow "Unrestricted" battery usage on the next screen so your protection stays active even when the app is closed.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Allow'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Detects OEM and tries to open their proprietary auto-start settings
  static Future<void> _handleOemAutoStart(BuildContext context) async {
    try {
      final manufacturer = await _getDeviceManufacturer();
      final intent = _getOemAutoStartIntent(manufacturer);

      if (intent != null && context.mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.phone_android, color: Colors.orange, size: 40),
            title: Text(
              '${_capitalize(manufacturer)} Extra Step',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Your ${_capitalize(manufacturer)} device may stop background apps aggressively.\n\n'
              'Please enable "Auto-start" for ElderSaathi in the next screen to ensure uninterrupted scam protection.',
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpen == true) {
          try {
            const platform = MethodChannel('com.eldercare.battery');
            await platform.invokeMethod('openAutoStart', {
              'package': intent['package'],
              'class': intent['class'],
            });
          } catch (e) {
            // If specific OEM intent fails, open generic app settings
            await openAppSettings();
          }
        }
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        'OEM auto-start handling failed: $e',
      );
    }
  }

  /// Gets device manufacturer string
  static Future<String> _getDeviceManufacturer() async {
    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.eldercare.battery');
        final manufacturer =
            await platform.invokeMethod<String>('getManufacturer');
        return (manufacturer ?? 'unknown').toLowerCase();
      }
    } catch (_) {}
    return 'unknown';
  }

  /// Returns OEM-specific intent for auto-start settings
  static Map<String, String>? _getOemAutoStartIntent(String manufacturer) {
    final intents = {
      'xiaomi': {
        'package': 'com.miui.securitycenter',
        'class':
            'com.miui.permcenter.autostart.AutoStartManagementActivity',
      },
      'oppo': {
        'package': 'com.coloros.safecenter',
        'class':
            'com.coloros.safecenter.permission.startup.StartupAppListActivity',
      },
      'vivo': {
        'package': 'com.vivo.permissionmanager',
        'class':
            'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
      },
      'huawei': {
        'package': 'com.huawei.systemmanager',
        'class':
            'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
      },
      'samsung': {
        'package': 'com.samsung.android.lool',
        'class':
            'com.samsung.android.sm.battery.ui.BatteryActivity',
      },
      'realme': {
        'package': 'com.coloros.safecenter',
        'class':
            'com.coloros.safecenter.permission.startup.StartupAppListActivity',
      },
      'oneplus': {
        'package': 'com.oneplus.security',
        'class':
            'com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity',
      },
    };

    return intents[manufacturer];
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
