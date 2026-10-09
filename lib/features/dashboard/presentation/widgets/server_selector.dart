import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_bloc.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_event.dart';
import 'package:yoopn/features/dashboard/presentation/bloc/vpn_state.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

class ServerSelector extends StatelessWidget {
  const ServerSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VpnBloc>();

    return BlocBuilder<VpnBloc, VpnState>(
      buildWhen: (prev, curr) =>
          prev.server != curr.server ||
          prev.servers != curr.servers ||
          prev.serversStatus != curr.serversStatus,
      builder: (context, state) {
        final selected = _selectedServer(state);

        return Center(
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32.r),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(32.r),
              onTap: () {
                AppLogger.i('UI', 'ServerSelector pill tapped');
                if (bloc.state.status != VpnStatus.disconnected) {
                  AppLogger.w('UI', 'server change blocked — not disconnected');
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Disconnect first to change server'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  return;
                }
                _openServerSheet(context, bloc);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isLoadingServers)
                      SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Text(selected.flag, style: TextStyle(fontSize: 22.sp)),
                    SizedBox(width: 10.w),
                    // Fixed-width label column: the pill must not resize when
                    // switching between a relay name and a placeholder.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 190.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                            ),
                          ),
                          Text(
                            selected.name.isEmpty ? 'Select' : selected.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: selected.isVpnGate
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  VpnServer _selectedServer(VpnState state) {
    for (final s in state.servers) {
      if (s.matchesId(state.server)) return s;
    }
    for (final s in VpnServer.availableServers) {
      if (s.matchesId(state.server)) return s;
    }
    return state.servers.isEmpty
        ? const VpnServer(name: '', flag: '🌐')
        : state.servers.first;
  }

  void _openServerSheet(BuildContext context, VpnBloc bloc) {
    AppLogger.d('UI', 'open server sheet (${bloc.state.servers.length} servers)');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: bloc,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (_, scrollController) =>
                _ServerListSheet(scrollController: scrollController),
          ),
        );
      },
    );
  }
}

class _ServerListSheet extends StatefulWidget {
  const _ServerListSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_ServerListSheet> createState() => _ServerListSheetState();
}

class _ServerListSheetState extends State<_ServerListSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VpnBloc>();

    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 12.w, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: BlocSelector<VpnBloc, VpnState, int>(
                    selector: (s) => s.servers.length,
                    builder: (_, count) => Text(
                      'Select server ($count)',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh VPNGate list',
                  onPressed: () {
                    AppLogger.i('UI', 'server list manual refresh');
                    bloc.add(
                      const VpnServersRequested(forceRefresh: true),
                    );
                  },
                  icon: BlocSelector<VpnBloc, VpnState, bool>(
                    selector: (s) => s.isLoadingServers,
                    builder: (_, loading) => loading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country, host or IP',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: BlocBuilder<VpnBloc, VpnState>(
              builder: (_, state) {
                if (state.isLoadingServers && state.servers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = _filtered(state.servers);
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No servers match "$_query"',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: entries.length + (state.serversError != null &&
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
                        title: const Text('Could not refresh VPNGate list'),
                        subtitle: Text(
                          state.serversError ?? 'Showing cached servers.',
                        ),
                        trailing: TextButton(
                          onPressed: () => bloc.add(
                            const VpnServersRequested(forceRefresh: true),
                          ),
                          child: const Text('Retry'),
                        ),
                      );
                    }
                    final e = entries[i];
                    final selected = e.matchesId(state.server);
                    return ListTile(
                      leading: Text(
                        e.flag,
                        style: TextStyle(fontSize: 24.sp),
                      ),
                      title: Text(
                        e.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        e.isVpnGate
                            ? '${e.hostName} • ${e.ip} • ${e.pingText} • ${e.speedText} • ${e.sessions} sessions'
                            : 'Built-in server',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () {
                        AppLogger.i('UI', 'server picked ${e.id} (${e.name} ${e.ip})');
                        Navigator.of(context).pop();
                        bloc.add(VpnServerSelected(e.id));
                      },
                    );
                  },
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
    return servers.where((s) {
      return s.name.toLowerCase().contains(_query) ||
          s.hostName.toLowerCase().contains(_query) ||
          s.ip.contains(_query) ||
          s.countryShort.toLowerCase().contains(_query) ||
          s.countryLong.toLowerCase().contains(_query);
    }).toList();
  }
}
