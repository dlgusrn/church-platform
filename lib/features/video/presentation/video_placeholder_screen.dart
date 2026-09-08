import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/video_repository.dart';
import '../domain/video_models.dart';

class VideoPlaceholderScreen extends StatefulWidget {
  const VideoPlaceholderScreen({super.key});
  @override
  State<VideoPlaceholderScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoPlaceholderScreen> {
  VideoFilters filters = const VideoFilters();
  List<VideoItem>? videos;
  List<VideoArchive> archive = const [];
  List<VideoCategory> categories = const [];
  List<VideoCollection> collections = const [];
  Object? error;
  int generation = 0;
  String? churchId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AppScope.of(context).activeMembership?.church.id;
    if (id != churchId) {
      churchId = id;
      load();
    }
  }

  Future<void> load() async {
    final state = AppScope.of(context);
    final id = state.activeMembership?.church.id;
    final repo = state.videoRepository;
    final g = ++generation;
    if (id == null || repo == null) {
      if (mounted) setState(() => videos = const []);
      return;
    }
    setState(() => error = null);
    try {
      final r = await Future.wait<Object>([
        repo.listVideos(id, filters: filters),
        repo.getArchive(id),
        repo.listCategories(id),
        repo.listCollections(id),
      ]);
      if (!mounted ||
          g != generation ||
          AppScope.of(context).activeMembership?.church.id != id)
        return;
      setState(() {
        videos = r[0] as List<VideoItem>;
        archive = r[1] as List<VideoArchive>;
        categories = (r[2] as List<VideoCategory>)
            .where((x) => x.isActive)
            .toList();
        collections = r[3] as List<VideoCollection>;
      });
    } catch (e) {
      if (mounted && g == generation)
        setState(() {
          error = e;
          videos = null;
        });
    }
  }

  Future<void> setFilter(VideoFilters value) async {
    setState(() => filters = value);
    await load();
  }

  String? category(String? id) => id == null
      ? null
      : categories.where((x) => x.id == id).map((x) => x.name).firstOrNull;
  String? collection(String? id) => id == null
      ? null
      : collections.where((x) => x.id == id).map((x) => x.title).firstOrNull;
  @override
  Widget build(BuildContext context) {
    final list = videos;
    return Scaffold(
      appBar: AppBar(
        title: const Align(alignment: Alignment.centerLeft, child: Text('영상')),
        titleSpacing: AppSpacing.pageHorizontal,
      ),
      body: list == null
          ? (error == null
                ? const Center(child: CircularProgressIndicator())
                : _Error(onRetry: load))
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: '최신',
                          selected:
                              filters.year == null &&
                              filters.categoryId == null &&
                              filters.collectionId == null,
                          onTap: () => setFilter(const VideoFilters()),
                        ),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              label: Text(
                                filters.year == null
                                    ? '기간'
                                    : '${filters.year}년${filters.month == null ? '' : ' ${filters.month}월'}',
                              ),
                              onPressed: archive.isEmpty ? null : pickArchive,
                            ),
                            ActionChip(
                              label: Text(
                                category(filters.categoryId) ?? '카테고리',
                              ),
                              onPressed: categories.isEmpty
                                  ? null
                                  : pickCategory,
                            ),
                            if (filters.year != null ||
                                filters.categoryId != null)
                              TextButton(
                                onPressed: () =>
                                    setFilter(const VideoFilters()),
                                child: const Text('전체'),
                              ),
                          ],
                        ),
                        if (collections.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: collection(filters.collectionId) ?? '컬렉션',
                            selected: filters.collectionId != null,
                            onTap: pickCollection,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (collections.isNotEmpty && filters.collectionId == null)
                    CollectionStrip(
                      items: collections,
                      onTap: (c) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CollectionDetail(
                            collection: c,
                            repo: AppScope.of(context).videoRepository!,
                            category: category(c.categoryId),
                          ),
                        ),
                      ),
                    ),
                  if (collections.isNotEmpty) const SizedBox(height: 24),
                  Text(
                    filters.year == null ? '최신 영상' : '${filters.year}년 영상',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    _Empty(
                      filtered:
                          filters.year != null ||
                          filters.categoryId != null ||
                          filters.collectionId != null,
                    ),
                  ...list.map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VideoCard(
                        video: v,
                        category: category(v.categoryId),
                        collection: collection(v.collectionId),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoDetail(
                              video: v,
                              category: category(v.categoryId),
                              collection: collection(v.collectionId),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> pickArchive() async {
    final selected = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (_) => ArchiveSheet(items: archive),
    );
    if (selected != null)
      setFilter(
        VideoFilters(
          year: selected.year,
          month: selected.month,
          categoryId: filters.categoryId,
        ),
      );
  }

  Future<void> pickCategory() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: [
          ListTile(
            title: const Text('전체 카테고리'),
            onTap: () => Navigator.pop(context, ''),
          ),
          ...categories.map(
            (c) => ListTile(
              title: Text(c.name),
              onTap: () => Navigator.pop(context, c.id),
            ),
          ),
        ],
      ),
    );
    if (picked != null)
      setFilter(
        VideoFilters(
          year: filters.year,
          month: filters.month,
          categoryId: picked.isEmpty ? null : picked,
        ),
      );
  }

  Future<void> pickCollection() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: [
          ListTile(
            title: const Text('전체 컬렉션'),
            onTap: () => Navigator.pop(context, ''),
          ),
          ...collections.map(
            (c) => ListTile(
              title: Text(c.title),
              onTap: () => Navigator.pop(context, c.id),
            ),
          ),
        ],
      ),
    );
    if (picked != null)
      setFilter(
        VideoFilters(
          year: filters.year,
          month: filters.month,
          categoryId: filters.categoryId,
          collectionId: picked.isEmpty ? null : picked,
        ),
      );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.surfaceMuted,
    borderRadius: AppRadii.control,
    child: InkWell(
      borderRadius: AppRadii.control,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _Choice {
  const _Choice(this.year, this.month);
  final int year;
  final int? month;
}

class ArchiveSheet extends StatelessWidget {
  const ArchiveSheet({super.key, required this.items});
  final List<VideoArchive> items;
  @override
  Widget build(BuildContext context) {
    final years = items.map((x) => x.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return ListView(
      children: [
        for (final year in years)
          ExpansionTile(
            title: Text('$year년'),
            children: [
              ListTile(
                title: const Text('전체'),
                onTap: () => Navigator.pop(context, _Choice(year, null)),
              ),
              for (final item
                  in (items.where((x) => x.year == year).toList()
                    ..sort((a, b) => b.month.compareTo(a.month))))
                ListTile(
                  title: Text('${item.month}월'),
                  trailing: Text('${item.videoCount}'),
                  onTap: () =>
                      Navigator.pop(context, _Choice(year, item.month)),
                ),
            ],
          ),
      ],
    );
  }
}

class CollectionStrip extends StatelessWidget {
  const CollectionStrip({super.key, required this.items, required this.onTap});
  final List<VideoCollection> items;
  final ValueChanged<VideoCollection> onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return SizedBox(
            width: 180,
            child: Card(
              child: InkWell(
                borderRadius: AppRadii.card,
                onTap: () => onTap(item),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      const Text(
                        '영상 모음',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.video,
    this.category,
    this.collection,
    required this.onTap,
  });
  final VideoItem video;
  final String? category, collection;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(2),
            child: Thumbnail(video: video, width: 152, height: 85.5),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel(video.recordedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (category != null || collection != null)
                    Text(
                      [category, collection].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Thumbnail extends StatelessWidget {
  const Thumbnail({
    super.key,
    required this.video,
    required this.width,
    required this.height,
  });
  final VideoItem video;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        video.sourceType == VideoSourceType.youtube
            ? Icons.play_circle_outline_rounded
            : Icons.video_library_outlined,
        color: AppColors.textMuted,
      ),
    );
    final url = video.thumbnailRef;
    return url == null || url.isEmpty
        ? fallback
        : Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
  }
}

String dateLabel(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')}';

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered});
  final bool filtered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70),
    child: Center(child: Text(filtered ? '조건에 맞는 영상이 없습니다.' : '등록된 영상이 없습니다.')),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('영상을 불러오지 못했습니다.'),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class CollectionDetail extends StatefulWidget {
  const CollectionDetail({
    super.key,
    required this.collection,
    required this.repo,
    this.category,
  });
  final VideoCollection collection;
  final VideoRepository repo;
  final String? category;
  @override
  State<CollectionDetail> createState() => _CollectionDetailState();
}

class _CollectionDetailState extends State<CollectionDetail> {
  late Future<List<VideoItem>> future;
  @override
  void initState() {
    super.initState();
    future = widget.repo.listVideos(
      widget.collection.churchId,
      filters: VideoFilters(collectionId: widget.collection.id),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('영상 모음')),
    body: FutureBuilder<List<VideoItem>>(
      future: future,
      builder: (context, s) {
        if (s.hasError)
          return _Error(
            onRetry: () => setState(
              () => future = widget.repo.listVideos(
                widget.collection.churchId,
                filters: VideoFilters(collectionId: widget.collection.id),
              ),
            ),
          );
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.collection.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.collection.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(widget.collection.description!),
            ],
            const SizedBox(height: 20),
            if (s.data!.isEmpty) const _Empty(filtered: false),
            ...s.data!.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VideoCard(
                  video: v,
                  category: widget.category,
                  collection: widget.collection.title,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoDetail(
                        video: v,
                        category: widget.category,
                        collection: widget.collection.title,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class VideoDetail extends StatelessWidget {
  const VideoDetail({
    super.key,
    required this.video,
    this.category,
    this.collection,
  });
  final VideoItem video;
  final String? category, collection;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('영상')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: AppRadii.card,
            child: video.sourceType == VideoSourceType.youtube
                ? YouTubePreview(videoId: video.sourceRef)
                : Thumbnail(
                    video: video,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text(video.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(dateLabel(video.recordedAt)),
        if (category != null || collection != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in [category, collection].whereType<String>())
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadii.control,
                    ),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: AppColors.primaryStrong),
                    ),
                  ),
              ],
            ),
          ),
        if (video.description?.isNotEmpty == true) ...[
          const SizedBox(height: 24),
          Text('설명', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            video.description!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ],
    ),
  );
}

class YouTubePreview extends StatefulWidget {
  const YouTubePreview({super.key, required this.videoId});
  final String videoId;
  @override
  State<YouTubePreview> createState() => _YouTubePreviewState();
}

class _YouTubePreviewState extends State<YouTubePreview>
    with WidgetsBindingObserver {
  late YoutubePlayerController controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller.pauseVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: YoutubePlayer(controller: controller),
  );
}
