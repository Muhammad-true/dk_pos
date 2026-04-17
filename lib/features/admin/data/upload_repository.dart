import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class UploadRepository {
  UploadRepository(this._http);

  final HttpClient _http;

  /// Загрузка в папку `menu` на сервере; возвращает [dbPath] (`uploads/...`) для `image_path`.
  Future<String> uploadMenuImageBytes(List<int> bytes, String filename) async {
    var name = filename;
    if (name.isEmpty) name = 'image.jpg';
    final res = await _http.postMultipart(
      'api/upload',
      files: [
        HttpMultipartFile(bytes: bytes, filename: name),
      ],
      fields: {'folder': 'menu'},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final dbPath = data['dbPath']?.toString();
    if (dbPath == null || dbPath.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер не вернул путь к файлу');
    }
    return dbPath;
  }

  /// Загрузка в папку `tv` на сервере; возвращает путь для `screen_pages.config.tvVideoBg.path`.
  Future<String> uploadTvVideoBytes(List<int> bytes, String filename) async {
    var name = filename;
    if (name.isEmpty) name = 'clip.mp4';
    final res = await _http.postMultipart(
      'api/upload',
      files: [
        HttpMultipartFile(bytes: bytes, filename: name),
      ],
      fields: {'folder': 'tv'},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final dbPath = data['dbPath']?.toString();
    if (dbPath == null || dbPath.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер не вернул путь к файлу');
    }
    return dbPath;
  }

  /// Загрузка в папку `audio` на сервере; возвращает путь для sound-полей.
  Future<String> uploadAudioBytes(List<int> bytes, String filename) async {
    var name = filename;
    if (name.isEmpty) name = 'sound.mp3';
    final res = await _http.postMultipart(
      'api/upload',
      files: [
        HttpMultipartFile(bytes: bytes, filename: name),
      ],
      fields: {'folder': 'audio'},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final dbPath = data['dbPath']?.toString();
    if (dbPath == null || dbPath.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер не вернул путь к файлу');
    }
    return dbPath;
  }
}
