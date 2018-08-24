# Shuttle Detection Box

The *shuttle detection box* is a programmable hardware device, that is used to detect mouse shuttling in almost realtime and react appropriately.

## Why is this extra Hardware necessary?

Since we already have the NIDAQ Board for realtime-processing, we shouldn't need another device. However, the NIDAQ requires predefined signals and allows no processing of incoming data in realtime. Processing has to be done via callback functions, such that the reaction depends on the OS scheduling. Therefore, we integrate and process incoming information via this device and act immediately upon shuttling detection.

## Typical scenario

The heart of the box is an Arduino Nano, that integrates all the information. It can receive the position (cage side) of the subject either via USB from the computer (using online camera tracking) or directly via BNC connectors (e.g., from photodetectors). If currently a trial is presented to the subject (e.g., tone followed by a shock) the computer sets a control input via the NIDAQ board. If a shuttling appears during this trial, the *shuttle detection box* will react, e.g., via blocking signals from the computer (sound and shock commands).


