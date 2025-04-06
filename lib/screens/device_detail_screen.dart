import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/device_data_model.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/services/database_service.dart';
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
                                ).toList(),
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
                        ..._dataHistory.map((data) => _buildDataHistoryItem(data)).toList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildStatusIndicator(String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'online':
        statusColor = Colors.green;
        break;
      case 'offline':
        statusColor = Colors.grey;
        break;
      case 'error':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }
    
    return Row(
      children: [
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
      ],
    );
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
        subtitle: Text(
          'Status: ${data.status}',
          style: TextStyle(
            fontSize: 12,
            color: data.status.toLowerCase() == 'online' ? Colors.green : Colors.grey,
          ),
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
                ).toList(),
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