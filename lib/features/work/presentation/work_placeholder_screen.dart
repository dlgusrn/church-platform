import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_theme.dart';

class WorkPlaceholderScreen extends StatelessWidget {
  const WorkPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final modules =
        <({String name, IconData icon, Set<AppPermission> permissions})>[
          (
            name: '공지사항',
            icon: Icons.campaign_outlined,
            permissions: {
              AppPermission.noticeView,
              AppPermission.noticeCreate,
              AppPermission.noticeUpdate,
              AppPermission.noticeDelete,
            },
          ),
          (
            name: '일정',
            icon: Icons.event_outlined,
            permissions: {
              AppPermission.scheduleView,
              AppPermission.scheduleManage,
            },
          ),
          (
            name: '지출결의',
            icon: Icons.receipt_long_outlined,
            permissions: {
              AppPermission.expenseView,
              AppPermission.expenseCreate,
              AppPermission.expenseUpdate,
              AppPermission.expenseApprove,
            },
          ),
          (
            name: '전자결재',
            icon: Icons.approval_outlined,
            permissions: {
              AppPermission.approvalView,
              AppPermission.approvalCreate,
              AppPermission.approvalApprove,
            },
          ),
          (
            name: '근태관리',
            icon: Icons.schedule_outlined,
            permissions: {
              AppPermission.attendanceView,
              AppPermission.attendanceManage,
            },
          ),
          (
            name: '문서관리',
            icon: Icons.folder_outlined,
            permissions: {
              AppPermission.documentView,
              AppPermission.documentCreate,
              AppPermission.documentManage,
            },
          ),
        ].where((module) => state.hasAny(module.permissions)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('업무'), backgroundColor: Colors.white),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: modules.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
        ),
        itemBuilder: (context, index) {
          final module = modules[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${module.name} 기능은 다음 단계에서 구현됩니다.')),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(module.icon, color: AppTheme.primary, size: 28),
                    Text(
                      module.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
