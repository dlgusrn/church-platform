import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/popup_notice_repository.dart';
import '../domain/popup_notice_models.dart';

class PopupNoticeAdminScreen extends StatefulWidget {
  const PopupNoticeAdminScreen({super.key});
  @override
  State<PopupNoticeAdminScreen> createState() => _PopupNoticeAdminScreenState();
}

class _PopupNoticeAdminScreenState extends State<PopupNoticeAdminScreen> {
  late Future<List<PopupNotice>> _items;
  final _toggling = <String>{};
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _items = AppScope.of(context).loadPopupNotices();
    }
  }

  void _reload() {
    final next = AppScope.of(context).loadPopupNotices();
    if (!mounted) return;
    setState(() {
      _items = next;
    });
  }

  Future<void> _open([PopupNotice? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PopupNoticeEditorScreen(item: item)),
    );
    if (saved == true) _reload();
  }

  Future<void> _setActive(PopupNotice item, bool value) async {
    if (_toggling.contains(item.id)) return;
    setState(() => _toggling.add(item.id));
    try {
      await AppScope.of(context).setPopupNoticeActive(item.id, value);
      _reload();
    } on PopupNoticeDataException catch (error) {
      _message(_friendlyError(error));
    } catch (_) {
      _message('팝업공지 상태를 변경하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _toggling.remove(item.id));
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('팝업공지 관리'),
      actions: [
        IconButton(
          tooltip: '팝업공지 등록',
          onPressed: _open,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<List<PopupNotice>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('팝업공지를 불러오지 못했습니다.'),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: _reload, child: const Text('다시 시도')),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const <PopupNotice>[];
        if (items.isEmpty) return const Center(child: Text('등록된 팝업공지가 없습니다.'));
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: InkWell(
                borderRadius: AppRadii.card,
                onTap: () => _open(item),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.image != null) ...[
                        _RemoteImage(
                          path: item.image!.url,
                          width: 64,
                          height: 64,
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _period(item.startsAt, item.endsAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                _Status(active: item.isActive),
                                const Spacer(),
                                Semantics(
                                  label: '팝업공지 활성화',
                                  child: Switch(
                                    value: item.isActive,
                                    onChanged: _toggling.contains(item.id)
                                        ? null
                                        : (v) => _setActive(item, v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class PopupNoticeEditorScreen extends StatefulWidget {
  const PopupNoticeEditorScreen({super.key, this.item});
  final PopupNotice? item;
  @override
  State<PopupNoticeEditorScreen> createState() =>
      _PopupNoticeEditorScreenState();
}

class _PopupNoticeEditorScreenState extends State<PopupNoticeEditorScreen> {
  static const _maxImageBytes = 5 * 1024 * 1024;
  late final TextEditingController _title;
  late final TextEditingController _content;
  late DateTime _start, _end;
  late bool _active;
  Uint8List? _image;
  String? _imageName;
  bool _removedServerImage = false,
      _saving = false,
      _picking = false,
      _removing = false,
      _deleting = false;
  String? _error;
  PopupNotice? get _item => widget.item;
  bool get _hasServerImage => _item?.image != null && !_removedServerImage;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _item?.title ?? '');
    _content = TextEditingController(text: _item?.content ?? '');
    _start = _item?.startsAt.toLocal() ?? DateTime.now();
    _end =
        _item?.endsAt.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    _active = _item?.isActive ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _pick() async {
    if (_picking || _saving) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        _setError('이미지는 5 MiB 이하여야 합니다.');
        return;
      }
      if (mounted)
        setState(() {
          _image = bytes;
          _imageName = file.name;
        });
    } catch (_) {
      _setError('이미지를 선택하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removeImage() async {
    final item = _item;
    if (item == null || !_hasServerImage || _removing || _saving) return;
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      await AppScope.of(context).removePopupImage(item.id);
      if (mounted) setState(() => _removedServerImage = true);
    } on PopupNoticeDataException catch (error) {
      _setError(_friendlyError(error));
    } catch (_) {
      _setError('이미지를 제거하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _date(bool start) async {
    final initial = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start)
        _start = value;
      else
        _end = value;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      _setError('제목과 내용을 입력해주세요.');
      return;
    }
    if (!_start.isBefore(_end)) {
      _setError('종료일시는 시작일시보다 늦어야 합니다.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final state = AppScope.of(context);
      var result = await state.savePopupNotice(
        PopupNoticeDraft(
          title: _title.text.trim(),
          content: _content.text.trim(),
          startsAt: _start,
          endsAt: _end,
          isActive: _active,
        ),
        id: _item?.id,
      );
      if (_image != null && _imageName != null)
        result = await state.uploadPopupImage(result.id, _image!, _imageName!);
      if (mounted) Navigator.of(context).pop(true);
    } on PopupNoticeDataException catch (error) {
      _setError(_friendlyError(error));
    } catch (_) {
      _setError('팝업공지를 저장하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final item = _item;
    if (item == null || _deleting || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팝업공지를 삭제할까요?'),
        content: const Text('삭제한 팝업공지는 복구할 수 없습니다.'),
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
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await AppScope.of(context).deletePopupNotice(item.id);
      if (mounted) Navigator.of(context).pop(true);
    } on PopupNoticeDataException catch (error) {
      _setError(_friendlyError(error));
    } catch (_) {
      _setError('팝업공지를 삭제하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_item == null ? '팝업공지 등록' : '팝업공지 수정'),
        actions: [
          if (_item != null)
            IconButton(
              tooltip: '팝업공지 삭제',
              onPressed: busy ? null : _delete,
              color: AppColors.danger,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
          ),
          children: [
            _Section(
              title: '기본 정보',
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    enabled: !busy,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '제목'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _content,
                    enabled: !busy,
                    minLines: 5,
                    maxLines: null,
                    decoration: const InputDecoration(labelText: '내용'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _Section(title: '이미지', child: _imageSection(busy)),
            const SizedBox(height: AppSpacing.sectionGap),
            _Section(
              title: '노출 기간',
              child: Column(
                children: [
                  _DateRow(
                    label: '시작일시',
                    value: _start,
                    enabled: !busy,
                    onTap: () => _date(true),
                  ),
                  const Divider(),
                  _DateRow(
                    label: '종료일시',
                    value: _end,
                    enabled: !busy,
                    onTap: () => _date(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _Section(
              title: '노출 설정',
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('팝업공지 활성화'),
                subtitle: const Text('설정한 노출 기간 동안 사용자에게 표시됩니다.'),
                value: _active,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        _active = value;
                        _error = null;
                      }),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : _save,
                child: Text(_saving ? '저장 중...' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSection(bool busy) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_image != null)
        _LocalImage(bytes: _image!)
      else if (_hasServerImage)
        _RemoteImage(path: _item!.image!.url, height: 180),
      if (_image != null || _hasServerImage)
        const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          OutlinedButton.icon(
            onPressed: busy || _picking ? null : _pick,
            icon: const Icon(Icons.photo_outlined),
            label: Text(
              _image != null || _hasServerImage ? '이미지 교체' : '이미지 선택',
            ),
          ),
          if (_hasServerImage)
            TextButton.icon(
              onPressed: busy || _removing ? null : _removeImage,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline),
              label: const Text('이미지 삭제'),
            ),
        ],
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      child,
    ],
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(_dateTime(value)),
    trailing: const Icon(Icons.calendar_today_outlined),
    enabled: enabled,
    onTap: enabled ? onTap : null,
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: active ? AppColors.successSoft : AppColors.surfaceMuted,
      borderRadius: AppRadii.control,
    ),
    child: Text(
      active ? '활성' : '비활성',
      style: TextStyle(
        color: active ? AppColors.success : AppColors.textSecondary,
      ),
    ),
  );
}

class _LocalImage extends StatelessWidget {
  const _LocalImage({required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadii.control,
    child: SizedBox(
      width: double.infinity,
      height: 180,
      child: Image.memory(bytes, fit: BoxFit.cover),
    ),
  );
}

class _RemoteImage extends StatefulWidget {
  const _RemoteImage({required this.path, this.width, this.height});
  final String path;
  final double? width, height;
  @override
  State<_RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<_RemoteImage> {
  Future<List<int>>? _bytes;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bytes ??= AppScope.of(context).popupImageBytes(widget.path);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadii.control,
    child: SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 180,
      child: FutureBuilder<List<int>>(
        future: _bytes,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          final bytes = snapshot.data;
          return bytes == null
              ? const SizedBox.shrink()
              : Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
        },
      ),
    ),
  );
}

String _friendlyError(PopupNoticeDataException error) =>
    error.code == 'popup_notice_period_overlap'
    ? '같은 시간에 노출되는 다른 팝업공지가 있습니다.\n노출 기간을 확인해주세요.'
    : '요청을 처리하지 못했습니다. 다시 시도해주세요.';
String _period(DateTime start, DateTime end) =>
    '${_dateTime(start.toLocal())} ~ ${_dateTime(end.toLocal())}';
String _dateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}
