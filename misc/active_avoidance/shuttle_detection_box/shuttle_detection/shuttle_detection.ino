/* Copyright 2018 Christian Henning
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @title           :shuttle_detection.m
 * @author          :ch
 * @contact         :christian@ini.ethz.ch
 * @created         :05/30/2018
 * @version         :1.0
 * 
 * This script controls an Arduino, that should detect when the mouse shuttles
 * (for the Active Avoidance setup). Currently, we ignore the LEFT OUT/RIGHT OUT
 * from the photo detectors of the shuttle cage. Instead, we have an online camera 
 * system, that communicates via USB and tells us the position of the mouse. 
 * 
 * If the control input is high, the system will act upon detecting a shuttling. It will
 * interupt the sound and shocking signals until the control signal turns LOW again. The
 * status output will indicate that a blocking is occurring.
 * 
 * Additionally, the SPARE IN output will continuously signal the position of the subject
 * (0 - left, 1 - right). This signal can be used to direct the shock into one of the
 * two chambers.
 */
 
/*
 * Pin assignments.
 */
int leftPin = 2; // Connected to LEFT OUT of shuttle cage.
int rightPin = 3; // Connected to RIGHT OUT of shuttle cage.

int statusPin = 12; // Is HIGH if switches are blocking signals.
int controlPin = 11; // Control box doesn't do anything if this input is LOW.

// Left and right sound channel switch control.
int soundPin1 = 9; // Controls the sound signal switch (right).
int soundPin2 = 10; // Controls the sound signal switch (left).

// Switch control for the two digital channels.
int shockPin1 = 7; // Controls the shocking signal switch (shock 1).
int shockPin2 = 8; // Controls the shocking signal switch (shock 2).

// Show internal side variable (on which side does the arduino think the mouse is?).
int leftLEDPin = 4; // Signals, that animal has been detected in the left cage half.
int rightLEDPin = 5; // Signals, that animal has been detected in the right cage half.

// These two pins are direct outputs from the arduino.
int sideControlPin = 6; // Outputs position (side) of mouse (used as SPARE IN of shuttle box).
int voidPin = 13; // Reserved for future usage. Currently: outputs status of switch activity.

/*
 * Configuration.
 */
// Whether the camera detection or the photodetector signals should be used 
// for shuttle detection?
int USE_SERIAL_INPUT = 1;

/*
 * Control variables.
 */
// FIXME, we could integrate the last position over some time, to have a 
// robust estimate.
int knownPos = -1; // Currently known position: 0 - left; 1 - right
int lastKnownPos = -1;

int sideChanged = 0; // Side change (shuttling) detected.

int controlVal = -1;
int eventType = -1; // 0 - STAY, 1 - GO
int leftVal = -1; // Value from leftPin input.
int rightVal = -1; // Value from rightPin input.

 // We need that, to read the detected position from the computer via USB.
int incomingByte = 0;

void setup() {
  // Shows switch blocking status atm.
  pinMode(LED_BUILTIN, OUTPUT);
  
  pinMode(leftPin, INPUT_PULLUP); 
  pinMode(rightPin, INPUT_PULLUP); 
  
  pinMode(statusPin, OUTPUT); 
  pinMode(controlPin, INPUT_PULLUP); 

  pinMode(soundPin1, OUTPUT); 
  pinMode(soundPin2, OUTPUT); 
  pinMode(shockPin1, OUTPUT); 
  pinMode(shockPin2, OUTPUT); 
  
  pinMode(sideControlPin, OUTPUT); 
  pinMode(voidPin, OUTPUT); 

  pinMode(leftLEDPin, OUTPUT); 
  pinMode(rightLEDPin, OUTPUT); 
        
  digitalWrite(statusPin, LOW);
  // The switches are by default turned off (non-blocking).
  // NOTE, switches are NO (normally open)
  digitalWrite(soundPin1, HIGH);
  digitalWrite(soundPin2, HIGH);
  digitalWrite(shockPin1, HIGH);
  digitalWrite(shockPin2, HIGH);
  digitalWrite(sideControlPin, LOW);
  digitalWrite(voidPin, LOW);

  digitalWrite(leftLEDPin, LOW);
  digitalWrite(rightLEDPin, LOW);

  Serial.begin(9600);
}

void loop() {  
  delay(10);

  controlVal = digitalRead(controlPin);  
  eventType = digitalRead(voidPin); 

  lastKnownPos = knownPos;

  /* Identify current cage side of subject */
  if (USE_SERIAL_INPUT) {
    // Read position from computer.
    if (Serial.available() > 0) {
      // read the incoming byte:
      incomingByte = Serial.read();

      // Give a feedback.
      Serial.print("Received position: ");
      Serial.println(incomingByte, DEC);

      // 49 is ASCII code for 1.
      if (incomingByte == 49) {
        knownPos = 1;
      } else {
        knownPos = 0;
      }
    }

    
  } else {
    leftVal = digitalRead(leftPin);  
    rightVal = digitalRead(rightPin);  

    // Note, that LEFT and RIGHT OUT inputs are inverted.
    if (rightVal == LOW) {
      knownPos = 1;
    // Left will be our default position.
    } else if (leftVal == LOW || lastKnownPos != -1) {
      knownPos = 0;
    }    
  }

  // Decide, whether position has changed:
  if (lastKnownPos != -1 && lastKnownPos != knownPos) {
    sideChanged = 1;
  }

  // User feedback.
  if (knownPos != -1) {
    if (knownPos == 0) {
      // Mouse is right.
      digitalWrite(leftLEDPin, LOW);
      digitalWrite(rightLEDPin, HIGH);
      
      digitalWrite(sideControlPin, HIGH);
    } else {
      // Mouse is left.
      digitalWrite(leftLEDPin, HIGH);
      digitalWrite(rightLEDPin, LOW);

      digitalWrite(sideControlPin, LOW);
    }
  }

  // We don't use the switches, if control var is low.
  if (controlVal == LOW) {
    goto default_mode;
  }

  // Block the signals until control signal is LOW again.
  if (sideChanged == 1) {
    goto blocking_mode;
  }
  
  goto default_mode;

  blocking_mode: 

  digitalWrite(LED_BUILTIN, HIGH);  
  
  digitalWrite(statusPin, HIGH);
  digitalWrite(soundPin1, LOW);
  digitalWrite(soundPin2, LOW);
  digitalWrite(shockPin1, LOW);
  digitalWrite(shockPin2, LOW);
  digitalWrite(voidPin, HIGH);

  return;
  
  default_mode:

  digitalWrite(LED_BUILTIN, LOW);  
  
  digitalWrite(statusPin, LOW);
  // The switches are by default turned off (non-blocking).
  digitalWrite(soundPin1, HIGH);
  digitalWrite(soundPin2, HIGH);
  digitalWrite(shockPin1, HIGH);
  digitalWrite(shockPin2, HIGH);
  digitalWrite(voidPin, LOW);

  sideChanged = 0;
}
