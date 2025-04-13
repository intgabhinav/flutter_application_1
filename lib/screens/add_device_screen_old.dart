import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:flutter_application_1/shared/loading.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math' show min;

// Import our services and screens
import 'package:flutter_application_1/services/wifi_service.dart';
import 'package:flutter_application_1/screens/captive_portal_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _database = DatabaseService();
  final TextEditingController _deviceNameController = TextEditingController();

  // Track the current step in the device registration flow
  int _currentStep = 0;

  // Steps in the registration flow
  static const int STEP_POWER_DEVICE = 0;
  static const int STEP_SEARCHING = 1;
  static const int STEP_DEVICE_FOUND = 2;
  static const int STEP_NAMING_DEVICE = 3;
  static const int STEP_REGISTERING = 4;
  static const int STEP_COMPLETE = 5;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isScanning = false;

  // Device information from the scan
  Map<String, dynamic>? _foundDevice;

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Device'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: _isLoading
          ? const Loading()
          : _buildCurrentStep(user, theme),
    );
  }

  Widget _buildCurrentStep(User? user, ThemeData theme) {
    switch (_currentStep) {
      case STEP_POWER_DEVICE:
        return _buildPowerDeviceStep(theme);
      case STEP_SEARCHING:
        return _buildSearchingStep(theme);
      case STEP_DEVICE_FOUND:
        return _buildDeviceFoundStep(theme);
      case STEP_NAMING_DEVICE:
        return _buildNamingDeviceStep(user, theme);
      case STEP_REGISTERING:
        return const Loading();
      case STEP_COMPLETE:
        return _buildCompleteStep(theme);
      default:
        return _buildPowerDeviceStep(theme);
    }
  }

  // Step 1: Power up device instructions
  Widget _buildPowerDeviceStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.power_settings_new,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),
          const Text(
            'Power Up Your Device',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'Make sure your device is powered up and blinking before continuing.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(height: 10),
                  Text(
                    'Setup Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. Plug in your device to a power source\n'
                    '2. Wait for the LED to start blinking blue\n'
                    '3. Press the Next button below to continue',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // Move to the WiFi connection step
              setState(() {
                _currentStep = STEP_SEARCHING;
                _errorMessage = null;
              });
            },
            child: const Text(
              'Next',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // This is just a placeholder to avoid compilation errors
  // The actual implementation would be much more complex
  Widget _buildDeviceFoundStep(ThemeData theme) {
    return Container();
  }

  // This is just a placeholder to avoid compilation errors
  // The actual implementation would be much more complex
  Widget _buildNamingDeviceStep(User? user, ThemeData theme) {
    return Container();
  }

  // This is just a placeholder to avoid compilation errors
  // The actual implementation would be much more complex
  Widget _buildCompleteStep(ThemeData theme) {
    return Container();
  }

  // Step 2: Connect to device WiFi and scan for devices
  Widget _buildSearchingStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            _isScanning ? Icons.search : Icons.wifi,
            size: 80,
            color: _isScanning ? Colors.green : Colors.blue,
          ),
          const SizedBox(height: 32),
          Text(
            _isScanning ? 'Scanning for Devices...' : 'Connect to Device WiFi',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _isScanning ? 'Scanning for devices...' : 'Opening WiFi settings...',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else if (_isScanning)
            // Show scanning animation and feedback
            Column(
              children: [
                const SizedBox(
                  height: 100,
                  width: 100,
                  child: CircularProgressIndicator(
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Looking for ESP devices...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This may take a few moments',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else
            // Show WiFi connection instructions
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You must connect to the device\'s WiFi network before continuing',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        label: const Text('Open WiFi Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          _connectToDeviceWifi();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Skynet-AutoConnect',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Steps to connect:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Tap "Open WiFi Settings" below\n'
                          '2. Connect to "Skynet-AutoConnect" network\n'
                          '3. Return to this app and tap "Scan for Devices" below',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Once connected, we\'ll scan for available ESP devices.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          const Spacer(),

          if (!_isLoading && !_isScanning)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Start scanning for devices
                _startDeviceScan();
              },
              child: const Text(
                'Scan for Devices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isScanning)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Stop scanning
                setState(() {
                  _isScanning = false;
                });
              },
              child: const Text(
                'Stop Scanning',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = STEP_POWER_DEVICE;
                    _isScanning = false;
                  });
                },
                child: const Text('Back'),
              ),
            ),
        ],
      ),
    );
  }

  // Open WiFi settings to allow the user to connect to the device's WiFi network
  Future<void> _connectToDeviceWifi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wifiService = WiFiService();

      // Just open WiFi settings without checking current connection
      bool opened = await wifiService.connectToWifi(context, "Skynet-AutoConnect");

      if (!opened) {
        // If we couldn't open WiFi settings, show manual instructions
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not open WiFi settings. Please open your device's WiFi settings manually and connect to 'Skynet-AutoConnect'.";
        });
      } else {
        // We opened WiFi settings, now wait for the user to connect
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // If opening WiFi settings fails, show error
      setState(() {
        _isLoading = false;
        _errorMessage = "Error opening WiFi settings: ${e.toString()}";
      });
    }
  }

  // This is just a placeholder to avoid compilation errors
  // The actual implementation would be much more complex
  Future<void> _startDeviceScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final wifiService = WiFiService();

      // Check if we're connected to WiFi
      bool isWifiConnected = await wifiService.isConnectedToWifi();

      if (isWifiConnected) {
        // Simulate finding a device (since we're not implementing the full functionality)
        await Future.delayed(const Duration(seconds: 2));
        
        // Show a message that this is a placeholder
        setState(() {
          _isScanning = false;
          _errorMessage = "This is a placeholder. The full device scanning functionality will be implemented later.";
        });
      } else {
        // Not connected to WiFi, show a more prominent error and guide the user
        setState(() {
          _isScanning = false;
          _errorMessage = 'Not connected to WiFi. Please tap "Open WiFi Settings" and connect to the "Skynet-AutoConnect" network.';
        });

        // Show a dialog to make it more obvious
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("WiFi Connection Required"),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    "You are not connected to WiFi.\n\n"
                    "Please connect to the 'Skynet-AutoConnect' network in your WiFi settings before continuing.",
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _connectToDeviceWifi(); // Open WiFi settings when they tap OK
                  },
                  child: const Text("Open WiFi Settings"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Failed to scan for devices: ${e.toString()}';
      });
    }
  }
}