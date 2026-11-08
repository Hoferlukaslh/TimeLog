import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../utils/ui.dart';

/// Text field with a small Markdown toolbar and a preview tab.
class MarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;

  const MarkdownEditor({super.key, required this.controller, required this.label, this.minLines = 6});

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  bool _preview = false;

  void _wrap(String before, [String? after]) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    after ??= before;
    if (!sel.isValid) {
      c.text = '$text$before$after';
      c.selection = TextSelection.collapsed(offset: text.length + before.length);
      return;
    }
    final selected = sel.textInside(text);
    final n = sel.textBefore(text) + before + selected + after + sel.textAfter(text);
    c.value = TextEditingValue(
      text: n,
      selection: TextSelection(
        baseOffset: sel.start + before.length,
        extentOffset: sel.start + before.length + selected.length,
      ),
    );
  }

  void _linePrefix(String prefix) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    final pos = sel.isValid ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', pos == 0 ? 0 : pos - 1) + 1;
    final n = text.substring(0, lineStart) + prefix + text.substring(lineStart);
    c.value = TextEditingValue(
      text: n,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.edit), label: Text(l.write)),
                  ButtonSegment(value: true, icon: const Icon(Icons.visibility), label: Text(l.preview)),
                ],
                selected: {_preview},
                onSelectionChanged: (s) => setState(() => _preview = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_preview)
          Container(
            constraints: BoxConstraints(minHeight: widget.minLines * 20.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: MarkdownBody(data: widget.controller.text, selectable: true),
          )
        else ...[
          Wrap(
            children: [
              IconButton(icon: const Icon(Icons.format_bold), onPressed: () => _wrap('**')),
              IconButton(icon: const Icon(Icons.format_italic), onPressed: () => _wrap('*')),
              IconButton(icon: const Icon(Icons.title), onPressed: () => _linePrefix('## ')),
              IconButton(icon: const Icon(Icons.format_list_bulleted), onPressed: () => _linePrefix('- ')),
              IconButton(icon: const Icon(Icons.format_list_numbered), onPressed: () => _linePrefix('1. ')),
              IconButton(icon: const Icon(Icons.check_box_outlined), onPressed: () => _linePrefix('- [ ] ')),
              IconButton(icon: const Icon(Icons.code), onPressed: () => _wrap('`')),
            ],
          ),
          TextField(
            controller: widget.controller,
            minLines: widget.minLines,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: l.markdownHint,
              helperMaxLines: 2,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }
}
