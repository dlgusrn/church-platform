import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../domain/notice_models.dart';

class NoticeEditorScreen extends StatefulWidget {
  const NoticeEditorScreen({super.key, this.notice});
  final Notice? notice;
  @override
  State<NoticeEditorScreen> createState() => _NoticeEditorScreenState();
}

class _NoticeEditorScreenState extends State<NoticeEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late bool _pinned;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.notice?.title ?? '');
    _content = TextEditingController(text: widget.notice?.content ?? '');
    _pinned = widget.notice?.isPinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _error = '제목과 본문을 입력해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final savedNotice = await AppScope.of(context).saveNotice(
        NoticeDraft(
          title: _title.text.trim(),
          content: _content.text.trim(),
          isPinned: _pinned,
        ),
        noticeId: widget.notice?.id,
      );
      if (mounted) Navigator.pop(context, savedNotice);
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했습니다. 입력 내용과 권한을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.notice == null ? '공지 작성' : '공지 수정')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _content,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '본문',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('고정공지'),
              value: _pinned,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _pinned = value),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '저장 중...' : '저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
