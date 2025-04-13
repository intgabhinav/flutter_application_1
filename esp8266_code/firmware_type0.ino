#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// WiFi credentials
const char* ssid = "YourWiFiSSID";      // Replace with your WiFi SSID
const char* password = "YourWiFiPassword";  // Replace with your WiFi password

// Web server on port 80
ESP8266WebServer server(80);

// LED pin
const int ledPin = 2;  // Built-in LED on ESP8266 (GPIO2)

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  
  // Initialize LED pin
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, HIGH);  // LED is active LOW, so HIGH = off
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  
  // Wait for connection
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    // Blink LED while connecting
    digitalWrite(ledPin, !digitalRead(ledPin));
  }
  
  // Print connection details
  Serial.println("");
  Serial.print("Connected to WiFi: ");
  Serial.println(ssid);
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  // Turn LED on to indicate successful connection
  digitalWrite(ledPin, LOW);
  
  // Set up web server routes
  server.on("/", HTTP_GET, handleRoot);
  server.on("/button", HTTP_POST, handleButton);
  
  // Start the server
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  // Handle client requests
  server.handleClient();
}

// Handle root page
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>body{font-family:Arial;margin:0;padding:20px;text-align:center;}";
  html += "button{background-color:#4CAF50;color:white;padding:15px 30px;border:none;border-radius:5px;cursor:pointer;font-size:18px;margin-top:20px;}";
  html += "button:hover{background-color:#45a049;}";
  html += "#response{margin-top:20px;padding:10px;border:1px solid #ddd;display:none;}";
  html += "</style>";
  html += "<script>";
  html += "function pressButton() {";
  html += "  fetch('/button', {method: 'POST'})";
  html += "    .then(response => {";
  html += "      if(response.status === 202) {";
  html += "        return response.text();";
  html += "      } else {";
  html += "        throw new Error('Server responded with status: ' + response.status);";
  html += "      }";
  html += "    })";
  html += "    .then(data => {";
  html += "      document.getElementById('response').style.display = 'block';";
  html += "      document.getElementById('response').textContent = 'Response: ' + data;";
  html += "    })";
  html += "    .catch(error => {";
  html += "      console.error('Error:', error);";
  html += "      document.getElementById('response').style.display = 'block';";
  html += "      document.getElementById('response').textContent = 'Error: ' + error.message;";
  html += "    });";
  html += "}";
  html += "</script></head><body>";
  html += "<h1>Simple Button Server</h1>";
  html += "<p>Press the button to get a response</p>";
  html += "<button onclick='pressButton()'>Press Me</button>";
  html += "<div id='response'></div>";
  html += "<p>Device IP: " + WiFi.localIP().toString() + "</p>";
  html += "</body></html>";
  
  server.send(200, "text/html", html);
}

// Handle button press
void handleButton() {
  // Return "123456" with status code 202
  server.send(202, "text/plain", "123456");
  
  // Flash the LED to indicate button press
  digitalWrite(ledPin, HIGH);  // Turn LED off
  delay(100);
  digitalWrite(ledPin, LOW);   // Turn LED on
  
  Serial.println("Button pressed, sent response: 123456");
}