import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yoopn/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/ads/ad_counter_store.dart';
import 'package:yoopn/core/ads/ad_gate.dart';
import 'package:yoopn/core/ads/server_change_gate.dart';
import 'package:yoopn/features/dashboard/domain/utils/server_ranking.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;

  /// Serializes taps while a selection (possibly through the ad gate)
  /// is in flight: without this, rapid taps on A then B interleave counter
  /// reads and the second selection bypasses the gate.
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VpnBloc>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        title: BlocSelector<VpnBloc, VpnState, int>(
          selector: (s) => s.servers.length,
          builder: (_, count) => Text(
            'Servers ($count)',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        actions: [
          BlocSelector<VpnBloc, VpnState, bool>(
            selector: (s) => s.isLoadingServers,
            builder: (_, loading) => IconButton(
              tooltip: 'Refresh server list',
              onPressed: loading
                  ? null
                  : () => bloc.add(const VpnServersRequested(forceRefresh: true)),
              icon: loading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 8.h),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country, host or IP',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              onChanged: (v) {
                // Debounced: the row-by-row text scan runs once the user
                // pauses, not on every keystroke.
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 250), () {
                  if (!mounted) return;
                  setState(() => _query = v.trim().toLowerCase());
                });
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<VpnBloc, VpnState>(
              // Tunnel detail strings stream in during a connect (several
              // per second); without buildWhen every one re-ran `_filtered`
              // and rebuilt the whole list.
              buildWhen: (prev, curr) =>
                  prev.servers != curr.servers ||
                  prev.server != curr.server ||
                  prev.isLoadingServers != curr.isLoadingServers ||
                  prev.serversStatus != curr.serversStatus ||
                  prev.serversError != curr.serversError,
              builder: (_, state) {
                if (state.isLoadingServers && state.servers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = _filtered(state.servers);
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No servers available.'
                          : 'No servers match "$_query"',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => bloc.add(
                    const VpnServersRequested(forceRefresh: true),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 24.h),
                    itemCount:
                        entries.length +
                        (state.serversError != null &&
                                state.serversStatus == VpnServersStatus.failure
                            ? 1
                            : 0),
                    itemBuilder: (_, i) {
                      if (i == entries.length) {
                        return ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                          ),
                          title: const Text('Could not refresh server list'),
                          subtitle: Text(
                            state.serversError ?? 'Showing saved servers.',
                          ),
                          trailing: TextButton(
                            onPressed: () => bloc.add(
                              const VpnServersRequested(forceRefresh: true),
                            ),
                            child: const Text('Retry'),
                          ),
                        );
                      }
                      final server = entries[i];
                      final selected = server.matchesId(state.server);
                      return Card(
                        color: AppColors.surface,
                        margin: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: ListTile(
                          leading: Text(
                            server.flag,
                            style: TextStyle(fontSize: 24.sp),
                          ),
                          title: Text(
                            server.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            server.isVpnGate
                                ? '${server.hostName} • ${server.ip}\n'
                                      '${server.pingText} • ${server.speedText} • '
                                      '${server.sessions} sessions'
                                : 'Built-in server',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          isThreeLine: server.isVpnGate,
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () => _select(context, bloc, server),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<VpnServer> _filtered(List<VpnServer> servers) {
    if (_query.isEmpty) return servers;
    return servers.where((s) => serverMatchesQuery(s, _query)).toList();
  }

  Future<void> _select(BuildContext context, VpnBloc bloc, VpnServer server) async {
    if (_busy) return;
    if (bloc.state.status != VpnStatus.disconnected) {
      showAppSnackBar(context, 'Disconnect first to change server');
      return;
    }
    if (server.matchesId(bloc.state.server)) {
      context.pop();
      return;
    }
    _busy = true;
    try {
      final store = context.read<AdCounterStore>();
      if (await ServerChangeGate.requiresAd(store)) {
        if (!context.mounted) return;
        await startAdGate();
        if (!context.mounted || bloc.isClosed) return;
        // Re-validate: the tunnel may have connected while the ad was on
        // screen, in which case selection is (correctly) a no-op in the
        // bloc — but don't pop the page out from under a connecting tunnel.
        if (bloc.state.status != VpnStatus.disconnected) return;
      }
      if (bloc.isClosed) return;
      bloc.add(VpnServerSelected(server.id));
      if (context.mounted) context.pop();
    } finally {
      _busy = false;
    }
  }
}
