import 'home_repository.dart';
import '../domain/home_models.dart';

class MockHomeRepository implements HomeRepository {
  @override
  Future<HomeContent> getHomeContent(String churchId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return HomeContent(
      live: LiveBroadcast(
        id: 'live-$churchId',
        churchId: churchId,
        title: churchId == 'sky-gate' ? '주일예배 생방송' : '주일 성회 생방송',
        thumbnailUrl: '',
        startedAt: DateTime(2026, 8, 30, 11),
        youtubeVideoId: 'mock-youtube-id',
        isLive: true,
      ),
      schedules: const [
        WorshipSchedule(name: '주일예배', time: '11:00'),
        WorshipSchedule(name: '주일학교', time: '11:00'),
        WorshipSchedule(name: '수요예배', time: '19:30'),
        WorshipSchedule(name: '새벽기도회', time: '05:30'),
      ],
      recentVideos: [
        RecentVideo(
          id: 'video-1-$churchId',
          churchId: churchId,
          title: '2026 하계 수련회',
          publishedAt: DateTime(2026, 8, 20),
          duration: '1:32:45',
          thumbnailUrl: '',
        ),
        RecentVideo(
          id: 'video-2-$churchId',
          churchId: churchId,
          title: '특별 새벽기도회',
          publishedAt: DateTime(2026, 8, 17),
          duration: '45:12',
          thumbnailUrl: '',
        ),
      ],
    );
  }
}
