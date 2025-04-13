import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A screen that displays a WebView for interacting with the device's web interface
class DeviceWebViewScreen extends StatefulWidget {
  final String deviceUrl;

  const DeviceWebViewScreen({
    super.key,
    required this.deviceUrl,
  });

  @override
  State<DeviceWebViewScreen> createState() => _DeviceWebViewScreenState();
}

class _DeviceWebViewScreenState extends State<DeviceWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Error: ${error.description}';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.deviceUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          if (_errorMessage == null)
            WebViewWidget(controller: _controller),
          
          // Error message
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not connect to device',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _controller.reload();
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}