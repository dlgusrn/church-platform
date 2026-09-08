import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/popup_notice_models.dart';

class PopupNoticeHost extends StatefulWidget {
  const PopupNoticeHost({super.key, required this.child});
  final Widget child;
  @override
  State<PopupNoticeHost> createState() => _PopupNoticeHostState();
}

class _PopupNoticeHostState extends State<PopupNoticeHost> {
  bool _scheduled = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _show();
    });
  }

  void _show() {
    final state = AppScope.of(context);
    final popup = state.pendingPopupNotice;
    if (popup == null || !state.claimPendingPopup(popup)) return;
    showDialog<_PopupAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PopupDialog(popup: popup),
    ).then((action) async {
      if (action == _PopupAction.today) {
        await state.dismissPopupForToday(popup);
      } else {
        state.dismissPopupForSession(popup);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    return widget.child;
  }
}

enum _PopupAction { close, today }

class _PopupDialog extends StatefulWidget {
  const _PopupDialog({required this.popup});
  final PopupNotice popup;

  @override
  State<_PopupDialog> createState() => _PopupDialogState();
}

class _PopupDialogState extends State<_PopupDialog> {
  bool _suppressToday = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    titlePadding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xl,
      AppSpacing.xl,
      0,
    ),
    contentPadding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      0,
    ),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.popup.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
      ],
    ),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.popup.image != null)
              _PopupImage(path: widget.popup.image!.url),
            Text(
              widget.popup.content,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.xl,
      AppSpacing.md,
    ),
    actions: [
      InkWell(
        borderRadius: AppRadii.control,
        onTap: () => setState(() => _suppressToday = !_suppressToday),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: _suppressToday,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (value) =>
                  setState(() => _suppressToday = value ?? false),
            ),
            const Text('오늘 하루 보지 않기'),
          ],
        ),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(110, 50),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        onPressed: () => Navigator.pop(
          context,
          _suppressToday ? _PopupAction.today : _PopupAction.close,
        ),
        child: const Text('닫기'),
      ),
    ],
  );
}

class _PopupImage extends StatefulWidget {
  const _PopupImage({required this.path});
  final String path;
  @override
  State<_PopupImage> createState() => _PopupImageState();
}

class _PopupImageState extends State<_PopupImage> {
  Future<List<int>>? _bytes;
  @override
  Widget build(BuildContext context) {
    _bytes ??= AppScope.of(context).popupImageBytes(widget.path);
    return FutureBuilder<List<int>>(
      future: _bytes,
      builder: (_, s) => s.hasData
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ClipRRect(
                borderRadius: AppRadii.control,
                child: Image.memory(
                  Uint8List.fromList(s.data!),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
