import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalReceiptSettings {
  const LocalReceiptSettings({
    required this.brandName,
    required this.siteUrl,
    required this.footerLine1,
    required this.showFooterLine1,
    required this.footerLine2,
    required this.showFooterLine2,
    required this.qrEnabled,
    required this.qrSize,
    required this.showOrderItems,
    required this.showUnitPrice,
    required this.showCashier,
    required this.showPaymentMethod,
    required this.showBranch,
    required this.showBusinessInfo,
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyInn,
    required this.showFiscalInfo,
    required this.fiscalKkm,
    required this.fiscalRnm,
    required this.fiscalCashierId,
    required this.fiscalShiftNo,
    required this.showTax,
    required this.taxPercent,
    required this.taxLabel,
    required this.taxIncluded,
    required this.gdiLeftOffset,
    required this.receiptCharsPerLine,
    required this.trimItemPriceZeros,
  });

  final String brandName;
  final String siteUrl;
  final String footerLine1;
  final bool showFooterLine1;
  final String footerLine2;
  final bool showFooterLine2;
  final bool qrEnabled;
  final int qrSize;
  final bool showOrderItems;
  final bool showUnitPrice;
  final bool showCashier;
  final bool showPaymentMethod;
  final bool showBranch;
  final bool showBusinessInfo;
  final String? companyName;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyInn;
  final bool showFiscalInfo;
  final String? fiscalKkm;
  final String? fiscalRnm;
  final String? fiscalCashierId;
  final String? fiscalShiftNo;
  final bool showTax;
  final double taxPercent;
  final String taxLabel;
  final bool taxIncluded;
  final int gdiLeftOffset;
  final int receiptCharsPerLine;
  final bool trimItemPriceZeros;

  factory LocalReceiptSettings.fromJson(Map settings) {
    return LocalReceiptSettings(
      brandName: settings['brandName']?.toString() ?? 'DONER KEBAB',
      siteUrl: settings['siteUrl']?.toString() ?? 'https://donerkebab.tj',
      footerLine1: settings['footerLine1']?.toString() ?? 'Спасибо за покупку!',
      showFooterLine1: settings['showFooterLine1'] == null
          ? true
          : settings['showFooterLine1'] == true || settings['showFooterLine1'].toString() == '1',
      footerLine2: settings['footerLine2']?.toString() ?? '',
      showFooterLine2: settings['showFooterLine2'] == null
          ? true
          : settings['showFooterLine2'] == true || settings['showFooterLine2'].toString() == '1',
      qrEnabled: settings['qrEnabled'] == null
          ? true
          : settings['qrEnabled'] == true || settings['qrEnabled'].toString() == '1',
      qrSize: int.tryParse(settings['qrSize']?.toString() ?? '') ?? 7,
      showOrderItems: settings['showOrderItems'] == null
          ? true
          : settings['showOrderItems'] == true || settings['showOrderItems'].toString() == '1',
      showUnitPrice: settings['showUnitPrice'] == null
          ? true
          : settings['showUnitPrice'] == true || settings['showUnitPrice'].toString() == '1',
      showCashier: settings['showCashier'] == null
          ? true
          : settings['showCashier'] == true || settings['showCashier'].toString() == '1',
      showPaymentMethod: settings['showPaymentMethod'] == null
          ? true
          : settings['showPaymentMethod'] == true || settings['showPaymentMethod'].toString() == '1',
      showBranch: settings['showBranch'] == null
          ? true
          : settings['showBranch'] == true || settings['showBranch'].toString() == '1',
      showBusinessInfo: settings['showBusinessInfo'] == null
          ? false
          : settings['showBusinessInfo'] == true || settings['showBusinessInfo'].toString() == '1',
      companyName: settings['companyName']?.toString(),
      companyAddress: settings['companyAddress']?.toString(),
      companyPhone: settings['companyPhone']?.toString(),
      companyInn: settings['companyInn']?.toString(),
      showFiscalInfo: settings['showFiscalInfo'] == null
          ? false
          : settings['showFiscalInfo'] == true || settings['showFiscalInfo'].toString() == '1',
      fiscalKkm: settings['fiscalKkm']?.toString(),
      fiscalRnm: settings['fiscalRnm']?.toString(),
      fiscalCashierId: settings['fiscalCashierId']?.toString(),
      fiscalShiftNo: settings['fiscalShiftNo']?.toString(),
      showTax: settings['showTax'] == null
          ? false
          : settings['showTax'] == true || settings['showTax'].toString() == '1',
      taxPercent: num.tryParse(settings['taxPercent']?.toString() ?? '')?.toDouble() ?? 0,
      taxLabel: settings['taxLabel']?.toString() ?? 'НДС',
      taxIncluded: settings['taxIncluded'] == null
          ? true
          : settings['taxIncluded'] == true || settings['taxIncluded'].toString() == '1',
      gdiLeftOffset: int.tryParse(settings['gdiLeftOffset']?.toString() ?? '') ?? 0,
      receiptCharsPerLine: int.tryParse(settings['receiptCharsPerLine']?.toString() ?? '') ?? 36,
      trimItemPriceZeros: settings['trimItemPriceZeros'] == null
          ? true
          : settings['trimItemPriceZeros'] == true ||
                settings['trimItemPriceZeros'].toString() == '1',
    );
  }
}

class LocalReceiptSettingsRepository {
  LocalReceiptSettingsRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<LocalReceiptSettings> fetch({String? branchId}) async {
    final res = await _http.get(
      'api/local/receipt-settings',
      query: {'branchId': branchId ?? _defaultBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map || body['settings'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ receipt settings');
    }
    return LocalReceiptSettings.fromJson(body['settings'] as Map);
  }

  Future<LocalReceiptSettings> update({
    required String brandName,
    required String siteUrl,
    required String footerLine1,
    required bool showFooterLine1,
    required String footerLine2,
    required bool showFooterLine2,
    required bool qrEnabled,
    required int qrSize,
    required bool showOrderItems,
    required bool showUnitPrice,
    required bool showCashier,
    required bool showPaymentMethod,
    required bool showBranch,
    required bool showBusinessInfo,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyInn,
    required bool showFiscalInfo,
    String? fiscalKkm,
    String? fiscalRnm,
    String? fiscalCashierId,
    String? fiscalShiftNo,
    required bool showTax,
    required double taxPercent,
    required String taxLabel,
    required bool taxIncluded,
    required int gdiLeftOffset,
    required int receiptCharsPerLine,
    required bool trimItemPriceZeros,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/receipt-settings',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'brandName': brandName,
        'siteUrl': siteUrl,
        'footerLine1': footerLine1,
        'showFooterLine1': showFooterLine1,
        'footerLine2': footerLine2,
        'showFooterLine2': showFooterLine2,
        'qrEnabled': qrEnabled,
        'qrSize': qrSize,
        'showOrderItems': showOrderItems,
        'showUnitPrice': showUnitPrice,
        'showCashier': showCashier,
        'showPaymentMethod': showPaymentMethod,
        'showBranch': showBranch,
        'showBusinessInfo': showBusinessInfo,
        'companyName': companyName,
        'companyAddress': companyAddress,
        'companyPhone': companyPhone,
        'companyInn': companyInn,
        'showFiscalInfo': showFiscalInfo,
        'fiscalKkm': fiscalKkm,
        'fiscalRnm': fiscalRnm,
        'fiscalCashierId': fiscalCashierId,
        'fiscalShiftNo': fiscalShiftNo,
        'showTax': showTax,
        'taxPercent': taxPercent,
        'taxLabel': taxLabel,
        'taxIncluded': taxIncluded,
        'gdiLeftOffset': gdiLeftOffset,
        'receiptCharsPerLine': receiptCharsPerLine,
        'trimItemPriceZeros': trimItemPriceZeros,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map || body['settings'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ после сохранения receipt settings');
    }
    return LocalReceiptSettings.fromJson(body['settings'] as Map);
  }
}
