import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:msu_wellbeing/core/logging/app_logger.dart';

/// Toggles Android `FLAG_SECURE` (blocks screenshots and recents previews)
/// through a small platform channel in `MainActivity`.
abstract final class SecureWindow {
  static const _channel = MethodChannel(
    'id.ac.telkomuniversity.msu.wellbeing/secure_window',
  );
  static int _holders = 0;

  static Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await _apply(secure: true);
  }

  static Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _apply(secure: false);
  }

  static Future<void> _apply({required bool secure}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // Not available in tests or on unsupported embedders.
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error('secure_window.apply', error, stackTrace);
    }
  }
}

/// Marks [child] as sensitive while it is visible.
///
/// Uses [TickerMode] so screens kept alive in an inactive tab (bottom-nav
/// `IndexedStack`) release the flag when the user switches away.
class SecureScreen extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  bool _holding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_holding) {
      _holding = true;
      unawaited(SecureWindow.acquire());
    } else if (!visible && _holding) {
      _holding = false;
      unawaited(SecureWindow.release());
    }
  }

  @override
  void dispose() {
    if (_holding) unawaited(SecureWindow.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
