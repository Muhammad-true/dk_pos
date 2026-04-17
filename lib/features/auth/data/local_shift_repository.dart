import 'package:dk_pos/core/network/http_client.dart';

class LocalShiftRepository {
  LocalShiftRepository(this._http);

  final HttpClient _http;

  Future<void> openShift({
    String branchId = 'branch_1',
    String? terminalId,
  }) async {
    await _http.post(
      'api/local/shifts/open',
      body: {
        'branchId': branchId,
        if (terminalId != null && terminalId.trim().isNotEmpty)
          'terminalId': terminalId.trim(),
      },
    );
  }

  Future<void> closeShift({
    String branchId = 'branch_1',
  }) async {
    await _http.post(
      'api/local/shifts/close',
      body: {'branchId': branchId},
    );
  }
}
