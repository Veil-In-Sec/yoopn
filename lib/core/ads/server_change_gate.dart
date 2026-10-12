import 'package:yoopn/core/ads/ad_counter_store.dart';

class ServerChangeGate {
  ServerChangeGate._();

  static const int freeChanges = 8;

  static Future<bool> requiresAd(AdCounterStore store) async {
    final count = await store.getServerChangeCount();
    if (count < freeChanges) {
      await store.incrementServerChangeCount();
      return false;
    }
    return true;
  }
}
