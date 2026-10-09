import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/utils/notification_permission.dart';

/// Guards that permission handling can never break startup.
///
/// `permission_handler` has no method channel in tests, so every real call
/// throws `MissingPluginException`. Both helpers must swallow it and report a
/// safe value instead of propagating into `YooPNApp.initState`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureGranted never throws when the plugin is unavailable', () async {
    await expectLater(NotificationPermission.ensureGranted(), completes);
  });

  test('isPermanentlyDenied never throws when the plugin is unavailable',
      () async {
    await expectLater(NotificationPermission.isPermanentlyDenied(), completes);
  });
}