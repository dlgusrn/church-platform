import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.pageVertical,
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('제목', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _title,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: '공지 제목을 입력하세요'),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('본문', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _content,
                  enabled: !_saving,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '공지 내용을 입력하세요',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _PinnedSetting(
                  value: _pinned,
                  enabled: !_saving,
                  onChanged: (value) => setState(() => _pinned = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _EditorError(message: _error!),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PinnedSetting extends StatelessWidget {
  const _PinnedSetting({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surfaceMuted,
    child: SwitchListTile(
      title: const Text('공지 상단에 고정'),
      subtitle: const Text('중요한 공지를 목록 상단에 표시합니다.'),
      value: value,
      onChanged: enabled ? onChanged : null,
    ),
  );
}

class _EditorError extends StatelessWidget {
  const _EditorError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.all(AppRadii.small),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.danger),
      ),
    ),
  );
}
