import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference devicesCollection = FirebaseFirestore.instance.collection('devices');

  Future<bool> addDevice(String uid, String deviceId, String deviceName) async {
    try {
      print('Adding new device: $deviceId, $deviceName');
      // First, add the device to the devices collection
      await devicesCollection.doc(deviceId).set({
        'deviceId': deviceId,
        'name': deviceName,
        'ownerId': uid,
        'status': 'active',
        'state': false,  // Default to OFF
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'type': 'default',
        'settings': {},
      });
      
      // Verify the device was added with the state field
      DocumentSnapshot deviceDoc = await devicesCollection.doc(deviceId).get();
      if (deviceDoc.exists) {
        Map<String, dynamic> data = deviceDoc.data() as Map<String, dynamic>;
        print('Device added successfully with state: ${data['state']}');
      }

      // Then, add only the device ID to the user's devices list
      DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        List<dynamic> devices = [];
        if (userData.containsKey('devices') && userData['devices'] is List) {
          devices = userData['devices'] as List<dynamic>;
        }

        // Add only the device ID
        devices.add(deviceId);

        await usersCollection.doc(uid).update({
          'devices': devices,
        });

        print('Device added successfully: $deviceId - $deviceName');
        return true;
      } else {
        print('User not found, cannot add device');
        // Try to delete the device document since we couldn't add it to the user
        await devicesCollection.doc(deviceId).delete();
        return false;
      }
    } catch (e) {
      print('Error adding device: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserData(User user) async {
    try {
      DocumentSnapshot userDoc = await usersCollection.doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        // Fetch the full device details for each device ID
        List<Map<String, dynamic>> deviceDetails = await getUserDevices(user.uid);

        // Replace the devices array with the full device details
        userData['devices'] = deviceDetails;

        return userData;
      } else {
        // Create a new user document if it doesn't exist
        Map<String, dynamic> userData = {
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? 'User',
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'preferences': {'theme': 'light', 'notifications': true},
          'devices': [],
        };

        await usersCollection.doc(user.uid).set(userData);
        return userData;
      }
    } catch (e) {
      print('Error getting user data: $e');
      // Return an empty map instead of null
      return {};
    }
  }

  Future<void> updateDeviceStatus(String uid, String deviceId, String newStatus) async {
    try {
      // Update status only in the devices collection
      await devicesCollection.doc(deviceId).update({
        'status': newStatus,
        'lastActive': FieldValue.serverTimestamp(),
      });

      print('Device status updated to $newStatus for device: $deviceId');
    } catch (e) {
      print('Error updating device status: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }
  
  // Method to update the device state (ON/OFF)
  Future<void> setDeviceState(String uid, String deviceId, bool isOn) async {
    print('DatabaseService.setDeviceState called with uid: $uid, deviceId: $deviceId, isOn: $isOn');
    try {
      // First check if the document exists
      DocumentSnapshot deviceDoc = await devicesCollection.doc(deviceId).get();
      if (!deviceDoc.exists) {
        print('Error: Device document does not exist: $deviceId');
        throw Exception('Device document does not exist');
      }
      
      print('Updating device state in Firestore...');
      // Update the state field (boolean for on/off)
      await devicesCollection.doc(deviceId).update({
        'state': isOn,
        'lastActive': FieldValue.serverTimestamp(),
      });

      print('Device state updated to ${isOn ? "ON" : "OFF"} for device: $deviceId');
      
      // Verify the update
      DocumentSnapshot updatedDoc = await devicesCollection.doc(deviceId).get();
      Map<String, dynamic> data = updatedDoc.data() as Map<String, dynamic>;
      print('Verified state after update: ${data['state']}');
    } catch (e) {
      print('Error updating device state: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  Future<void> deleteDeviceCompletely(String uid, String deviceId) async {
    try {
      // Delete from devices collection
      await devicesCollection.doc(deviceId).delete();

      // Remove device ID from user's devices list
      DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData.containsKey('devices') && userData['devices'] is List) {
          List<dynamic> devices = userData['devices'] as List<dynamic>;

          // Remove the device ID from the list
          devices.remove(deviceId);

          await usersCollection.doc(uid).update({
            'devices': devices,
          });
        }
      }

      print('Device deleted successfully: $deviceId');
    } catch (e) {
      print('Error deleting device: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }

  Future<Map<String, dynamic>> getLatestDeviceData(String deviceId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('device_data')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting latest device data: $e');
    }

    // Return default data if no data is found or an error occurs
    return {
      'deviceId': deviceId,
      'sensorData': {},
      'timestamp': Timestamp.now(),
      'status': 'unknown',
      'state': false,  // Include the state field with default value
      'reportedBy': '',
    };
  }

  Future<List<Map<String, dynamic>>> getDeviceDataHistory(String deviceId, {int limit = 20}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('device_data')
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error getting device data history: $e');
    }

    // Return an empty list if no data is found or an error occurs
    return [];
  }

  // Get device details from the devices collection
  Future<Map<String, dynamic>> getDeviceDetails(String deviceId) async {
    print('Getting device details for deviceId: $deviceId');
    try {
      DocumentSnapshot deviceDoc = await devicesCollection.doc(deviceId).get();

      if (deviceDoc.exists && deviceDoc.data() != null) {
        Map<String, dynamic> deviceData = deviceDoc.data() as Map<String, dynamic>;
        print('Device document found: $deviceId');
        print('Raw device data: $deviceData');
        
        // Check if state field exists
        if (deviceData.containsKey('state')) {
          print('State field exists with value: ${deviceData['state']}');
        } else {
          print('State field does not exist in the document');
        }

        // Ensure the data has the expected format for DeviceModel
        Map<String, dynamic> formattedData = {
          'id': deviceId,
          'name': deviceData['name'] ?? 'Unknown Device',
          'status': deviceData['status'] ?? 'offline',
          'state': deviceData['state'] ?? false,  // Include the state field
          'lastActive': deviceData['lastActive'],
          'settings': deviceData['settings'] ?? {},
          'type': deviceData['type'] ?? 'default',
          'createdAt': deviceData['createdAt'],
        };
        
        print('Formatted device data: $formattedData');
        return formattedData;
      } else {
        print('Device document not found: $deviceId');
      }
    } catch (e) {
      print('Error getting device details: $e');
    }

    print('Returning default device data for: $deviceId');
    // Return default data if device not found or error occurs
    return {
      'id': deviceId,
      'name': 'Unknown Device',
      'status': 'offline',
      'state': false,  // Include the state field with default value
      'settings': {},
    };
  }

  // Get all devices for a user by fetching each device from the devices collection
  Future<List<Map<String, dynamic>>> getUserDevices(String uid) async {
    try {
      // First get the user document to get the list of device IDs
      DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData.containsKey('devices') && userData['devices'] is List) {
          List<dynamic> deviceIds = userData['devices'] as List<dynamic>;
          List<Map<String, dynamic>> devices = [];

          // Fetch each device's details
          for (String deviceId in deviceIds) {
            Map<String, dynamic> deviceData = await getDeviceDetails(deviceId);
            devices.add(deviceData);
          }

          return devices;
        }
      }
    } catch (e) {
      print('Error getting user devices: $e');
    }

    // Return an empty list if no devices found or error occurs
    return [];
  }
  
  // Register a new device with the given chip ID and name
  Future<bool> registerDevice(User user, String chipId, String deviceName) async {
    try {
      print('Registering new device: $chipId, $deviceName for user: ${user.uid}');
      
      // Check if the device already exists
      DocumentSnapshot deviceDoc = await devicesCollection.doc(chipId).get();
      if (deviceDoc.exists) {
        print('Device already exists with ID: $chipId');
        
        // Check if it's already assigned to this user
        Map<String, dynamic> deviceData = deviceDoc.data() as Map<String, dynamic>;
        
        // If the device is already assigned to this user, return success
        if (deviceData['ownerId'] == user.uid) {
          print('Device already registered to this user');
          return true;
        } 
        // If the device has no owner (ownerId is empty or null), allow this user to claim it
        else if (deviceData['ownerId'] == null || deviceData['ownerId'] == '') {
          print('Device exists but has no owner, claiming it for this user');
          
          // Update the device with the new owner
          await devicesCollection.doc(chipId).update({
            'ownerId': user.uid,
            'name': deviceName,
            'lastActive': FieldValue.serverTimestamp(),
          });
          
          // Add the device ID to the user's devices list
          DocumentSnapshot userDoc = await usersCollection.doc(user.uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            
            List<dynamic> devices = [];
            if (userData.containsKey('devices') && userData['devices'] is List) {
              devices = userData['devices'] as List<dynamic>;
            }
            
            // Add the device ID if it's not already in the list
            if (!devices.contains(chipId)) {
              devices.add(chipId);
              await usersCollection.doc(user.uid).update({
                'devices': devices,
              });
            }
            
            print('Device claimed successfully: $chipId - $deviceName');
            return true;
          } else {
            print('User not found, cannot claim device');
            return false;
          }
        } 
        // If the device is assigned to another user, throw an exception
        else {
          print('Device already registered to another user');
          throw Exception('This device is already registered to another account');
        }
      }
      
      // If the device doesn't exist, add it using the existing addDevice method
      //return await addDevice(user.uid, chipId, deviceName);
    } catch (e) {
      print('Error registering device: $e');
      rethrow; // Re-throw to handle in the UI
    }
  }
}
