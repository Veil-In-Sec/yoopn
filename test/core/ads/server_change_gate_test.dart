import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/ads/ad_counter_store.dart';
import 'package:yoopn/core/ads/server_change_gate.dart';

void main() {
  test('first 8 server changes are free, 9th+ requires the ad', () async {
    final store = MemoryAdCounterStore();

    for (var i = 0; i < ServerChangeGate.freeChanges; i++) {
      expect(await ServerChangeGate.requiresAd(store), isFalse);
    }
    expect(await store.getServerChangeCount(), ServerChangeGate.freeChanges);

    expect(await ServerChangeGate.requiresAd(store), isTrue);
    expect(await ServerChangeGate.requiresAd(store), isTrue);
    expect(await store.getServerChangeCount(), ServerChangeGate.freeChanges);
  });
}
