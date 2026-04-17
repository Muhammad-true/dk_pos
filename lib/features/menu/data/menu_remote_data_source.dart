import 'package:dk_pos/shared/shared.dart';

abstract class MenuRemoteDataSource {
  Future<List<PosCategory>> fetchPosMenu({String lang = 'ru'});
}
