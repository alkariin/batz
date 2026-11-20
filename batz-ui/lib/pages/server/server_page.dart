import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/server/server_client.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../sync/sync_card.dart';
import 'server_cubit.dart';

/// Settings > Server: pairing, status, devices.
class ServerPage extends StatelessWidget {
  const ServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.serverTitle)),
      body: BlocBuilder<ServerCubit, ServerState>(
        builder: (context, state) {
          if (state.loading) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.busy) const LinearProgressIndicator(),
              if (state.problem case final problem?) _ProblemBanner(problem: problem, paired: state.paired),
              if (state.paired) _PairedView(state: state) else _PairingForm(busy: state.busy),
            ],
          );
        },
      ),
    );
  }
}

String problemText(AppLocalizations l, ServerProblem problem) => switch (problem) {
  ServerProblem.invalidAddress => l.serverErrorAddress,
  ServerProblem.unreachable => l.serverErrorUnreachable,
  ServerProblem.certificateMismatch => l.serverErrorCertificate,
  ServerProblem.codeInvalid => l.serverErrorCodeInvalid,
  ServerProblem.codeExpired => l.serverErrorCodeExpired,
  ServerProblem.codeUsed => l.serverErrorCodeUsed,
  ServerProblem.nameInvalid => l.serverErrorName,
  ServerProblem.deviceRevoked => l.serverErrorRevoked,
  ServerProblem.unknownDevice => l.serverErrorUnknownDevice,
  ServerProblem.other => l.serverErrorOther,
};

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.problem, required this.paired});

  final ServerProblem problem;
  final bool paired;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    // Without the server, the pairing can still be forgotten here.
    final canForget = paired && problem != ServerProblem.other;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(problemText(l, problem), style: TextStyle(color: colors.onErrorContainer)),
            if (canForget)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => context.read<ServerCubit>().forget(), child: Text(l.serverForget)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PairingForm extends StatefulWidget {
  const _PairingForm({required this.busy});

  final bool busy;

  @override
  State<_PairingForm> createState() => _PairingFormState();
}

class _PairingFormState extends State<_PairingForm> {
  final _address = TextEditingController();
  final _code = TextEditingController();
  late final _name = TextEditingController(text: _defaultDeviceName());

  static String _defaultDeviceName() {
    final os = Platform.isAndroid ? 'Android' : (Platform.isWindows ? 'Windows' : 'Linux');
    try {
      return '$os ${Platform.localHostname}'.trim();
    } catch (_) {
      return os;
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.serverPairingIntro),
        const SizedBox(height: 16),
        TextField(
          key: const Key('server-address'),
          controller: _address,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l.serverAddress, hintText: '192.168.1.95:$defaultServerPort'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('server-code'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.serverCode, hintText: 'ABCD-1234'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('server-name'),
          controller: _name,
          decoration: InputDecoration(labelText: l.serverDeviceName),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.busy
              ? null
              : () =>
                    context.read<ServerCubit>().pair(address: _address.text, code: _code.text, deviceName: _name.text),
          child: Text(l.serverPair),
        ),
      ],
    );
  }
}

class _PairedView extends StatelessWidget {
  const _PairedView({required this.state});

  final ServerState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pairing = state.pairing!;
    final status = state.status;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SyncCard(showPairing: false),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.serverPaired, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l.serverAddressValue('${pairing.address.host}:${pairing.address.port}')),
                if (status != null) Text(l.serverVersion(status.version)),
                const SizedBox(height: 8),
                Text(l.serverFingerprint, style: theme.textTheme.labelMedium),
                SelectableText(pairing.fingerprint, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (status != null && !status.appCompatible)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(l.serverIncompatible(status.minAppVersion))),
          ),
        if (status != null) ...[
          const SizedBox(height: 16),
          Text(l.serverDevices, style: theme.textTheme.titleMedium),
          for (final device in status.devices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(device.current ? l.serverThisDevice(device.name) : device.name),
              subtitle: Text(
                device.revoked
                    ? l.serverDeviceRevoked(formatDate(device.revokedAt!.toLocal()))
                    : l.serverDeviceSince(formatDate(device.createdAt.toLocal())),
              ),
              trailing: device.revoked || device.current
                  ? null
                  : TextButton(
                      onPressed: state.busy ? null : () => _confirmRevoke(context, device),
                      child: Text(l.serverRevoke),
                    ),
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: state.busy ? null : () => context.read<ServerCubit>().refresh(),
          child: Text(l.serverRefresh),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('serverReplace'),
          onPressed: state.busy ? null : () => confirmReplace(context),
          child: Text(l.syncReplaceAction),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: state.busy ? null : () => _confirmUnpair(context), child: Text(l.serverUnpair)),
      ],
    );
  }

  Future<void> _confirmRevoke(BuildContext context, ServerDevice device) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ServerCubit>();
    if (await _confirm(context, l.serverRevokeConfirm(device.name))) await cubit.revoke(device.id);
  }

  Future<void> _confirmUnpair(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ServerCubit>();
    if (await _confirm(context, l.serverUnpairConfirm)) await cubit.unpair();
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.confirm)),
        ],
      ),
    );
    return ok ?? false;
  }
}
