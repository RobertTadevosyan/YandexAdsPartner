import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:adpocket/core/session.dart';
import 'package:adpocket/core/settings.dart';
import 'package:adpocket/theme.dart';

/// Thin wrapper over local_auth so screens and tests can swap it out.
class AppLockService {
  final LocalAuthentication _auth;
  AppLockService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  /// True when the device has a screen lock (biometrics or PIN/pattern).
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Prompts for fingerprint / face, falling back to the device PIN.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Shows a lock screen over [child] whenever app lock is enabled: on cold
/// start and every time the app returns from the background.
class LockGate extends StatefulWidget {
  final Widget child;
  final AppLockService? service;
  const LockGate({required this.child, this.service, super.key});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late final AppLockService _service = widget.service ?? AppLockService();
  bool _locked = false;
  bool _prompting = false;
  bool _initialised = false;

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
    if (context.read<AppSettings>().appLock &&
        context.read<AppSession>().isSignedIn) {
      _locked = true;
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
    if (!mounted) return;
    final enabled =
        context.read<AppSettings>().appLock &&
        context.read<AppSession>().isSignedIn;
    if (!enabled) return;
    if (state == AppLifecycleState.paused && !_prompting) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_prompting || !mounted) return;
    _prompting = true;
    final reason = context.read<AppSettings>().strings['lock.reason'];
    final ok = await _service.authenticate(reason);
    if (!mounted) return;
    _prompting = false;
    if (ok) setState(() => _locked = false);
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
                            color: Brand.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Brand.navy,
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
