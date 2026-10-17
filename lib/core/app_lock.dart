import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/theme.dart';

/// Result of one authentication attempt.
enum LockAuthResult {
  success,

  /// Cancelled, failed or interrupted: stay locked, the user can try again.
  retry,

  /// Too many attempts; the system blocks biometrics for a while.
  lockedOut,

  /// The phone has no screen lock any more, so there is nothing to verify
  /// against. The app lock cannot protect anything in that state.
  noCredentials,
}

/// Thin wrapper over local_auth so screens and tests can swap it out.
class AppLockService {
  final LocalAuthentication _auth;
  AppLockService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// True when the device has a screen lock (biometrics or PIN/pattern).
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Prompts for fingerprint / face, falling back to the device PIN.
  ///
  /// local_auth 3 reports a cancelled or interrupted prompt by throwing
  /// LocalAuthException, not by returning false; every outcome is mapped here
  /// so callers never see an exception.
  Future<LockAuthResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? LockAuthResult.success : LockAuthResult.retry;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noCredentialsSet:
          return LockAuthResult.noCredentials;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return LockAuthResult.lockedOut;
        default:
          return LockAuthResult.retry;
      }
    } catch (_) {
      return LockAuthResult.retry;
    }
  }
}

/// Shows a lock screen over [child] when app lock is enabled: on start and
/// when the app comes back from the background after longer than the
/// "Lock after" setting (immediately by default).
class LockGate extends StatefulWidget {
  final Widget child;
  final AppLockService? service;
  final DateTime Function() clock;
  const LockGate({
    required this.child,
    this.service,
    this.clock = DateTime.now,
    super.key,
  });

  /// When the app last went to the background, so the grace period also
  /// holds when the system kills the app in the background.
  static const backgroundAtKey = 'lock.backgroundAt';

  static int _externalFlows = 0;

  /// True while the app shows a system flow of its own (Google sign-in):
  /// its screens pause the app, but the user has not left it.
  static bool get inExternalFlow => _externalFlows > 0;

  /// Runs [flow] without the lock treating its system screens as leaving
  /// the app.
  static Future<T> duringExternalFlow<T>(Future<T> Function() flow) async {
    _externalFlows++;
    try {
      return await flow();
    } finally {
      _externalFlows--;
    }
  }

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late final AppLockService _service = widget.service ?? AppLockService();
  bool _locked = false;
  bool _prompting = false;
  bool _initialised = false;
  DateTime? _backgroundAt;

  /// Set only when the app really went to the background. System dialogs
  /// (the biometric prompt itself) send "resumed" too, and a cancelled prompt
  /// must not reopen by itself.
  bool _wasAway = false;
  String? _message;

  bool get _enabled =>
      context.read<AppSettings>().appLock &&
      context.read<AppSession>().isSignedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    if (!_enabled) return;
    // Lock at start unless the app left the screen less than the grace
    // period ago (the system may have killed it in the background).
    _locked = true;
    _restoreGrace();
  }

  Future<void> _restoreGrace() async {
    final timeout = context.read<AppSettings>().lockTimeout;
    var withinGrace = false;
    if (timeout > Duration.zero) {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(LockGate.backgroundAtKey);
      if (at != null) {
        final away = widget.clock().difference(
          DateTime.fromMillisecondsSinceEpoch(at),
        );
        withinGrace = !away.isNegative && away < timeout;
      }
    }
    if (!mounted) return;
    if (withinGrace) {
      setState(() => _locked = false);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || !_enabled) return;
    // The system PIN screen pauses the app too; that is not leaving it.
    // Neither are Google's sign-in screens.
    if (_prompting || LockGate.inExternalFlow) return;
    if (state == AppLifecycleState.paused) {
      _wasAway = true;
      if (_locked) return;
      final now = widget.clock();
      _backgroundAt = now;
      SharedPreferences.getInstance().then(
        (p) => p.setInt(LockGate.backgroundAtKey, now.millisecondsSinceEpoch),
      );
      // "Immediately" hides the content before the app is even gone.
      if (context.read<AppSettings>().lockTimeout == Duration.zero) {
        setState(() => _locked = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_wasAway) return;
      _wasAway = false;
      if (!_locked && _backgroundAt != null) {
        final away = widget.clock().difference(_backgroundAt!);
        if (away.isNegative ||
            away >= context.read<AppSettings>().lockTimeout) {
          setState(() => _locked = true);
        }
      }
      _backgroundAt = null;
      if (_locked) _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_prompting || !mounted) return;
    _prompting = true;
    setState(() => _message = null);
    final s = context.read<AppSettings>().strings;
    LockAuthResult result = LockAuthResult.retry;
    try {
      result = await _service.authenticate(s['lock.reason']);
    } catch (_) {
      result = LockAuthResult.retry;
    } finally {
      // Whatever happened, the Unlock button must work again.
      _prompting = false;
    }
    if (!mounted) return;
    setState(() {
      switch (result) {
        case LockAuthResult.success:
        case LockAuthResult.noCredentials:
          _locked = false;
        case LockAuthResult.lockedOut:
          _message = s['lock.lockedOut'];
        case LockAuthResult.retry:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>().strings;
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: BrandPalette.of(context).heroStart,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: BrandPalette.of(context).onHero,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          s['lock.title'],
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s['lock.subtitle'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _unlock,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(s['lock.unlock']),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
