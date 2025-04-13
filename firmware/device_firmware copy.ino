#include <ESP8266WiFi.h>
#include <DNSServer.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>      // For JSON parsing
#include <EEPROM.h>
#include <Firebase_ESP_Client.h>  // New Firebase library with Firestore support
#include <time.h>             // For time functions
#include <addons/TokenHelper.h>  // Firebase token generation helper
#include <addons/RTDBHelper.h>   // RTDB helper functions

// Constants
#define SWITCH_PIN 5
#define CONFIG_MODE_TIMEOUT 300000  // 5 minutes in milliseconds
#define EEPROM_SIZE 512
#define EEPROM_WIFI_SSID_ADDR 0
#define EEPROM_WIFI_PASS_ADDR 32
#define EEPROM_API_KEY_ADDR 96
#define EEPROM_DEVICE_NAME_ADDR 160
#define EEPROM_DEVICE_ID_ADDR 224  // Store device ID
#define EEPROM_CONFIG_FLAG_ADDR 288  // Flag to indicate if device is configured

// Firebase configuration
#define API_KEY "AIzaSyDwyL3PbGnr5ZwYz-GadsMzIKXy6FMxa7g"  // Replace with your Firebase API Key
#define PROJECT_ID "thegardenhelper-35b52"  // Replace with your Firebase Project ID
#define USER_EMAIL "master@skynet.com"  // Replace with your Firebase Auth email
#define USER_PASSWORD "password"  // Replace with your Firebase Auth password

// Variables
bool isConfigured = false;
char deviceName[32] = "";
char deviceId[40] = "";  // Store device ID instead of API key
char wifiSSID[32] = "";
char wifiPassword[32] = "";
unsigned long setupModeStartTime = 0;
bool currentState = false;  // Current state of the switch (ON/OFF)
unsigned long lastStateCheckTime = 0;
const unsigned long STATE_CHECK_INTERVAL = 5000;  // Check state every 5 seconds

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseJson content;

// DNS Server for captive portal
const byte DNS_PORT = 53;
DNSServer dnsServer;

// Web server for configuration portal
ESP8266WebServer webServer(80);

void setup() {
  Serial.begin(115200);
  pinMode(SWITCH_PIN, OUTPUT);
  digitalWrite(SWITCH_PIN, LOW);  // Initialize switch to OFF
  
  // Initialize EEPROM
  EEPROM.begin(EEPROM_SIZE);
  
  // Check if device is already configured
  isConfigured = (EEPROM.read(EEPROM_CONFIG_FLAG_ADDR) == 1);
  
  if (isConfigured) {
    // Read configuration from EEPROM
    readConfigFromEEPROM();
    
    // Try to connect to WiFi
    if (connectToWiFi()) {
      Serial.println("Connected to WiFi, entering normal operation mode");
      
      // Initialize Firebase
      config.api_key = API_KEY;
      config.service_account.data.project_id = PROJECT_ID;
      
      // Configure authentication
      auth.user.email = USER_EMAIL;
      auth.user.password = USER_PASSWORD;
      
      // Assign the callback function for the long running token generation task
      config.token_status_callback = tokenStatusCallback; // This function is defined in TokenHelper.h
      
      // Initialize Firebase with authentication
      Firebase.begin(&config, &auth);
      Firebase.reconnectWiFi(true);
      
      // Sign in to Firebase
      Serial.println("Signing in to Firebase...");
      
      // Verify sign in
      Serial.println("Getting user UID...");
      while (auth.token.uid == "") {
        Serial.print(".");
        delay(1000);
      }
      
      // Print successful authentication
      Serial.println();
      Serial.print("User UID: ");
      Serial.println(auth.token.uid.c_str());
      
      // Note: Timeout settings are handled internally by the library in this version
      
      // Configure time
      configTime(0, 0, "pool.ntp.org", "time.nist.gov");
      Serial.println("Waiting for time sync...");
      while (time(nullptr) < 1510644967) {
        delay(100);
        Serial.print(".");
      }
      Serial.println("\nTime synchronized!");
      
      normalOperationMode();
      return;
    } else {
      Serial.println("Failed to connect to saved WiFi, entering setup mode");
      isConfigured = false;
    }
  }
  
  // Enter setup mode
  setupMode();
}

void loop() {
  // This will only run if we're in setup mode
  dnsServer.processNextRequest();
  webServer.handleClient();
  
  // Check if setup mode has timed out
  if (millis() - setupModeStartTime > CONFIG_MODE_TIMEOUT) {
    Serial.println("Setup mode timed out, restarting device");
    ESP.restart();
  }
}

void setupMode() {
  Serial.println("Entering setup mode");
  setupModeStartTime = millis();
  
  // Create unique AP name
  String apName = "SkyNet-AutoConnect";
  
  // Start AP
  WiFi.mode(WIFI_AP);
  WiFi.softAP(apName.c_str());
  
  // Configure DNS server to redirect all requests to the ESP
  IPAddress apIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(apIP);
  dnsServer.start(DNS_PORT, "*", apIP);
  
  // Setup web server
  webServer.on("/", handleRoot);
  webServer.on("/configure", handleConfigure);
  webServer.on("/cid", handleCID);
  webServer.onNotFound(handleRoot);
  webServer.begin();
  
  Serial.println("Setup mode active. Connect to WiFi: " + apName);
  
  // Blink LED to indicate setup mode
  for (int i = 0; i < 5; i++) {
    digitalWrite(SWITCH_PIN, HIGH);
    delay(100);
    digitalWrite(SWITCH_PIN, LOW);
    delay(100);
  }
}

void handleCID() {
  String wifiMAC = WiFi.macAddress();
  String cID = String(ESP.getChipId()).c_str();
  webServer.send(200, "text/html", cID);
}

void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>body{font-family:Arial;margin:0;padding:20px;text-align:center;}";
  html += "input,select{width:100%;padding:10px;margin:10px 0;box-sizing:border-box;}";
  html += "button{background-color:#4CAF50;color:white;padding:10px;border:none;cursor:pointer;width:100%;}";
  html += "</style></head><body>";
  html += "<h1>Switch Setup</h1>";
  html += "<form action='/configure' method='post'>";
  html += "<label for='ssid'>WiFi Network:</label><br>";
  html += "<select id='ssid' name='ssid' required>";
  
  // Scan for networks
  int n = WiFi.scanNetworks();
  for (int i = 0; i < n; ++i) {
    html += "<option value='" + WiFi.SSID(i) + "'>" + WiFi.SSID(i) + " (" + WiFi.RSSI(i) + "dBm)</option>";
  }
  
  html += "</select><br>";
  html += "<label for='password'>WiFi Password:</label><br>";
  html += "<input type='password' id='password' name='password' required><br>";
  html += "<label for='deviceName'>Device Name (optional):</label><br>";
  html += "<input type='text' id='deviceName' name='deviceName' placeholder='Kitchen Switch'><br>";
  html += "<label for='deviceId'>Device ID:</label><br>";
  html += "<input type='text' id='deviceId' name='deviceId' value='" + String(ESP.getChipId()) + "' readonly><br>";
  html += "<button type='submit'>Configure Device</button>";
  html += "</form></body></html>";
  
  webServer.send(200, "text/html", html);
}

void handleConfigure() {
  if (webServer.method() != HTTP_POST) {
    webServer.send(405, "text/plain", "Method Not Allowed");
    return;
  }
  
  String ssid = webServer.arg("ssid");
  String password = webServer.arg("password");
  String name = webServer.arg("deviceName");
  String id = webServer.arg("deviceId");
  
  if (ssid.length() == 0 || password.length() == 0 || id.length() == 0) {
    webServer.send(400, "text/plain", "Missing required fields");
    return;
  }
  
  // Store WiFi credentials and device info
  ssid.toCharArray(wifiSSID, sizeof(wifiSSID));
  password.toCharArray(wifiPassword, sizeof(wifiPassword));
  id.toCharArray(deviceId, sizeof(deviceId));
  
  if (name.length() > 0) {
    name.toCharArray(deviceName, sizeof(deviceName));
  } else {
    String defaultName = "Switch_" + id;
    defaultName.toCharArray(deviceName, sizeof(deviceName));
  }
  
  // Send confirmation page
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>body{font-family:Arial;margin:0;padding:20px;text-align:center;}";
  html += ".loader{border:16px solid #f3f3f3;border-top:16px solid #3498db;border-radius:50%;width:120px;height:120px;";
  html += "animation:spin 2s linear infinite;margin:0 auto;}";
  html += "@keyframes spin{0%{transform:rotate(0deg);}100%{transform:rotate(360deg);}}";
  html += "</style>";
  html += "<script>setTimeout(function(){document.getElementById('status').innerHTML='Device is connecting to your WiFi network.<br>You can now close this page and connect back to your regular WiFi network.';},3000);</script>";
  html += "</head><body>";
  html += "<h1>Device Configuration</h1>";
  html += "<div class='loader'></div>";
  html += "<p id='status'>Saving configuration...</p>";
  html += "</body></html>";
  
  webServer.send(202, "text/html", html);
  
  // Wait a moment for the response to be sent
  delay(1000);
  
  // Try to connect to the provided WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID, wifiPassword);
  
  Serial.println("Connecting to WiFi...");
  
  // Wait up to 30 seconds for connection
  int timeout = 30;
  while (WiFi.status() != WL_CONNECTED && timeout > 0) {
    delay(1000);
    Serial.print(".");
    timeout--;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("Connected to WiFi!");
    
    // Save configuration to EEPROM
    saveConfigToEEPROM();
    
    // Set configured flag
    EEPROM.write(EEPROM_CONFIG_FLAG_ADDR, 1);
    EEPROM.commit();
    
    isConfigured = true;
    
    // Wait a moment before restarting
    delay(2000);
    ESP.restart();
  } else {
    Serial.println("Failed to connect to WiFi");
    // We'll continue in setup mode
  }
}

void saveConfigToEEPROM() {
  // Save WiFi credentials
  for (int i = 0; i < sizeof(wifiSSID); i++) {
    EEPROM.write(EEPROM_WIFI_SSID_ADDR + i, wifiSSID[i]);
  }
  
  for (int i = 0; i < sizeof(wifiPassword); i++) {
    EEPROM.write(EEPROM_WIFI_PASS_ADDR + i, wifiPassword[i]);
  }
  
  // Save device ID
  for (int i = 0; i < sizeof(deviceId); i++) {
    EEPROM.write(EEPROM_DEVICE_ID_ADDR + i, deviceId[i]);
  }
  
  // Save device name
  for (int i = 0; i < sizeof(deviceName); i++) {
    EEPROM.write(EEPROM_DEVICE_NAME_ADDR + i, deviceName[i]);
  }
  
  EEPROM.commit();
  Serial.println("Configuration saved to EEPROM");
}

void readConfigFromEEPROM() {
  // Read WiFi credentials
  for (int i = 0; i < sizeof(wifiSSID); i++) {
    wifiSSID[i] = EEPROM.read(EEPROM_WIFI_SSID_ADDR + i);
  }
  
  for (int i = 0; i < sizeof(wifiPassword); i++) {
    wifiPassword[i] = EEPROM.read(EEPROM_WIFI_PASS_ADDR + i);
  }
  
  // Read device ID
  for (int i = 0; i < sizeof(deviceId); i++) {
    deviceId[i] = EEPROM.read(EEPROM_DEVICE_ID_ADDR + i);
  }
  
  // Read device name
  for (int i = 0; i < sizeof(deviceName); i++) {
    deviceName[i] = EEPROM.read(EEPROM_DEVICE_NAME_ADDR + i);
  }
  
  Serial.println("Configuration loaded from EEPROM");
  Serial.print("SSID: ");
  Serial.println(wifiSSID);
  Serial.print("Device Name: ");
  Serial.println(deviceName);
  Serial.print("Device ID: ");
  Serial.println(deviceId);
}

bool connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID, wifiPassword);
  
  Serial.print("Connecting to WiFi...");
  
  // Wait up to 20 seconds for connection
  int timeout = 20;
  while (WiFi.status() != WL_CONNECTED && timeout > 0) {
    delay(1000);
    Serial.print(".");
    timeout--;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("Connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    return true;
  } else {
    Serial.println("Failed to connect");
    return false;
  }
}

void normalOperationMode() {
  Serial.println("Entering normal operation mode");
  
  // Initial state check
  checkDeviceState();
  
  // Main operation loop
  while (true) {
    // Check WiFi connection and reconnect if needed
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi connection lost, reconnecting...");
      connectToWiFi();
    }
    
    // Check for device state changes in Firebase
    unsigned long currentMillis = millis();
    if (currentMillis - lastStateCheckTime >= STATE_CHECK_INTERVAL) {
      lastStateCheckTime = currentMillis;
      checkDeviceState();
    }
    
    // Send status update periodically (every 30 seconds)
    static unsigned long lastStatusUpdateTime = 0;
    if (currentMillis - lastStatusUpdateTime >= 30000) {
      lastStatusUpdateTime = currentMillis;
      sendStatusUpdate();
    }
    
    // Allow the ESP to handle other tasks
    yield();
  }
}

void checkDeviceState() {
  Serial.println("Checking device state in Firestore...");
  
  // Document path in Firestore
  String documentPath = "devices/" + String(deviceId);
  
  // Check if Firebase is ready
  if (Firebase.ready()) {
    // Get the document from Firestore
    if (Firebase.Firestore.getDocument(&fbdo, PROJECT_ID, "", documentPath, "")) {
      Serial.println("Got document from Firestore");
      
      // Parse the JSON response
      FirebaseJson payload;
      payload.setJsonData(fbdo.payload().c_str());
      
      // Extract the state field
      FirebaseJsonData result;
      payload.get(result, "fields/state/booleanValue");
      
      if (result.success) {
        // Convert the string "true" or "false" to a boolean
        bool newState = (result.stringValue == "true");
        Serial.print("Current state in Firestore: ");
        Serial.println(newState ? "ON" : "OFF");
        
        // Update the switch if state has changed
        if (newState != currentState) {
          currentState = newState;
          updateSwitchState();
        }
      } else {
        Serial.println("Document doesn't have a state field, creating it...");
        createInitialDocument();
      }
    } else {
      Serial.print("Failed to get document from Firestore: ");
      Serial.println(fbdo.errorReason());
      
      // If document doesn't exist, create it
      if (fbdo.errorReason().indexOf("NOT_FOUND") >= 0) {
        Serial.println("Document not found, creating it...");
        createInitialDocument();
      }
    }
  } else {
    Serial.println("Firebase is not ready, waiting for authentication...");
    delay(1000);
  }
}

void createInitialDocument() {
  Serial.println("Creating initial device document in Firestore...");
  
  // Document path in Firestore
  String documentPath = "devices/" + String(deviceId);
  
  // Create the document data
  content.clear();
  content.set("fields/state/booleanValue", false);
  content.set("fields/status/stringValue", "online");
  content.set("fields/ipAddress/stringValue", WiFi.localIP().toString());
  content.set("fields/lastActive/integerValue", String(time(nullptr)));
  content.set("fields/name/stringValue", String(deviceName));
  
  if (Firebase.Firestore.createDocument(&fbdo, PROJECT_ID, "", documentPath, content.raw())) {
    Serial.println("Initial document created successfully");
    currentState = false;
    updateSwitchState();
  } else {
    Serial.print("Failed to create initial document: ");
    Serial.println(fbdo.errorReason());
  }
}

void updateSwitchState() {
  Serial.print("Updating switch to: ");
  Serial.println(currentState ? "ON" : "OFF");
  
  // Set the pin HIGH or LOW based on the state
  digitalWrite(SWITCH_PIN, currentState ? HIGH : LOW);
}

void sendStatusUpdate() {
  Serial.println("Sending status update to Firestore...");
  
  // Check if Firebase is ready (token is valid)
  if (!Firebase.ready()) {
    Serial.println("Firebase is not ready, waiting for token refresh...");
    delay(1000);
    return;
  }
  
  // Document path in Firestore
  String documentPath = "devices/" + String(deviceId);
  
  // Get current time in seconds since epoch
  unsigned long currentTime = time(nullptr);
  
  // Create the document data
  content.clear();
  content.set("fields/state/booleanValue", currentState);
  content.set("fields/status/stringValue", "online");
  content.set("fields/ipAddress/stringValue", WiFi.localIP().toString());
  content.set("fields/lastActive/integerValue", String(currentTime));
  
  // Define the update mask for the fields we want to update
  String updateMask = "state,status,ipAddress,lastActive";
  
  if (Firebase.Firestore.patchDocument(&fbdo, PROJECT_ID, "", documentPath, content.raw(), updateMask)) {
    Serial.println("Status update sent successfully to Firestore");
  } else {
    Serial.print("Failed to update status in Firestore: ");
    Serial.println(fbdo.errorReason());
    
    // If document doesn't exist, create it
    if (fbdo.errorReason().indexOf("NOT_FOUND") >= 0) {
      Serial.println("Document not found, creating it...");
      
      // Add name field for document creation
      content.set("fields/name/stringValue", String(deviceName));
      
      if (Firebase.Firestore.createDocument(&fbdo, PROJECT_ID, "", documentPath, content.raw())) {
        Serial.println("New document created successfully in Firestore");
      } else {
        Serial.print("Failed to create document: ");
        Serial.println(fbdo.errorReason());
      }
    }
  }
}