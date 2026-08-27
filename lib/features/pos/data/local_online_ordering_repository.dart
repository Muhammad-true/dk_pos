import 'package:dk_pos/core/network/http_client.dart';

class OnlineOrderingStatus {
  const OnlineOrderingStatus({
    required this.available,
    required this.asapAvailable,
    required this.scheduledAvailable,
    required this.paused,
    required this.posOnline,
    required this.shiftOpen,
    required this.withinHours,
    required this.reason,
    required this.closedMessage,
    required this.workingHours,
    this.minutesUntilClose,
    this.posLastSeenAt,
  });

  final bool available;
  final bool asapAvailable;
  final bool scheduledAvailable;
  final bool paused;
  final bool posOnline;
  final bool shiftOpen;
  final bool withinHours;
  final String reason;
  final String closedMessage;
  final String workingHours;
  final int? minutesUntilClose;
  final DateTime? posLastSeenAt;

  factory OnlineOrderingStatus.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    DateTime? seen;
    final rawSeen = m['pos_last_seen_at'];
    if (rawSeen != null) {
      seen = DateTime.tryParse(rawSeen.toString());
    }
    final until = m['minutes_until_close'];
    return OnlineOrderingStatus(
      available: m['available'] == true,
      asapAvailable: m['asap_available'] == true,
      scheduledAvailable: m['scheduled_available'] == true,
      paused: m['ordering_paused'] == true,
      posOnline: m['pos_online'] == true,
      shiftOpen: m['shift_open'] == true,
      withinHours: m['within_hours'] == true,
      reason: m['reason']?.toString() ?? '',
      closedMessage: m['closed_message']?.toString() ?? '',
      workingHours: m['working_hours']?.toString() ?? '',
      minutesUntilClose: until is num ? until.round() : int.tryParse('$until'),
      posLastSeenAt: seen,
    );
  }

  String get shortLabel {
    if (paused) return 'Пауза онлайн';
    if (!posOnline) return 'POS без связи';
    if (!shiftOpen) return 'Смена закрыта';
    if (!asapAvailable && scheduledAvailable) return 'Только на завтра';
    if (available && asapAvailable) return 'Онлайн: приём';
    return 'Онлайн: стоп';
  }

  bool get isAcceptingAsap => asapAvailable;
}

class LocalOnlineOrderingRepository {
  LocalOnlineOrderingRepository(this._http);
  final HttpClient _http;

  Future<OnlineOrderingStatus?> fetchStatus() async {
    final res = await _http.get('/api/local/online-ordering/status');
    if (res.body is! Map) return null;
    final map = Map<String, dynamic>.from(res.body as Map);
    if (map['ok'] != true) return null;
    final ordering = map['ordering'];
    if (ordering is! Map) return null;
    return OnlineOrderingStatus.fromJson(Map<String, dynamic>.from(ordering));
  }

  Future<void> setPaused(bool paused) async {
    await _http.post('/api/local/online-ordering/pause', body: {'paused': paused});
  }
}
