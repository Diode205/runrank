import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _mobileUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
    'Mobile/15E148 Safari/604.1';

Future<void> _loadUri(
  WebViewController controller,
  Uri uri, {
  required bool forceMobileViewport,
}) async {
  if (!forceMobileViewport) {
    await controller.loadRequest(uri);
    return;
  }

  await _configureFittedViewport(controller);
  await controller.setUserAgent(_mobileUserAgent);
  await controller.loadRequest(uri);
}

Future<void> _configureFittedViewport(WebViewController controller) async {
  final platformController = controller.platform;

  try {
    await (platformController as dynamic).setUseWideViewPort(true);
  } catch (_) {
    // Only Android exposes this. Other platforms keep their normal behavior.
  }

  try {
    await (platformController as dynamic).setTextZoom(90);
  } catch (_) {
    // Only Android exposes this. Other platforms keep their normal behavior.
  }
}

Future<void> _fitPageToWebViewWidth(WebViewController controller) async {
  try {
    await controller.runJavaScript(r'''
      (function() {
        function fitRunRankPage() {
          var doc = document.documentElement;
          var body = document.body;
          if (!doc || !body) return;

          var wrapper = document.getElementById('__runrank_fit_wrapper');
          if (!wrapper) {
            wrapper = document.createElement('div');
            wrapper.id = '__runrank_fit_wrapper';
            while (body.firstChild) {
              wrapper.appendChild(body.firstChild);
            }
            body.appendChild(wrapper);
          }

          wrapper.style.transform = '';
          wrapper.style.width = '';
          wrapper.style.marginLeft = '';
          wrapper.style.transformOrigin = '0 0';
          wrapper.style.display = 'block';
          body.style.margin = '0';
          body.style.overflowX = 'hidden';
          body.style.backgroundColor = '#f4f4f4';
          doc.style.overflowX = 'hidden';

          var viewportWidth = doc.clientWidth || window.innerWidth || 1;
          var candidates = Array.prototype.slice.call(
            document.querySelectorAll(
              '#container, #wrapper, #page, .container, .wrapper, .page, table, main'
            )
          );
          var measurements = candidates.map(function(el) {
            var rect = el.getBoundingClientRect();
            return {
              width: Math.max(el.scrollWidth || 0, el.offsetWidth || 0, rect.width || 0),
              left: Math.max(0, rect.left || 0)
            };
          }).filter(function(item) {
            return item.width >= 600;
          });
          var best = measurements.sort(function(a, b) {
            return a.width - b.width;
          })[0];
          var contentWidth = Math.max(
            best ? best.width : 0,
            wrapper.offsetWidth,
            980
          );
          var scale = Math.min(
            1.08,
            (viewportWidth / contentWidth) * 1.10
          );
          var scaledWidth = contentWidth * scale;
          var offset = Math.max(0, (viewportWidth - scaledWidth) / 2);
          var visualTrimLeft = 26;

          wrapper.style.width = contentWidth + 'px';
          wrapper.style.marginLeft = (offset - visualTrimLeft) + 'px';
          wrapper.style.transform = 'scale(' + scale + ')';
          body.style.minHeight = (wrapper.scrollHeight * scale) + 'px';
          body.dataset.runrankFitReady = 'true';
        }

        fitRunRankPage();
        window.setTimeout(fitRunRankPage, 300);
        window.setTimeout(fitRunRankPage, 900);
      })();
    ''');
  } catch (_) {
    // The page still renders normally if script injection is unavailable.
  }
}

class WebLinkPreviewCard extends StatefulWidget {
  const WebLinkPreviewCard({
    super.key,
    required this.url,
    this.buttonLabel = 'View Full Page',
    this.height = 420,
    this.forceMobileViewport = false,
  });

  final String url;
  final String buttonLabel;
  final double height;
  final bool forceMobileViewport;

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
  var _isFitting = false;

  @override
  void initState() {
    super.initState();
    _uri = _parseUri(widget.url);
    if (_uri != null) {
      _controller = WebViewController();
      _configurePreviewController();
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

  Future<void> _configurePreviewController() async {
    final controller = _controller;
    final uri = _uri;
    if (controller == null || uri == null) return;

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (widget.forceMobileViewport && mounted) {
            setState(() => _isFitting = true);
          }
        },
        onPageFinished: (_) {
          if (widget.forceMobileViewport) {
            _fitPageToWebViewWidth(controller);
            Future<void>.delayed(const Duration(milliseconds: 450), () {
              if (mounted) {
                setState(() => _isFitting = false);
              }
            });
          }
        },
      ),
    );
    await _loadUri(
      controller,
      uri,
      forceMobileViewport: widget.forceMobileViewport,
    );
  }

  Future<void> _openInApp() async {
    final uri = _uri;
    if (uri == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WebLinkBrowserPage(
          uri: uri,
          title: uri.host.replaceFirst('www.', ''),
          forceMobileViewport: widget.forceMobileViewport,
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
            if (_isFitting)
              const ColoredBox(
                color: Color(0xFFF4F4F4),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
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
  const _WebLinkBrowserPage({
    required this.uri,
    required this.title,
    required this.forceMobileViewport,
  });

  final Uri uri;
  final String title;
  final bool forceMobileViewport;

  @override
  State<_WebLinkBrowserPage> createState() => _WebLinkBrowserPageState();
}

class _WebLinkBrowserPageState extends State<_WebLinkBrowserPage> {
  late final WebViewController _controller;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _configureBrowserController();
  }

  Future<void> _configureBrowserController() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() => _isLoading = true);
          }
        },
        onPageFinished: (_) {
          if (widget.forceMobileViewport) {
            _fitPageToWebViewWidth(_controller);
            Future<void>.delayed(const Duration(milliseconds: 450), () {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            });
            return;
          }
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
    await _loadBrowserUri(widget.uri);
  }

  Future<void> _loadBrowserUri(Uri uri) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    await _loadUri(
      _controller,
      uri,
      forceMobileViewport: widget.forceMobileViewport,
    );
    if (mounted && widget.forceMobileViewport) {
      setState(() => _isLoading = false);
    }
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
