import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:garden_helper/services/database_service.dart';
import 'package:garden_helper/screens/home_page.dart';

class DeviceInAppWebViewScreen extends StatefulWidget {
  final String deviceUrl;

  const DeviceInAppWebViewScreen({super.key, required this.deviceUrl});

  @override
  State<DeviceInAppWebViewScreen> createState() => _DeviceInAppWebViewScreenState();
}

class _DeviceInAppWebViewScreenState extends State<DeviceInAppWebViewScreen> {
  late final WebViewController _controller;
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ResponseChannel',
        onMessageReceived: (message) async {
          try {
            setState(() => _isLoading = true);
            
            // Parse the message from the device
            final data = json.decode(message.message);
            final deviceId = data['deviceId'] ?? '';
            final deviceName = data['deviceName'] ?? 'New Device';
            final response = data['message'] ?? message.message;
            
            if (deviceId.isEmpty) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Invalid device ID received';
              });
              return;
            }
            
            // Get the current user
            final user = Provider.of<User?>(context, listen: false);
            if (user == null) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'You must be logged in to register a device';
              });
              return;
            }
            
            // Check if the device already exists in Firebase
            final deviceDetails = await _databaseService.getDeviceDetails(deviceId);
            
            if (deviceDetails['status'] != 'offline' || deviceDetails['name'] != 'Unknown Device') {
              // Device exists, navigate to the device registered screen
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceRegisteredScreen(
                      deviceId: deviceId,
                      deviceName: deviceDetails['name'],
                      response: message.message,
                    ),
                  ),
                );
              }
            } else {
              // Device doesn't exist, add it to Firebase
              final success = await _databaseService.addDevice(user.uid, deviceId, deviceName);
              
              if (success && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceRegisteredScreen(
                      deviceId: deviceId,
                      deviceName: deviceName,
                      response: message.message,
                      isNewDevice: true,
                    ),
                  ),
                );
              } else if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Failed to register device. Please try again.';
                });
              }
            }
          } catch (e) {
            print('Error processing device response: $e');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Error: ${e.toString()}';
              });
            }
          }
        },
      )
      ..loadRequest(Uri.parse(widget.deviceUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_errorMessage.isNotEmpty)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = '';
                            });
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DeviceRegisteredScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;
  final String response;
  final bool isNewDevice;

  const DeviceRegisteredScreen({
    super.key, 
    required this.deviceId, 
    required this.deviceName, 
    required this.response,
    this.isNewDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Registered'),
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              isNewDevice 
                ? 'Device Successfully Registered!' 
                : 'Device Already Registered',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Device ID', deviceId),
                    const SizedBox(height: 8),
                    _buildInfoRow('Device Name', deviceName),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Device Response:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      response,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Navigate to the home page
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false, // Remove all previous routes
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
