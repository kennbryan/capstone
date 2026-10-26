import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// Renders the small Markdown subset used by articles: `## ` headings,
/// `- ` bullets, paragraphs, and `**bold**`.
class MarkdownText extends StatelessWidget {
  const new(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(
        _Spaced(
          Text.rich(_inline(paragraph.join(' '), theme.textTheme.bodyLarge)),
        ),
      );
      paragraph.clear();
    }

    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('## ')) {
        flush();
        blocks.add(
          _Spaced(
            Semantics(
              header: true,
              child: Text(
                line.substring(3),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        flush();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: theme.textTheme.bodyLarge),
                Expanded(
                  child: Text.rich(
                    _inline(line.substring(2), theme.textTheme.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        paragraph.add(line);
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static TextSpan _inline(String text, TextStyle? style) {
    final parts = text.split('**');
    return TextSpan(
      style: style,
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
      ],
    );
  }
}

class _Spaced extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: child,
  );
}
