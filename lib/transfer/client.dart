import 'dart:io';

import 'package:http/http.dart' as http;

class Client {
  void upload(List<File> files, String ipAddress, int port) async {
    final fileSize = await getFileSize(files);
    final uri = Uri.parse('http://$ipAddress:$port/upload');
    final request = http.MultipartRequest('POST', uri);

    for (var file in files) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }

    request.headers['x-file-size'] = fileSize.toString();
    final response = await request.send();
    if (response.statusCode == 200) {
      print('Files uploaded successfully');
    } else {
      print('Failed to upload files: ${response.statusCode}');
    }
  }
}

Future<int> getFileSize(List<File> files) async {
  return files.fold(0, (total, file) async {
    return await total + await file.length();
  });
}
