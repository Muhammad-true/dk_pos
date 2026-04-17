import 'package:dk_pos/features/menu/data/menu_remote_data_source.dart';
import 'package:dk_pos/shared/shared.dart';

class MenuRepository {
  MenuRepository(this._remote);

  final MenuRemoteDataSource _remote;

  Future<List<PosCategory>> fetchMenu({String lang = 'ru'}) {
    return _remote.fetchPosMenu(lang: lang);
  }
}
