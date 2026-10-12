import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/utils/notification_permission.dart';

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