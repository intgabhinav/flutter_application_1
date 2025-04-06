import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference devicesCollection = FirebaseFirestore.instance.collection('devices');

  Future<bool> addDevice(String uid, String deviceId) async {
    try {
      DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        List<dynamic> devices = [];
        if (userData.containsKey('devices') && userData['devices'] is List) {
          devices = userData['devices'] as List<dynamic>;
        }

        devices.add(deviceId);

        await usersCollection.doc(uid).update({
          'devices': devices,
        });

        print('Device ID added successfully: $deviceId');
        return true;
      } else {
        print('User not found, cannot add device ID');
        return false;
      }
    } catch (e) {
      print('Error adding device ID: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserData(User user) async {
    try {
      DocumentSnapshot userDoc = await usersCollection.doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data() as Map<String, dynamic>;
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
      DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData.containsKey('devices') && userData['devices'] is List) {
          List<dynamic> devices = userData['devices'] as List<dynamic>;

          for (int i = 0; i < devices.length; i++) {
            if (devices[i] is Map && devices[i]['id'] == deviceId) {
              devices[i]['status'] = newStatus;
              devices[i]['lastActive'] = FieldValue.serverTimestamp();
              break;
            }
          }

          await usersCollection.doc(uid).update({
            'devices': devices,
          });
        }
      }
    } catch (e) {
      print('Error updating device status: $e');
    }
  }

  Future<void> deleteDeviceCompletely(String uid, String deviceId) async {
    try {
      DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        if (userData.containsKey('devices') && userData['devices'] is List) {
          List<dynamic> devices = userData['devices'] as List<dynamic>;

          devices.removeWhere((device) =>
            device is Map && device['id'] == deviceId
          );

          await usersCollection.doc(uid).update({
            'devices': devices,
          });
        }
      }
    } catch (e) {
      print('Error deleting device: $e');
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
}
