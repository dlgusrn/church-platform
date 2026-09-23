import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/overflow_only_scroll_physics.dart';
import '../data/video_repository.dart';
import '../domain/video_models.dart';

class VideoReviewScreen extends StatefulWidget {
  const VideoReviewScreen({super.key});

  @override
  State<VideoReviewScreen> createState() => _VideoReviewScreenState();
}

class _VideoReviewScreenState extends State<VideoReviewScreen> {
  static const _pageSize = 100;
  static const _maxBatch = 200;
  String status = 'unpublished';
  bool loading = false;
  bool publishing = false;
  String? error;
  String? notice;
  int total = 0;
  int publishedCount = 0;
  int unpublishedCount = 0;
  List<VideoItem> videos = [];
  List<VideoCategory> categories = [];
  List<VideoCollection> collections = [];
  Set<String> selectedIds = {};

  String get churchId => AppScope.of(context).activeMembership!.church.id;
  bool get hasMore => videos.length < total;
  List<VideoItem> get selectable =>
      videos.where((video) => !video.isPublished).toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (videos.isEmpty && !loading) load(reset: true);
  }

  Future<void> load({required bool reset}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = AppScope.of(context).videoRepository!;
      final response = await repo.reviewVideos(
        churchId,
        status: status,
        offset: reset ? 0 : videos.length,
        limit: _pageSize,
      );
      final page = ((response['items'] as List?) ?? []).map(_video).toList();
      final merged = <String, VideoItem>{
        if (!reset)
          for (final video in videos) video.id: video,
        for (final video in page) video.id: video,
      };
      final metadata = await Future.wait([
        repo.listCategories(churchId),
        repo.listCollections(churchId),
      ]);
      if (!mounted) return;
      setState(() {
        videos = merged.values.toList();
        total = _int(response['total']);
        publishedCount = _int(response['published_count']);
        unpublishedCount = _int(response['unpublished_count']);
        categories = metadata[0] as List<VideoCategory>;
        collections = metadata[1] as List<VideoCollection>;
      });
    } on VideoDataException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = '영상 검수 목록을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeStatus(String next) async {
    setState(() {
      status = next;
      videos = [];
    });
    await load(reset: true);
  }

  Future<void> publishSelected() async {
    if (selectedIds.isEmpty || publishing) return;
    if (selectedIds.length > _maxBatch) {
      setState(() => error = '한 번에 최대 200개까지 공개할 수 있습니다.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영상 공개'),
        content: Text(
          '${selectedIds.length}개의 영상을 공개하시겠습니까?\n\n공개하면 영상 열람 권한이 있는 성도에게 영상이 표시됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('공개하기'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final ids = selectedIds.toList()..sort();
    setState(() {
      publishing = true;
      error = null;
      notice = null;
    });
    try {
      final result = await AppScope.of(context).videoRepository!
          .bulkPublish(churchId, ids);
      final items = ((result['items'] as List?) ?? [])
          .whereType<Map>()
          .toList();
      final completed = <String>{
        for (var index = 0; index < ids.length && index < items.length; index++)
          if (items[index]['status'] == 'published' ||
              items[index]['status'] == 'already_published')
            ids[index],
      };
      if (!mounted) return;
      setState(() {
        selectedIds.removeAll(completed);
        notice =
            '영상 공개 완료\n공개됨 ${_int(result['published_count'])}개 · 이미 공개됨 ${_int(result['already_published_count'])}개 · 실패 ${_int(result['failed_count'])}개';
        if (status == 'unpublished')
          videos.removeWhere((video) => completed.contains(video.id));
      });
      await load(reset: true);
    } on VideoDataException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = '영상 공개에 실패했습니다.');
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  Future<void> edit(VideoItem video) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VideoEditSheet(
        video: video,
        categories: categories,
        collections: collections,
      ),
    );
    if (result == null) return;
    try {
      final updated = await AppScope.of(context).videoRepository!
          .updateVideo(churchId, video.id, result);
      if (!mounted) return;
      setState(() {
        videos = [
          for (final item in videos)
            if (item.id == updated.id) updated else item,
        ];
      });
    } on VideoDataException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('영상 검수 및 공개')),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: FilledButton(
        onPressed: selectedIds.isEmpty || publishing ? null : publishSelected,
        child: Text(publishing ? '공개하는 중…' : '선택한 ${selectedIds.length}개 공개하기'),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: () => load(reset: true),
      child: ListView(
        physics: const OverflowOnlyScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('비공개 $unpublishedCount개')),
              Chip(label: Text('공개 $publishedCount개')),
              Chip(label: Text('선택 ${selectedIds.length}개')),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: status,
            items: const [
              DropdownMenuItem(value: 'unpublished', child: Text('비공개')),
              DropdownMenuItem(value: 'published', child: Text('공개')),
              DropdownMenuItem(value: 'all', child: Text('전체')),
            ],
            onChanged: loading
                ? null
                : (value) {
                    if (value != null) changeStatus(value);
                  },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: selectable.isEmpty
                    ? null
                    : () => setState(
                        () => selectedIds.addAll(
                          selectable.map((video) => video.id),
                        ),
                      ),
                child: const Text('현재 목록 전체 선택'),
              ),
              OutlinedButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => setState(() => selectedIds = {}),
                child: const Text('선택 해제'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                notice!,
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          if (loading && videos.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (videos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                status == 'unpublished'
                    ? '검수할 비공개 영상이 없습니다.'
                    : '조건에 맞는 영상이 없습니다.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...videos.map(_row),
          if (hasMore)
            Center(
              child: OutlinedButton(
                onPressed: loading ? null : () => load(reset: false),
                child: const Text('더 보기'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _row(VideoItem video) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: ListTile(
      leading: Checkbox(
        value: selectedIds.contains(video.id),
        onChanged: video.isPublished
            ? null
            : (value) => setState(() {
                if (value == true)
                  selectedIds.add(video.id);
                else
                  selectedIds.remove(video.id);
              }),
      ),
      title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_date(video.recordedAt)} · ${video.sourceType == VideoSourceType.synology ? 'NAS 영상' : 'YouTube'}${_category(video.categoryId)}${_collection(video.collectionId)}',
      ),
      trailing: Chip(label: Text(video.isPublished ? '공개' : '비공개')),
      onTap: () => edit(video),
    ),
  );

  String _category(String? id) => id == null
      ? ' · 카테고리 미지정'
      : ' · ${categories.where((item) => item.id == id).map((item) => item.name).firstOrNull ?? '카테고리'}';
  String _collection(String? id) => id == null
      ? ' · 컬렉션 미지정'
      : ' · ${collections.where((item) => item.id == id).map((item) => item.title).firstOrNull ?? '컬렉션'}';
  static int _int(dynamic value) => value is int ? value : 0;
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static VideoItem _video(dynamic value) {
    final item = (value as Map).cast<String, dynamic>();
    return VideoItem(
      id: '${item['id']}',
      churchId: '${item['church_id']}',
      title: '${item['title']}',
      description: item['description'] as String?,
      sourceType: item['source_type'] == 'synology'
          ? VideoSourceType.synology
          : VideoSourceType.youtube,
      sourceRef: '',
      recordedAt: DateTime.parse(item['recorded_at'] as String).toLocal(),
      durationSeconds: item['duration_seconds'] as int?,
      thumbnailRef: item['thumbnail_ref'] as String?,
      isPublished: item['is_published'] as bool? ?? false,
      categoryId: item['category_id'] == null ? null : '${item['category_id']}',
      collectionId: item['collection_id'] == null
          ? null
          : '${item['collection_id']}',
    );
  }
}

class _VideoEditSheet extends StatefulWidget {
  const _VideoEditSheet({
    required this.video,
    required this.categories,
    required this.collections,
  });
  final VideoItem video;
  final List<VideoCategory> categories;
  final List<VideoCollection> collections;
  @override
  State<_VideoEditSheet> createState() => _VideoEditSheetState();
}

class _VideoEditSheetState extends State<_VideoEditSheet> {
  late final TextEditingController title = TextEditingController(
    text: widget.video.title,
  );
  late final TextEditingController date = TextEditingController(
    text: _VideoReviewScreenState._date(widget.video.recordedAt),
  );
  late String? categoryId = widget.video.categoryId;
  late String? collectionId = widget.video.collectionId;
  late bool published = widget.video.isPublished;
  @override
  void dispose() {
    title.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '영상 정보 수정',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: date,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(labelText: '날짜 (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: '카테고리'),
              items: [
                const DropdownMenuItem(value: null, child: Text('미지정')),
                ...widget.categories.map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                ),
              ],
              onChanged: (value) => setState(() => categoryId = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: collectionId,
              decoration: const InputDecoration(labelText: '컬렉션'),
              items: [
                const DropdownMenuItem(value: null, child: Text('미지정')),
                ...widget.collections.map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.title)),
                ),
              ],
              onChanged: (value) => setState(() => collectionId = value),
            ),
            SwitchListTile(
              value: published,
              onChanged: (value) => setState(() => published = value),
              title: const Text('공개'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = DateTime.tryParse(date.text.trim());
                if (title.text.trim().isEmpty || parsed == null) return;
                Navigator.pop(context, {
                  'title': title.text.trim(),
                  'recorded_at': '${parsed.toUtc().toIso8601String()}',
                  'category_id': categoryId == null
                      ? null
                      : int.tryParse(categoryId!),
                  'collection_id': collectionId == null
                      ? null
                      : int.tryParse(collectionId!),
                  'is_published': published,
                });
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
