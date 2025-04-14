import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DeviceInAppWebViewScreen extends StatefulWidget {
  final String deviceUrl;

  const DeviceInAppWebViewScreen({super.key, required this.deviceUrl});

  @override
  State<DeviceInAppWebViewScreen> createState() => _DeviceInAppWebViewScreenState();
}

class _DeviceInAppWebViewScreenState extends State<DeviceInAppWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ResponseChannel',
        onMessageReceived: (message) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(response: message.message),
            ),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.deviceUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  final String response;
  const SuccessScreen({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Success')),
      body: Center(
        child: Text(
          'Received from ESP:\n$response',
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
