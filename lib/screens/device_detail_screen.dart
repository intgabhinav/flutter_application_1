import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:garden_helper/models/device_data_model.dart';
import 'package:garden_helper/models/user_model.dart';
import 'package:garden_helper/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DeviceDetailScreen extends StatefulWidget {
  final DeviceModel device;

  const DeviceDetailScreen({
    super.key,
    required this.device,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final DatabaseService _database = DatabaseService();
  bool _isLoading = true;
  DeviceDataModel? _latestData;
  List<DeviceDataModel> _dataHistory = [];
  
  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }
  
  Future<void> _loadDeviceData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the latest device data and convert to DeviceDataModel
      Map<String, dynamic> latestDataMap = await _database.getLatestDeviceData(widget.device.id);
      _latestData = DeviceDataModel.fromFirestore(latestDataMap);

      // Get the device data history and convert each item to DeviceDataModel
      List<Map<String, dynamic>> historyDataList = await _database.getDeviceDataHistory(widget.device.id, limit: 20);
      _dataHistory = historyDataList.map((data) => DeviceDataModel.fromFirestore(data)).toList();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading device data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    Provider.of<User?>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDeviceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device Info Card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Device Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildStatusIndicator(widget.device.status),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('ID', widget.device.id),
                              _buildInfoRow('Name', widget.device.name),
                              _buildInfoRow('Status', widget.device.status),
                              _buildInfoRow('State', widget.device.state ? 'ON' : 'OFF'),
                              if (widget.device.lastActive != null)
                                _buildInfoRow(
                                  'Last Active',
                                  DateFormat('MMM d, yyyy HH:mm').format(widget.device.lastActive!),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Latest Data Card
                      if (_latestData != null) ...[
                        const Text(
                          'Latest Sensor Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  'Timestamp',
                                  DateFormat('MMM d, yyyy HH:mm:ss').format(_latestData!.timestamp),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Sensor Values',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._latestData!.sensorData.entries.map((entry) => 
                                  _buildSensorValueRow(entry.key, entry.value.toString())
                                ),
                                if (_latestData!.sensorData.isEmpty)
                                  const Text(
                                    'No sensor data available',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Data History
                      const Text(
                        'Data History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_dataHistory.isEmpty)
                        const Card(
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No data history available',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._dataHistory.map((data) => _buildDataHistoryItem(data)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildStatusIndicator(String status) {
    bool isOnline = status.toLowerCase() == 'online';
    Color statusColor = isOnline ? Colors.green : Colors.red;
    
    return Row(
      children: [
        // Status indicator (online/offline)
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          status,
          style: TextStyle(
            fontSize: 14,
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 20),
        // ON/OFF state toggle
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.device.state ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          widget.device.state ? 'ON' : 'OFF',
          style: TextStyle(
            fontSize: 14,
            color: widget.device.state ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        Switch(
          value: widget.device.state,
          onChanged: (value) {
            _toggleDeviceState(value);
          },
          activeColor: Colors.green,
          activeTrackColor: Colors.green.shade100,
          inactiveThumbColor: Colors.red,
          inactiveTrackColor: Colors.red.shade100,
        ),
      ],
    );
  }
  
  Future<void> _toggleDeviceState(bool isOn) async {
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await _database.setDeviceState(user.uid, widget.device.id, isOn);
        
        // Refresh the data
        await _loadDeviceData();
        
        // Show a snackbar to confirm the action
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device turned ${isOn ? 'ON' : 'OFF'}'),
              backgroundColor: isOn ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error toggling device state: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to toggle device state'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Keep the original method for backward compatibility
  Future<void> _toggleDeviceStatus(bool isOnline) async {
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await _database.updateDeviceStatus(user.uid, widget.device.id, isOnline ? 'online' : 'offline');
        
        // Refresh the data
        await _loadDeviceData();
        
        // Show a snackbar to confirm the action
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device status updated to ${isOnline ? 'online' : 'offline'}'),
              backgroundColor: isOnline ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error updating device status: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update device status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
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
      ),
    );
  }
  
  Widget _buildSensorValueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDataHistoryItem(DeviceDataModel data) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        title: Text(
          DateFormat('MMM d, yyyy HH:mm:ss').format(data.timestamp),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${data.status}',
              style: TextStyle(
                fontSize: 12,
                color: data.status.toLowerCase() == 'online' ? Colors.green : Colors.red,
              ),
            ),
            Text(
              'State: ${data.state ? 'ON' : 'OFF'}',
              style: TextStyle(
                fontSize: 12,
                color: data.state ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensor Values',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...data.sensorData.entries.map((entry) =>
                  _buildSensorValueRow(entry.key, entry.value.toString())
                ),
                if (data.sensorData.isEmpty)
                  const Text(
                    'No sensor data available',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Reported by: ${data.reportedBy}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}