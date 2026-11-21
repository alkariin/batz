import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/device_lock.dart';
import '../../l10n/app_localizations.dart';
import 'lock_cubit.dart';

/// The door in front of every screen of the app. While the app is locked,
/// [child] — the navigator and all its routes — is not drawn: not built
/// before the first unlocking, then kept off stage with its state, so
/// that the screen and what was being typed are found again. On a device
/// without lock (desktops), it is [child].
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  late final LockCubit _cubit = context.read<LockCubit>();
  AppLifecycleListener? _lifecycle;

  /// Whether the app was shown once: its screens exist from then on.
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    if (!_cubit.enabled) return;
    _lifecycle = AppLifecycleListener(onHide: _cubit.left, onShow: _returned);
    // The system dialog opens by itself when the app starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _returned() async {
    if (await _cubit.returned() && mounted) _ask();
  }

  void _ask() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    _cubit.unlock(UnlockTexts(title: l.lockDialogTitle, reason: l.lockDialogReason, cancel: l.cancel));
  }

  @override
  Widget build(BuildContext context) {
    if (!_cubit.enabled) return widget.child;
    return BlocBuilder<LockCubit, AppLockState>(
      builder: (context, state) {
        if (!state.locked) _opened = true;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_opened)
              Offstage(
                offstage: state.locked,
                child: ExcludeFocus(excluding: state.locked, child: widget.child),
              ),
            if (state.locked) _LockScreen(state: state, onUnlock: _ask),
          ],
        );
      },
    );
  }
}

/// While the app is locked, the « back » of Android closes nothing: without
/// this, it would close the screen kept behind the lock, and what was being
/// typed there.
///
/// It must stand above the `MaterialApp`: the observers of the binding are
/// asked in the order they were added, and the first that handles « back »
/// stops it; the app's own, added later, would pop a route of the navigator.
class LockedBackGuard extends StatefulWidget {
  const LockedBackGuard({super.key, required this.child});

  final Widget child;

  @override
  State<LockedBackGuard> createState() => _LockedBackGuardState();
}

class _LockedBackGuardState extends State<LockedBackGuard> with WidgetsBindingObserver {
  late final LockCubit _cubit = context.read<LockCubit>();

  @override
  void initState() {
    super.initState();
    if (_cubit.enabled) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Handled, by doing nothing, while the app is locked.
  @override
  Future<bool> didPopRoute() async => _cubit.state.locked;

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.state, required this.onUnlock});

  final AppLockState state;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final message = switch (state.failure) {
      null => null,
      LockFailure.cancelled => l.lockCancelled,
      LockFailure.lockedOut => l.lockLockedOut,
      LockFailure.failed => l.lockFailed(state.error ?? ''),
    };
    return Scaffold(
      key: const Key('lockScreen'),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l.appTitle, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(l.lockTitle, textAlign: TextAlign.center),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    key: const Key('lockMessage'),
                    textAlign: TextAlign.center,
                    style: state.failure == LockFailure.failed ? TextStyle(color: theme.colorScheme.error) : null,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('unlockButton'),
                  onPressed: state.unlocking ? null : onUnlock,
                  icon: const Icon(Icons.lock_open),
                  label: Text(state.failure == LockFailure.failed ? l.lockRetry : l.lockUnlock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
