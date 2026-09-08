import 'package:flutter_test/flutter_test.dart';
import 'package:jett/transfer/server.dart';

void main() {
  group('a filename chosen by the sender', () {
    test('an ordinary name is left alone', () {
      expect(safeFileName('holiday.jpg'), 'holiday.jpg');
      expect(safeFileName('report v2 (final).pdf'), 'report v2 (final).pdf');
    });

    test('cannot climb out of the download directory', () {
      expect(safeFileName('../../../.bashrc'), 'bashrc');
      expect(safeFileName('../secrets.txt'), 'secrets.txt');
      expect(safeFileName('a/b/c.txt'), 'c.txt');
    });

    test('cannot be an absolute path', () {
      // path.join hands an absolute second argument straight back, so this is
      // the case that would otherwise write outside the directory entirely.
      expect(safeFileName('/etc/passwd'), 'passwd');
      expect(safeFileName('/tmp/x/y.bin'), 'y.bin');
    });

    test('cannot use Windows separators to get around it', () {
      // The name crosses between machines, so the host's idea of a separator
      // is not the sender's.
      expect(
        safeFileName(r'..\..\Windows\System32\drivers\etc\hosts'),
        'hosts',
      );
      expect(safeFileName(r'C:\Users\me\thing.txt'), 'thing.txt');
    });

    test('cannot hide the file with a leading dot', () {
      expect(safeFileName('.ssh_config'), 'ssh_config');
    });

    test('falls back to something usable when there is no name', () {
      expect(safeFileName(null), 'file');
      expect(safeFileName(''), 'file');
      expect(safeFileName('   '), 'file');
      expect(safeFileName('..'), 'file');
      expect(safeFileName('.'), 'file');
      expect(safeFileName('/'), 'file');
    });

    test('never returns anything with a separator left in it', () {
      const nasty = [
        '../../etc/passwd',
        r'..\..\etc\passwd',
        '/absolute/path',
        'a/b/c',
        './x',
      ];
      for (final name in nasty) {
        final safe = safeFileName(name);
        expect(safe, isNot(contains('/')), reason: 'from $name');
        expect(safe, isNot(contains(r'\')), reason: 'from $name');
        expect(safe, isNot(startsWith('.')), reason: 'from $name');
      }
    });
  });
}
