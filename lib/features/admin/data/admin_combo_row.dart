/// Строка списка комбо (GET /api/combos).
class AdminComboRow {
  const AdminComboRow({
    required this.id,
    required this.nameRu,
    this.imagePath,
    required this.isActive,
    required this.sortOrder,
    this.validDateStart,
    this.validDateEnd,
    this.validTimeStart,
    this.validTimeEnd,
    this.validNow = true,
  });

  final int id;
  final String nameRu;
  final String? imagePath;
  final int isActive;
  final int sortOrder;
  final String? validDateStart;
  final String? validDateEnd;
  final String? validTimeStart;
  final String? validTimeEnd;
  final bool validNow;

  factory AdminComboRow.fromJson(Map<String, dynamic> j) {
    final n = j['name'];
    var ru = '';
    if (n is Map) {
      ru = n['ru']?.toString() ?? '';
    }
    return AdminComboRow(
      id: (j['id'] as num).toInt(),
      nameRu: ru,
      imagePath: j['imagePath']?.toString(),
      isActive: (j['isActive'] as num?)?.toInt() ?? 1,
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      validDateStart: j['validDateStart']?.toString(),
      validDateEnd: j['validDateEnd']?.toString(),
      validTimeStart: j['validTimeStart']?.toString(),
      validTimeEnd: j['validTimeEnd']?.toString(),
      validNow: j['validNow'] != false,
    );
  }
}
