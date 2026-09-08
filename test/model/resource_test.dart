import 'package:flutter_test/flutter_test.dart';
import 'package:jett/model/resource.dart';

/// What each kind of resource can offer the native data plane.
///
/// This is the question that decides whether a transfer runs in Rust or in
/// Dart, and it used to be answered by testing whether `identifier` started
/// with a slash. Three of the cases below are ones that test got wrong.
void main() {
  group('a plain file', () {
    test('offers its path', () async {
      final source = await FileResource('/tmp/holiday.mp4').nativeSource();
      expect(source, isA<NativePath>());
      expect((source! as NativePath).path, '/tmp/holiday.mp4');
    });
  });

  group('a resource wrapping a local path', () {
    // Files dropped onto the desktop window arrive as absolute paths and are
    // wrapped as ContentResource, which turns them into file:// URIs. They are
    // ordinary files and the native side can open them.
    test('offers the path back, not the URI', () async {
      final dropped = ContentResource(uri: '/home/sangam/holiday.mp4');
      expect(dropped.identifier, startsWith('file://'));

      final source = await dropped.nativeSource();
      expect(source, isA<NativePath>());
      expect((source! as NativePath).path, '/home/sangam/holiday.mp4');
    });

    test('survives a name that has to be escaped', () async {
      final dropped = ContentResource(uri: '/home/sangam/two words.bin');
      final source = await dropped.nativeSource();
      expect((source! as NativePath).path, '/home/sangam/two words.bin');
    });

    test('a Windows path does not parse as a URI scheme', () {
      // 'C:\dir\f.bin' read as a URI has scheme 'c'. Uri.file is what keeps the
      // drive letter part of the path.
      expect(Uri.parse(r'C:\dir\f.bin').scheme, 'c');

      final identifier = ContentResource(uri: r'C:\dir\f.bin').identifier;
      expect(identifier, 'file:///C:/dir/f.bin');
      expect(
        Uri.parse(identifier).toFilePath(windows: true),
        r'C:\dir\f.bin',
        reason: 'the drive letter has to survive the round trip',
      );
    });
  });

  group('a content:// URI', () {
    test('offers nothing off Android, where nothing can open it', () async {
      // The descriptor comes from Android's ContentResolver. On every other
      // platform there is no such thing, so the bytes go through Dart.
      final provider = ContentResource(
        uri: 'content://media/external/images/media/42',
        name: 'photo.jpg',
      );
      expect(provider.identifier, startsWith('content://'));
      expect(await provider.nativeSource(), isNull);
    });
  });
}
