import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/screens/add_device_screen.dart';
import 'package:flutter_application_1/screens/device_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/database_service.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService();
  final DatabaseService _database = DatabaseService();
  UserModel? _userModel;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    print('_fetchUserData called');
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        print('Fetching user data from database...');
        Map<String, dynamic> userData = await _database.getUserData(user);
        print('User data fetched successfully');
        
        if (userData.containsKey('devices')) {
          print('Devices in user data: ${userData['devices'].length}');
          for (var device in userData['devices']) {
            print('Device: ${device['id']}, Name: ${device['name']}, Status: ${device['status']}, State: ${device['state']}');
          }
        }
        
        setState(() {
          _userModel = userData.isNotEmpty
              ? UserModel.fromFirestore(userData)
              : UserModel(
                  uid: user.uid,
                  email: user.email ?? '',
                  displayName: user.displayName ?? 'User',
                  photoURL: user.photoURL,
                  preferences: {'theme': 'light', 'notifications': true},
                  devices: [],
                );
          
          print('UserModel updated with ${_userModel?.devices.length ?? 0} devices');
          if (_userModel != null && _userModel!.devices.isNotEmpty) {
            for (var device in _userModel!.devices) {
              print('Device in model: ${device.id}, State: ${device.state}');
            }
          }
        });
      } catch (e) {
        print('Error fetching user data: $e');
        setState(() {
          _userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? 'User',
            photoURL: user.photoURL,
            preferences: {'theme': 'light', 'notifications': true},
            devices: [],
          );
        });
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      print('User is null, cannot fetch user data');
    }
  }

  Future<void> _navigateToAddDevice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
    if (result == true) _fetchUserData();
  }

  Future<void> _updateDeviceStatus(String deviceId, String newStatus) async {
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      setState(() => _isLoading = true);
      
      try {
        await _database.updateDeviceStatus(user.uid, deviceId, newStatus);
        
        // Show a snackbar to confirm the action
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device status updated to $newStatus'),
              backgroundColor: newStatus.toLowerCase() == 'online' ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Refresh the data
        await _fetchUserData();
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
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _toggleDeviceState(String deviceId, bool newState) async {
    print('Toggling device state for $deviceId to ${newState ? 'ON' : 'OFF'}');
    
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      setState(() => _isLoading = true);
      
      try {
        print('Calling setDeviceState with uid: ${user.uid}, deviceId: $deviceId, state: $newState');
        await _database.setDeviceState(user.uid, deviceId, newState);
        print('Successfully updated device state in Firestore');
        
        // Show a snackbar to confirm the action
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device turned ${newState ? 'ON' : 'OFF'}'),
              backgroundColor: newState ? Colors.green : Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Refresh the data
        print('Refreshing user data after state update');
        await _fetchUserData();
        print('User data refreshed successfully');
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
        setState(() => _isLoading = false);
      }
    } else {
      print('User is null, cannot toggle device state');
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Device'),
          content: const Text('Are you sure you want to remove this device?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
          ],
        ),
      );

      if (confirmed == true) {
        await _database.deleteDeviceCompletely(user.uid, deviceId);
        _fetchUserData();
      }
    }
  }

  void _navigateToDeviceDetail(DeviceModel device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeviceDetailScreen(device: device)),
    ).then((_) => _fetchUserData());
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
            onPressed: () async => await _auth.signOut(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddDevice,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome, ${_userModel?.displayName ?? 'User'}!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  if (_userModel?.createdAt != null)
                    Text('Account created: ${_formatDate(_userModel!.createdAt!)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  if (_userModel?.lastLogin != null)
                    Text('Last login: ${_formatDate(_userModel!.lastLogin!)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 30),

                  // Devices Section
                  _buildDevicesSection(),

                  const SizedBox(height: 30),

                  // Preferences
                  _buildPreferencesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildDevicesSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Devices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (_userModel != null && _userModel!.hasDevices)
                Text('${_userModel!.devices.length} device(s)', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 15),
          if (_userModel == null || !_userModel!.hasDevices)
            _buildNoDevicesMessage()
          else
            ..._userModel!.devices.map(_buildDeviceItem).toList(),
        ]),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('User Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            if (_userModel != null) ...[
              _buildPreferenceItem('Theme', _userModel!.preferences['theme'] ?? 'light'),
              _buildPreferenceItem(
                'Notifications',
                (_userModel!.preferences['notifications'] ?? true) ? 'Enabled' : 'Disabled',
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(DeviceModel device) {
    Color statusColor;
    switch (device.status.toLowerCase()) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => _navigateToDeviceDetail(device),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                  child: Row(children: [
                    const Icon(Icons.devices, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        device.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      _removeDevice(device.id);
                    } else if (value.startsWith('status_')) {
                      _updateDeviceStatus(device.id, value.substring(7));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'status_online', child: Text('Set Online')),
                    const PopupMenuItem(value: 'status_offline', child: Text('Set Offline')),
                    const PopupMenuItem(value: 'status_error', child: Text('Set Error')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'remove', child: Text('Remove Device')),
                  ],
                ),
              ]),
              const SizedBox(height: 10),
              // Device ID
              Text(
                'Device ID: ${device.id.length > 8 ? device.id.substring(0, 8) + '...' : device.id}',
                style: const TextStyle(fontSize: 14, color: Colors.grey)
              ),
              const SizedBox(height: 8),
              
              // Status and State Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status indicator (online/offline)
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: device.status.toLowerCase() == 'online' ? Colors.green : Colors.red,
                          shape: BoxShape.circle
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Status: ${device.status}',
                        style: TextStyle(
                          fontSize: 14, 
                          color: device.status.toLowerCase() == 'online' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ],
                  ),
                  
                  // ON/OFF state toggle with switch
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: device.state ? Colors.green : Colors.red,
                          shape: BoxShape.circle
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        device.state ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 14, 
                          color: device.state ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold
                        )
                      ),
                      const SizedBox(width: 5),
                      Switch(
                        value: device.state,
                        onChanged: (value) {
                          _toggleDeviceState(device.id, value);
                        },
                        activeColor: Colors.green,
                        activeTrackColor: Colors.green.shade100,
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.red.shade100,
                        // Make the switch smaller to fit better
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
              if (device.lastActive != null) ...[
                const SizedBox(height: 5),
                Text('Last active: ${_formatDate(device.lastActive!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDevicesMessage() {
    return Column(children: [
      const Icon(Icons.devices, size: 60, color: Colors.grey),
      const SizedBox(height: 15),
      const Text('No devices found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      const Text("You haven't added any devices yet.",
          style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _navigateToAddDevice,
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ]);
  }

  Widget _buildPreferenceItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
