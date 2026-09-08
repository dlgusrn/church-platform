import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/notice_models.dart';
import 'notice_editor_screen.dart';

class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({super.key, required this.noticeId});
  final String noticeId;
  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late Future<Notice> _notice;
  bool _loaded = false;
  bool _deleting = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _notice = AppScope.of(context).loadNotice(widget.noticeId);
  }

  Future<void> _edit(Notice notice) async {
    final updatedNotice = await Navigator.of(context).push<Notice>(
      MaterialPageRoute(builder: (_) => NoticeEditorScreen(notice: notice)),
    );
    if (updatedNotice == null || !mounted) return;
    setState(() {
      _notice = Future.value(updatedNotice);
    });
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공지사항을 삭제하시겠습니까?'),
        content: const Text('삭제한 공지사항은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await AppScope.of(context).deleteNotice(widget.noticeId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('공지사항을 삭제하지 못했습니다.')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return FutureBuilder<Notice>(
      future: _notice,
      builder: (context, snapshot) {
        final notice = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('공지사항'),
            actions: [
              if (notice != null && state.has(AppPermission.noticeUpdate))
                IconButton(
                  tooltip: '공지 수정',
                  onPressed: () => _edit(notice),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (notice != null && state.has(AppPermission.noticeDelete))
                IconButton(
                  tooltip: '공지 삭제',
                  onPressed: _deleting ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: snapshot.hasError
              ? const Center(child: Text('공지사항을 찾을 수 없습니다.'))
              : notice == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.pageVertical,
                    AppSpacing.pageHorizontal,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice.isPinned) const _PinnedLabel(),
                      Text(
                        notice.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        notice.detailDate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Divider(),
                      ),
                      SelectableText(
                        notice.content,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(height: 1.7),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _PinnedLabel extends StatelessWidget {
  const _PinnedLabel();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Semantics(
      label: '고정 공지',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.all(AppRadii.small),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin_outlined, size: 16, color: AppColors.primary),
            SizedBox(width: AppSpacing.xs),
            Text(
              '고정',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
