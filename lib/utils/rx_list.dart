import 'package:rxdart/rxdart.dart';

class RxList<T> {
  final BehaviorSubject<List<T>> _subject = BehaviorSubject<List<T>>.seeded([]);

  Stream<List<T>> get stream => _subject.stream;
  List<T> get current => _subject.value;

  void addItem(T item) {
    final updated = [...current, item];
    _subject.add(updated);
  }

  void removeItem(T item) {
    final updated = [...current];
    updated.remove(item);
    _subject.add(updated);
  }

  void removeWhere(bool Function(T item) test) {
    final updated = [...current];
    updated.removeWhere(test);
    _subject.add(updated);
  }

  void clear() {
    _subject.add([]);
  }

  void dispose() {
    _subject.close();
  }
}
