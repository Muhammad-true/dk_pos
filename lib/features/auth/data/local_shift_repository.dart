import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalShiftRepository {
  LocalShiftRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<void> openShift({
    String? branchId,
    String? terminalId,
  }) async {
    await _http.post(
      'api/local/shifts/open',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        if (terminalId != null && terminalId.trim().isNotEmpty)
          'terminalId': terminalId.trim(),
      },
    );
  }

  Future<void> closeShift({
    String? branchId,
  }) async {
    await _http.post(
      'api/local/shifts/close',
      body: {'branchId': branchId ?? _defaultBranchId},
    );
  }
}
