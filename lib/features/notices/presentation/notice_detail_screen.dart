import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_theme.dart';
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
                  onPressed: () => _edit(notice),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (state.has(AppPermission.noticeDelete))
                IconButton(
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice.isPinned)
                        const Chip(
                          avatar: Icon(Icons.push_pin_rounded, size: 16),
                          label: Text('고정공지'),
                        ),
                      Text(
                        notice.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notice.detailDate,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const Divider(height: 32),
                      SelectableText(
                        notice.content,
                        style: const TextStyle(fontSize: 16, height: 1.6),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
