import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SubstackLoginScreen extends StatefulWidget {
  const SubstackLoginScreen({super.key});

  @override
  State<SubstackLoginScreen> createState() => _SubstackLoginScreenState();
}

class _SubstackLoginScreenState extends State<SubstackLoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _tryExtractCookie(),
        onProgress: (progress) {
          if (progress == 100 && _loading) {
            setState(() => _loading = false);
          }
        },
      ))
      ..loadRequest(Uri.parse('https://substack.com/sign-in'));
  }

  Future<void> _tryExtractCookie() async {
    try {
      final cookies = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookieStr = cookies.toString().replaceAll('"', '');
      final match = RegExp(r'substack\.sid=([^;]+)').firstMatch(cookieStr);
      if (match != null && mounted) {
        final sid = match.group(1)!;
        Navigator.pop(context, sid);
      }
    } catch (_) {
      // JS extraction failed (HttpOnly cookie) — user can use paste fallback
    }
  }

  void _showPasteDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste cookie value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The substack.sid cookie is HttpOnly and cannot be read '
              'from the page. Open your browser DevTools → Application '
              '→ Cookies, find "substack.sid", and paste its value below.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'substack.sid value',
                hintText: 'Paste cookie value here',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = ctrl.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(ctx); // close dialog
                Navigator.pop(context, value); // return to caller
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Substack Sign In'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'Paste cookie',
            onPressed: _showPasteDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
