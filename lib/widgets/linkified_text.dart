import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders text and automatically turns URLs into tappable links
/// that open in an external browser.
class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.bodyMedium;
    final linkStyle = (style ?? theme.textTheme.bodyMedium)?.copyWith(
      color: Colors.blueAccent,
      decoration: TextDecoration.underline,
    );

    final spans = _buildSpans(text, defaultStyle, linkStyle);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.visible,
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildSpans(
    String input,
    TextStyle? normalStyle,
    TextStyle? linkStyle,
  ) {
    final regex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    final spans = <InlineSpan>[];
    int start = 0;

    for (final match in regex.allMatches(input)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: input.substring(start, match.start),
            style: normalStyle,
          ),
        );
      }

      final url = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                final uri = Uri.parse(url);
                if (!await canLaunchUrl(uri)) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                // Silent failure; keep UI responsive
              }
            },
        ),
      );

      start = match.end;
    }

    if (start < input.length) {
      spans.add(TextSpan(text: input.substring(start), style: normalStyle));
    }

    return spans;
  }
}
