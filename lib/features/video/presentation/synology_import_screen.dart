import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/overflow_only_scroll_physics.dart';
import '../data/video_repository.dart';

class SynologyImportScreen extends StatefulWidget {
  const SynologyImportScreen({super.key});

  @override
  State<SynologyImportScreen> createState() => _SynologyImportScreenState();
}

class _SynologyImportScreenState extends State<SynologyImportScreen> {
  static const _pageSize = 100;
  static const _maxBatchSize = 200;

  bool loading = false;
  bool importing = false;
  bool scanExpired = false;
  String? error;
  String? notice;
  String? token;
  String? folder;
  Map<String, dynamic>? connection;
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> candidates = [];
  List<String> folders = [];
  Set<String> selectedSourceRefs = {};
  String status = 'all';

  String get churchId => AppScope.of(context).activeMembership!.church.id;
  int get filteredTotal => _number(summary?['filtered_total']);
  bool get hasMore => candidates.length < filteredTotal;
  List<Map<String, dynamic>> get _loadedReady =>
      candidates.where(_isReady).toList(growable: false);

  Future<void> test() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      connection = await AppScope.of(context).videoRepository!
          .testSynology(churchId);
    } catch (_) {
      error = '연결을 확인할 수 없습니다. 다시 시도해주세요.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> scan() {
    setState(() {
      selectedSourceRefs = {};
      notice = null;
    });
    return _loadPreview(reset: true, newSnapshot: true);
  }

  Future<void> _loadPreview({
    required bool reset,
    bool newSnapshot = false,
  }) async {
    setState(() {
      loading = true;
      error = null;
      if (newSnapshot) scanExpired = false;
    });
    try {
      final result = await AppScope.of(context).videoRepository!
          .previewSynology(
            churchId,
            snapshotToken: newSnapshot ? null : token,
            offset: reset ? 0 : candidates.length,
            limit: _pageSize,
            status: status,
            folder: folder,
          );
      final page = ((result['candidates'] as List?) ?? [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(growable: false);
      final merged = <String, Map<String, dynamic>>{
        if (!reset)
          for (final item in candidates) item['source_ref'] as String: item,
        for (final item in page) item['source_ref'] as String: item,
      };
      if (!mounted) return;
      setState(() {
        token = result['snapshot_token'] as String?;
        summary = (result['summary'] as Map?)?.cast<String, dynamic>();
        folders = ((result['folder_facets'] as List?) ?? [])
            .whereType<String>()
            .toList();
        candidates = merged.values.toList();
        scanExpired = false;
      });
    } on SynologySnapshotExpiredException {
      if (mounted) {
        setState(() {
          scanExpired = true;
          token = null;
          candidates = [];
          summary = null;
          selectedSourceRefs = {};
        });
      }
    } on SynologyPermissionException {
      if (mounted) setState(() => error = '영상 관리 권한이 없습니다.');
    } catch (_) {
      if (mounted) setState(() => error = '영상 검색에 실패했습니다. 연결 상태를 확인해주세요.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changeFilter({
    String? nextStatus,
    String? nextFolder,
    bool clearFolder = false,
  }) async {
    setState(() {
      status = nextStatus ?? status;
      folder = clearFolder ? null : nextFolder ?? folder;
      candidates = [];
    });
    await _loadPreview(reset: true);
  }

  Future<void> _confirmImport() async {
    if (selectedSourceRefs.isEmpty || importing) return;
    if (selectedSourceRefs.length > _maxBatchSize) {
      setState(() => error = '한 번에 최대 200개까지 가져올 수 있습니다.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영상 가져오기'),
        content: Text(
          '${selectedSourceRefs.length}개의 영상을 가져오시겠습니까?\n\n'
          '가져온 영상은 바로 공개되지 않으며 관리자가 확인 후 공개할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (confirmed == true) await importSelected();
  }

  Future<void> importSelected() async {
    if (token == null || selectedSourceRefs.isEmpty || importing) return;
    final refs = selectedSourceRefs.toList()..sort();
    if (refs.length > _maxBatchSize) {
      setState(() => error = '한 번에 최대 200개까지 가져올 수 있습니다.');
      return;
    }
    setState(() {
      importing = true;
      error = null;
      notice = null;
    });
    try {
      final result = await AppScope.of(context).videoRepository!
          .importSynology(churchId, token!, refs);
      if (!mounted) return;
      final imported = _number(
        result['imported_count'],
        fallback: _number(result['created']),
      );
      final alreadyImported = _number(
        result['already_imported_count'],
        fallback: _number(result['skipped']),
      );
      final failed = _number(
        result['failed_count'],
        fallback: _number(result['failed']),
      );
      final items = ((result['items'] as List?) ?? [])
          .whereType<Map>()
          .toList();
      final candidateOutOfSnapshot = items.any(
        (item) => item['error_code'] == 'candidate_not_in_snapshot',
      );
      final completed = <String>{};
      for (
        var index = 0;
        index < items.length && index < refs.length;
        index++
      ) {
        final item = items[index];
        if (item['status'] == 'imported' ||
            item['status'] == 'already_imported') {
          completed.add(refs[index]);
        }
      }
      setState(() {
        selectedSourceRefs.removeAll(completed);
        notice =
            '영상 가져오기 완료\n가져옴 ${imported}개 · 이미 등록됨 ${alreadyImported}개 · 실패 ${failed}개';
        if (failed > 0) notice = '$notice\n일부 영상을 가져오지 못했습니다.';
        if (candidateOutOfSnapshot) {
          notice = '$notice\n선택한 영상 정보를 다시 불러와 주세요.';
        }
      });
      // Keep the same snapshot and filters; only refresh this visible page.
      await _loadPreview(reset: true);
    } on SynologySnapshotExpiredException {
      if (mounted) {
        setState(() {
          scanExpired = true;
          token = null;
          candidates = [];
          summary = null;
          selectedSourceRefs = {};
        });
      }
    } on SynologyCandidateInvalidException {
      if (mounted) setState(() => error = '선택한 영상 정보를 다시 불러와 주세요.');
    } on SynologyPermissionException {
      if (mounted) setState(() => error = '영상 관리 권한이 없습니다.');
    } catch (_) {
      if (mounted) setState(() => error = '가져오기에 실패했습니다. 다시 스캔해주세요.');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NAS 영상 가져오기')),
    bottomNavigationBar: summary == null
        ? null
        : SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton(
              onPressed: importing || selectedSourceRefs.isEmpty
                  ? null
                  : _confirmImport,
              child: Text(
                importing
                    ? '가져오는 중…'
                    : '선택한 ${selectedSourceRefs.length}개 가져오기',
              ),
            ),
          ),
    body: ListView(
      physics: const OverflowOnlyScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        const Text(
          'Synology NAS',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              connection == null
                  ? '연결 상태를 확인해주세요.'
                  : connection!['root_accessible'] == true
                  ? '연결됨 · 영상 폴더 접근 가능'
                  : '연결 또는 영상 폴더를 확인해주세요.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: loading ? null : test,
              child: const Text('연결 확인'),
            ),
            FilledButton(
              onPressed: loading ? null : scan,
              child: Text(loading ? '처리 중…' : '영상 검색'),
            ),
          ],
        ),
        if (scanExpired) ...[
          const SizedBox(height: 12),
          const Text(
            'NAS 목록을 다시 불러와 주세요.',
            style: TextStyle(color: AppColors.warning),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: loading ? null : scan,
            child: const Text('다시 검색'),
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: 12),
          Text(notice!, style: const TextStyle(color: AppColors.primary)),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        if (summary != null) ..._libraryContent(),
      ],
    ),
  );

  List<Widget> _libraryContent() => [
    const SizedBox(height: 24),
    const Text(
      'NAS 영상',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _count('총', summary!['total']),
        _count('가져오기 가능', summary!['ready']),
        _count('검토 필요', summary!['needs_review']),
        _count('이미 등록됨', summary!['already_imported']),
        _count('선택', selectedSourceRefs.length),
      ],
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<String>(
          value: status,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('전체')),
            DropdownMenuItem(value: 'ready', child: Text('가져오기 가능')),
            DropdownMenuItem(value: 'needs_review', child: Text('검토 필요')),
            DropdownMenuItem(value: 'already_imported', child: Text('이미 등록됨')),
          ],
          onChanged: loading
              ? null
              : (value) {
                  if (value != null) _changeFilter(nextStatus: value);
                },
        ),
        DropdownButton<String?>(
          value: folder,
          hint: const Text('전체 폴더'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('전체 폴더')),
            for (final item in folders)
              DropdownMenuItem<String?>(
                value: item,
                child: Text(
                  _folderLabel(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: loading
              ? null
              : (value) => _changeFilter(
                  nextFolder: value,
                  clearFolder: value == null,
                ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: _loadedReady.isEmpty
              ? null
              : () => setState(
                  () => selectedSourceRefs.addAll(
                    _loadedReady.map((item) => item['source_ref'] as String),
                  ),
                ),
          child: const Text('현재 목록 전체 선택'),
        ),
        OutlinedButton(
          onPressed: selectedSourceRefs.isEmpty
              ? null
              : () => setState(() => selectedSourceRefs = {}),
          child: const Text('선택 해제'),
        ),
      ],
    ),
    const SizedBox(height: 12),
    if (candidates.isEmpty) _emptyState() else ...candidates.map(_row),
    if (hasMore)
      Center(
        child: OutlinedButton(
          onPressed: loading ? null : () => _loadPreview(reset: false),
          child: const Text('더 보기'),
        ),
      ),
  ];

  Widget _emptyState() {
    final message = switch (status) {
      'ready' => '가져올 수 있는 새 영상이 없습니다.',
      'needs_review' => '확인이 필요한 영상이 없습니다.',
      'already_imported' => '아직 등록된 영상이 없습니다.',
      _ when folder != null => '조건에 맞는 영상이 없습니다.',
      _ => '표시할 영상이 없습니다.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(message, textAlign: TextAlign.center),
    );
  }

  Widget _count(String label, dynamic value) =>
      Chip(label: Text('$label ${_number(value)}개'));

  Widget _row(Map<String, dynamic> candidate) {
    final ref = candidate['source_ref'] as String;
    final selectable = _isReady(candidate);
    return _SynologyCandidateRow(
      candidate: candidate,
      leading: Checkbox(
        value: selectedSourceRefs.contains(ref),
        onChanged: !selectable
            ? null
            : (checked) => setState(() {
                if (checked == true)
                  selectedSourceRefs.add(ref);
                else
                  selectedSourceRefs.remove(ref);
              }),
      ),
    );
  }

  static int _number(dynamic value, {int fallback = 0}) =>
      value is int ? value : fallback;
  static bool _isReady(Map<String, dynamic> candidate) =>
      candidate['already_imported'] != true &&
      candidate['duplicate'] != true &&
      candidate['needs_review'] != true &&
      ((candidate['warnings'] as List?)?.isEmpty ?? true);
  static String _folderLabel(String value) => value.split('/').last;
}

class _SynologyCandidateRow extends StatelessWidget {
  const _SynologyCandidateRow({required this.candidate, this.leading});
  final Map<String, dynamic> candidate;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final alreadyImported =
        candidate['already_imported'] == true || candidate['duplicate'] == true;
    final reasons =
        ((candidate['review_reasons'] ?? candidate['warnings']) as List? ??
                const [])
            .whereType<String>()
            .map(_reasonLabel)
            .toList();
    final needsReview = candidate['needs_review'] == true || reasons.isNotEmpty;
    final label = alreadyImported
        ? '등록됨'
        : needsReview
        ? '검토 필요'
        : '가져오기 가능';
    final recordedAt = candidate['inferred_recorded_at'];
    final date = recordedAt is String && recordedAt.isNotEmpty
        ? recordedAt.split('T').first
        : '날짜 확인 필요';
    final extension = '${candidate['extension'] ?? ''}'.toUpperCase();
    final size = _fileSize(candidate['file_size']);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${candidate['inferred_title']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Chip(label: Text(label)),
                    ],
                  ),
                  Text(
                    [
                      date,
                      if (extension.isNotEmpty) extension,
                      size,
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                  if (needsReview)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        reasons.isEmpty ? '확인 필요' : reasons.join(' · '),
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _reasonLabel(String reason) => switch (reason) {
    'missing_recorded_at' => '날짜 확인 필요',
    'possible_duplicate' => '중복 가능성 있음',
    'ambiguous_title' => '제목 확인 필요',
    'unknown_structure' => '폴더 구조 확인 필요',
    _ => '확인 필요',
  };

  static String _fileSize(dynamic bytes) {
    if (bytes is! int || bytes < 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
