import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// A service to handle WiFi connection functionality
class WiFiService {
  static final WiFiService _instance = WiFiService._internal();
  static const MethodChannel _channel = MethodChannel('com.example.flutter_application_1/wifi');

  factory WiFiService() {
    return _instance;
  }

  WiFiService._internal();

  /// Check if the device is connected to WiFi
  Future<bool> isConnectedToWifi() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }

  /// Connect to a specific WiFi network
  ///
  /// On Android, this will attempt to guide the user to WiFi settings
  /// On iOS, this will show a dialog with instructions
  Future<bool> connectToWifi(BuildContext context, String ssid) async {
    if (Platform.isAndroid) {
      // On Android, we can try to open WiFi settings
      return _openAndroidWifiSettings();
    } else if (Platform.isIOS) {
      // On iOS, we need to show manual instructions
      _showIosConnectionDialog(context, ssid);
      return false;
    }
    return false;
  }

  /// Open Android WiFi settings using the Settings.Panel.ACTION_WIFI intent
  Future<bool> _openAndroidWifiSettings() async {
    if (Platform.isAndroid) {
      try {
        // Try to use the method channel to open the WiFi panel
        final bool result = await _channel.invokeMethod('openWifiSettings');
        return result;
      } catch (e) {
        // If the method channel fails, fall back to the URL launcher approaches
        return _fallbackOpenWifiSettings();
      }
    }
    return false;
  }

  /// Fallback methods to open WiFi settings if the method channel fails
  Future<bool> _fallbackOpenWifiSettings() async {
    // Try different approaches to open WiFi settings

    // First try the standard Android settings URI
    try {
      final uri = Uri.parse('android-settings://wifi');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      // Ignore and try next method
    }

    // Try the package-based approach
    try {
      final uri = Uri.parse('package:android.settings/wifi');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      // Ignore and try next method
    }

    // Try the intent-based approach
    try {
      final uri = Uri.parse('android.intent.action.MAIN');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      // Ignore and try next method
    }

    // Fallback to a more generic approach - open main settings
    try {
      final uri = Uri.parse('package:android.settings/settings');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      return false;
    }

    return false;
  }
  
  /// Show a dialog with instructions for iOS users
  void _showIosConnectionDialog(BuildContext context, String ssid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Connect to Device WiFi"),
        content: Text(
          "Please follow these steps to connect to the device:\n\n"
          "1. Go to Settings > WiFi\n"
          "2. Connect to '$ssid'\n"
          "3. Return to this app when connected"
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
  
  // We no longer need the openCaptivePortal method as we're using WebView instead
  
  /// Check if connected to the device's WiFi by making a request to the device's IP
  /// Returns true if the device is reachable, false otherwise
  Future<bool> isConnectedToDeviceWifi() async {
    // First check if connected to any WiFi
    final isConnected = await isConnectedToWifi();
    if (!isConnected) {
      return false;
    }
    
    // Try to reach the device at its IP address
    try {
      // Set a short timeout to avoid hanging the UI
      final response = await http.get(
        Uri.parse('http://192.168.4.1/'),
      ).timeout(const Duration(seconds: 3));
      
      // If we get any response, consider it a success
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      // If there's an error (timeout, connection refused, etc.), the device is not reachable
      return false;
    }
  }
}

// Simplified NetworkSecurity enum for compatibility
enum NetworkSecurity { NONE, WEP, WPA, WPA2, WPA3 }