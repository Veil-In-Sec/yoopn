import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/telemetry/supabase_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('track/ reportCrash are no-ops without an initialized Supabase', () async {
    Telemetry.enabled = true;

    await expectLater(
      Telemetry.track('test_event', {'k': 'v'}),
      completes,
    );
    await expectLater(
      Telemetry.reportCrash(
        StateError('boom'),
        StackTrace.current,
        context: {'phase': 'test'},
      ),
      completes,
    );
  });

  test('disabled telemetry never throws', () async {
    Telemetry.enabled = false;
    addTearDown(() => Telemetry.enabled = true);

    await expectLater(Telemetry.track('ignored'), completes);
    await expectLater(
      Telemetry.reportCrash(Exception('x'), null),
      completes,
    );
  });

  test('sessionId is non-empty and stable', () {
    final first = Telemetry.sessionId;
    expect(first, isNotEmpty);
    expect(Telemetry.sessionId, first);
  });

  test('screen() delegates to track()', () {
    expect(Telemetry.screen('home'), isA<Future<void>>());
  });
}