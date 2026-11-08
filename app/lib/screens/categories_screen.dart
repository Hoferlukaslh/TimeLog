import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/categories_store.dart';
import '../services/settings.dart';
import '../utils/ui.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class CategoriesScreen extends StatelessWidget {
  final Widget? drawer;
  const CategoriesScreen({super.key, this.drawer});

  static Future<void> edit(BuildContext context, [Category? c]) async {
    final l = context.l;
    final name = TextEditingController(text: c?.name ?? '');
    var color = c?.color ?? AppSettings.accentColors.first;
    final store = context.read<CategoriesStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(c == null ? l.newCategory : l.editCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.categoryName),
              ),
              const SizedBox(height: 16),
              Text(l.categoryColor),
              const SizedBox(height: 8),
              ColorChoice(value: color, onChanged: (v) => setState(() => color = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  ctx.toast(l.nameRequired);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await store.save(Category(id: c?.id, name: name.text.trim(), color: color));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cats = context.watch<CategoriesStore>().items;
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(title: Text(l.menuCategories)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.newCategory,
        onPressed: () => edit(context),
        child: const Icon(Icons.add),
      ),
      body: cats.isEmpty
          ? Center(
              child: EmptyState(icon: Icons.label_outline, text: l.noCategories),
            )
          : CenteredListView(
              padding: const EdgeInsets.only(bottom: 88, top: 8),
              children: [
                for (final c in cats)
                  ListTile(
                    leading: CircleAvatar(backgroundColor: c.colorValue),
                    title: Text(c.name),
                    onTap: () => edit(context, c),
                    trailing: IconButton(
                      tooltip: l.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final store = context.read<CategoriesStore>();
                        if (await Pickers.confirm(context, message: l.categoryDeleteMessage)) {
                          await store.delete(c.id!);
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class ColorChoice extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const ColorChoice({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in AppSettings.accentColors)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onChanged(c),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(c),
              child: c == value ? const Icon(Icons.check, color: Colors.white) : null,
            ),
          ),
      ],
    );
  }
}
