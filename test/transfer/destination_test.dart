import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jett/transfer/destination.dart';

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
      expect(safeFileName('..ssh_config'), 'ssh_config');
      expect(safeFileName('...x'), 'x');
    });

    test('running it twice agrees with running it once', () {
      const names = [
        'holiday.jpg',
        '..foo',
        '...x',
        '.bashrc',
        '../../etc/passwd',
        '..',
        '',
      ];
      for (final name in names) {
        expect(
          safeFileName(safeFileName(name)),
          safeFileName(name),
          reason: 'from $name',
        );
      }
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
        '..x',
        '...x',
        '../..x',
      ];
      for (final name in nasty) {
        final safe = safeFileName(name);
        expect(safe, isNot(contains('/')), reason: 'from $name');
        expect(safe, isNot(contains(r'\')), reason: 'from $name');
        expect(safe, isNot(startsWith('.')), reason: 'from $name');
      }
    });
  });

  group('choosing where a file lands', () {
    late Directory workspace;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('jett-destinations');
    });

    tearDown(() => workspace.deleteSync(recursive: true));

    test('sanitises the name on the way through', () async {
      final landed = await unusedPathIn(workspace.path, '../../etc/passwd');
      expect(landed.parent.path, workspace.path);
      expect(landed.path, endsWith('passwd'));
    });

    test('steps around a file that is already there', () async {
      File('${workspace.path}/holiday.mp4').writeAsStringSync('first');

      final landed = await unusedPathIn(workspace.path, 'holiday.mp4');
      expect(landed.path, endsWith('holiday (1).mp4'));
    });

    test('steps around a name claimed but not yet written', () async {
      // Two files offered under one name. Neither exists on disk yet, so
      // without `claimed` both would resolve to the same path and the second
      // would overwrite the first.
      final first = await unusedPathIn(workspace.path, 'a.bin');
      final second = await unusedPathIn(
        workspace.path,
        'a.bin',
        claimed: {first.path},
      );

      expect(second.path, isNot(first.path));
      expect(second.path, endsWith('a (1).bin'));
    });
  });
}
