import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebLinkPreviewCard extends StatefulWidget {
  const WebLinkPreviewCard({
    super.key,
    required this.url,
    this.buttonLabel = 'View Full Page',
    this.height = 420,
  });

  final String url;
  final String buttonLabel;
  final double height;

  @override
  State<WebLinkPreviewCard> createState() => _WebLinkPreviewCardState();

  static String? extractFirstUrl(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    final match = RegExp(
      r"""(https?:\/\/[^\s"'<>]+|www\.[^\s"'<>]+)""",
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0);
  }

  static String removeFirstUrl(String? text) {
    if (text == null || text.trim().isEmpty) return '';

    final withoutEmbedHtml = _removeEmbedHtml(text);
    final withoutUrl = withoutEmbedHtml.replaceFirst(
      RegExp(
        r"""(https?:\/\/[^\s"'<>]+|www\.[^\s"'<>]+)""",
        caseSensitive: false,
      ),
      '',
    );

    return withoutUrl
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _removeEmbedHtml(String text) {
    final iframeMatch = RegExp(
      r'<\s*iframe\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (iframeMatch == null) return text;

    final firstTag = text.indexOf('<');
    final prefix = firstTag >= 0 ? text.substring(0, firstTag) : '';
    final lineBreak = text.lastIndexOf('\n', iframeMatch.start);
    final start = prefix.trim().isEmpty
        ? firstTag
        : lineBreak >= 0
        ? lineBreak + 1
        : firstTag;
    final end = text.lastIndexOf('>');
    if (start < 0 || end < start) return text;

    return '${text.substring(0, start)} ${text.substring(end + 1)}';
  }
}

class _WebLinkPreviewCardState extends State<WebLinkPreviewCard> {
  WebViewController? _controller;
  Uri? _uri;

  @override
  void initState() {
    super.initState();
    _uri = _parseUri(widget.url);
    if (_uri != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(_uri!);
    }
  }

  Uri? _parseUri(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return null;

    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';

    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _launchExternal() async {
    final uri = _uri;
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  Future<void> _openInApp() async {
    final uri = _uri;
    if (uri == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WebLinkBrowserPage(
          uri: uri,
          title: uri.host.replaceFirst('www.', ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uri == null || _controller == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This web link could not be previewed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: _controller!),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _openInApp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.buttonLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebLinkBrowserPage extends StatefulWidget {
  const _WebLinkBrowserPage({required this.uri, required this.title});

  final Uri uri;
  final String title;

  @override
  State<_WebLinkBrowserPage> createState() => _WebLinkBrowserPageState();
}

class _WebLinkBrowserPageState extends State<_WebLinkBrowserPage> {
  late final WebViewController _controller;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(widget.uri);
  }

  Future<void> _openExternal() async {
    final launched = await launchUrl(
      widget.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
