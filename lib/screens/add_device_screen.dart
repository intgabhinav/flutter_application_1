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

  // Step 3: Device found
  Widget _buildDeviceFoundStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          const Text(
            'ESP Device Found!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'We found the following ESP device:',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.memory, color: Colors.blue, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _foundDevice?['model'] ?? 'ESP Device',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chip ID: ${_foundDevice?['chipId'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Configuration Complete',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your device has been successfully configured and is ready to be registered to your account.',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
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
              setState(() {
                _currentStep = STEP_NAMING_DEVICE;
                // Pre-fill the device name with a default name including the chip ID
                final chipId = (_foundDevice?['chipId'] ?? '').toString();
                _deviceNameController.text = chipId.isNotEmpty 
                    ? 'ESP Device (${chipId.substring(0, min(6, chipId.length))})'
                    : 'ESP Device';
              });
            },
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = STEP_SEARCHING;
                // Try connecting again
                _openCaptivePortal();
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Step 4: Name the device
  Widget _buildNamingDeviceStep(User? user, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Name Your Device',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'Give your device a name to easily identify it.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a device name';
                }
                return null;
              },
              onChanged: (value) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
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
            onPressed: () => _registerDevice(user?.uid),
            child: const Text(
              'Register Device',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep = STEP_DEVICE_FOUND;
              });
            },
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  // Step 5: Registration complete
  Widget _buildCompleteStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          const Text(
            'Device Registered!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Your device "${_deviceNameController.text}" has been successfully registered and is now ready to use.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.tips_and_updates, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text(
                    'Next Steps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your device is now connected to your account. You can monitor and control it from the devices dashboard.',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
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
              Navigator.pop(context, true); // Return to previous screen
            },
            child: const Text(
              'Go to Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                // Reset the flow to add another device
                _currentStep = STEP_POWER_DEVICE;
                _deviceNameController.clear();
                _foundDevice = null;
              });
            },
            child: const Text('Add Another Device'),
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

  // Get the chip ID from the ESP device
  Future<String?> _getChipId() async {
    try {
      // Set a timeout for the HTTP request
      final response = await http.get(Uri.parse('http://192.168.4.1/cid'))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Return the chip ID from the response, ensuring it's a valid string
        final chipId = response.body.trim();
        if (chipId.isNotEmpty) {
          return chipId;
        } else {
          debugPrint('Empty chip ID received');
          return 'ESP-${DateTime.now().millisecondsSinceEpoch % 10000}';
        }
      } else {
        debugPrint('Failed to get chip ID: ${response.statusCode}');
        // Generate a fallback ID if we can't get the real one
        return 'ESP-${DateTime.now().millisecondsSinceEpoch % 10000}';
      }
    } on TimeoutException {
      debugPrint('Timeout getting chip ID');
      return 'ESP-${DateTime.now().millisecondsSinceEpoch % 10000}';
    } catch (e) {
      debugPrint('Error getting chip ID: $e');
      return 'ESP-${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
  }

  // Start scanning for ESP devices
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
        // First, try to get the chip ID from the device
        final chipId = await _getChipId();
        
        if (chipId == null) {
          setState(() {
            _isScanning = false;
            _errorMessage = 'Could not find any ESP devices. Make sure you are connected to the correct WiFi network.';
          });
          return;
        }
        
        // We found a device, create the device object
        final device = {
          'id': chipId,
          'model': 'ESP Device',
          'type': 'esp',
          'chipId': chipId,
        };
        
        // Set the found device and proceed to setup
        _foundDevice = device;
        _openDeviceSetup(_foundDevice!);
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
  
  // Open the device setup process for a specific device
  Future<void> _openDeviceSetup(Map<String, dynamic> device) async {
    setState(() {
      _isLoading = true;
      _isScanning = false;
    });
    
    // Show a dialog with the device info
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Device Found"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text("ESP Device detected!"),
              const SizedBox(height: 10),
              Text("Chip ID: ${device['chipId']}"),
              const SizedBox(height: 10),
              const Text("Opening configuration page..."),
            ],
          ),
        ),
      );
      
      // Wait a moment to show the dialog before proceeding
      await Future.delayed(const Duration(seconds: 2));
      
      // Dismiss the dialog if it's still showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    // Open the captive portal in a WebView
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      // Navigate to the captive portal screen
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CaptivePortalScreen(
            url: 'http://192.168.4.1',
            onSetupComplete: () {
              // When setup is complete, pop the screen and return true
              Navigator.of(context).pop(true);
            },
          ),
        ),
      );

      // If the result is true, it means setup was completed successfully
      if (result == true) {
        setState(() {
          _currentStep = STEP_DEVICE_FOUND;
        });
      }
    }
  }
  
  // Legacy method for backward compatibility
  Future<void> _openCaptivePortal() async {
    // Start the device scan instead
    await _startDeviceScan();
  }

  Future<void> _registerDevice(String? uid) async {
    if (uid == null) {
      setState(() {
        _errorMessage = 'You must be logged in to register a device';
      });
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _currentStep = STEP_REGISTERING;
        _errorMessage = null;
      });

      try {
        // Get the device name from the controller
        final deviceName = _deviceNameController.text.trim();

        // Use the found device ID or generate a new one
        final deviceId = _foundDevice?['id'] ?? const Uuid().v4();

        // Add the device to both the devices collection and the user's account
        final success = await _database.addDevice(uid, deviceId, deviceName);

        if (success) {
          // Move to the completion step
          setState(() {
            _currentStep = STEP_COMPLETE;
          });
        } else {
          setState(() {
            _currentStep = STEP_NAMING_DEVICE;
            _errorMessage = 'Failed to register device. Please try again.';
          });
        }
      } catch (e) {
        setState(() {
          _currentStep = STEP_NAMING_DEVICE;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }
}

