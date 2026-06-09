import 'dart:convert';
import 'dart:io';

/// Запрос действия с экрана клиента → касса (через файл в %TEMP%).
enum CustomerDisplayPosAction {
  discount,
  checkout,
  setMenuPath,
  menuBack,
  addItem,
  setOrderType,
}

class CustomerDisplayPosActionRequest {
  const CustomerDisplayPosActionRequest({
    required this.seq,
    required this.action,
    this.productId,
    this.pathIds,
    this.orderTypeIndex,
  });

  final int seq;
  final CustomerDisplayPosAction action;
  final String? productId;
  final List<int>? pathIds;
  final int? orderTypeIndex;

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'action': action.name,
        if (productId != null && productId!.trim().isNotEmpty)
          'productId': productId,
        if (pathIds != null && pathIds!.isNotEmpty) 'pathIds': pathIds,
        if (orderTypeIndex != null) 'orderTypeIndex': orderTypeIndex,
      };

  static CustomerDisplayPosActionRequest? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final seq = (json['seq'] as num?)?.toInt();
    final raw = json['action']?.toString().trim();
    if (seq == null || seq <= 0 || raw == null || raw.isEmpty) return null;
    final action = CustomerDisplayPosAction.values.asNameMap()[raw];
    if (action == null) return null;
    final pathRaw = json['pathIds'];
    final pathIds = pathRaw is List
        ? pathRaw.map((e) => (e as num).toInt()).toList(growable: false)
        : null;
    return CustomerDisplayPosActionRequest(
      seq: seq,
      action: action,
      productId: json['productId']?.toString(),
      pathIds: pathIds,
      orderTypeIndex: (json['orderTypeIndex'] as num?)?.toInt(),
    );
  }
}

File customerDisplayActionsFile(String syncFilePath) {
  final dir = File(syncFilePath).parent.path;
  return File('$dir${Platform.pathSeparator}actions.json');
}

Future<void> writeCustomerDisplayPosAction(
  String syncFilePath,
  CustomerDisplayPosAction action, {
  String? productId,
  List<int>? pathIds,
  int? orderTypeIndex,
}) async {
  final file = customerDisplayActionsFile(syncFilePath);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode(
      CustomerDisplayPosActionRequest(
        seq: DateTime.now().millisecondsSinceEpoch,
        action: action,
        productId: productId,
        pathIds: pathIds,
        orderTypeIndex: orderTypeIndex,
      ).toJson(),
    ),
    flush: true,
  );
}
