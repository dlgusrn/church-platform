import 'package:flutter_test/flutter_test.dart';
import 'package:church_app/core/navigation/app_destination.dart';
import 'package:church_app/core/permission/app_permission.dart';

void main() {
  bool hasVideo(Set<AppPermission> permissions) =>
      NavigationPolicy.available(permissions)
          .any((item) => item.key == AppDestinationKey.video);
  test('video navigation requires a read permission', () {
    expect(hasVideo({AppPermission.vodView}), isTrue);
    expect(hasVideo({AppPermission.mediaVideoView}), isTrue);
    expect(hasVideo(const {}), isFalse);
    expect(hasVideo({AppPermission.mediaVideoDownload}), isFalse);
  });
}
