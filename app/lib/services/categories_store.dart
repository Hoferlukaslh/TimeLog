import 'package:flutter/foundation.dart' hide Category;

import '../data/repository.dart';
import '../models/models.dart';

/// Cached list of categories shared by the journal and the notes.
class CategoriesStore extends ChangeNotifier {
  final _repo = Repository.instance;
  List<Category> items = [];

  Future<void> load() async {
    items = await _repo.categories();
    notifyListeners();
  }

  Category? byId(int? id) {
    if (id == null) return null;
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> save(Category c) async {
    await _repo.saveCategory(c);
    await load();
  }

  Future<void> delete(int id) async {
    await _repo.deleteCategory(id);
    await load();
  }
}
