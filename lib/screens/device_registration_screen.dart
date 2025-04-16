import 'package:flutter/material.dart';
import 'dart:convert';

class DeviceRegistrationScreen extends StatelessWidget {
  final String response;

  const DeviceRegistrationScreen({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    // Parse the JSON string
    String chipID = '';
    try {
      final Map<String, dynamic> jsonData = json.decode(response);
      chipID = jsonData['chipID']?.toString() ?? 'No chipID found';
    } catch (e) {
      chipID = 'Error parsing JSON: $e';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Device Registration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Chip ID:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                chipID,
                style: const TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}