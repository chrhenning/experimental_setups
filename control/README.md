# Conduct an Experiment

The *control software* controls an experimental setup (with a [NIDAQ](http://www.ni.com/data-acquisition/) device at its core).

The software is configured via the local file [params.m](params.m). Afterwards, one can start a *recording* by running the script [run_experiment.m](run_experiment.m). E.g., just enter

```Matlab
>> run_experiment
```

in the console (ensure, that the current Matlab folder is the folder that contains the script).

## General hints

* A constant HIGH signal for the duration of a recording can be generated via a trigger channel by setting `p.triggerRate` to 0. This is necessary, for instance, when triggering a recording with one of the custom Miniscopes.
* If for any reason, a recording has to be aborted, it is advisable to restart Matlab.
* The configurations in [params.m](params.m) are checked via the function [preprocessParams.m](helper/preprocessParams.m). This function doesn't produce user-friendly messages at the moment. If an assertion in this function fails for any reason, you have most likely a mistake in your [params.m](params.m). Try to understand why the assertion failed and revise your configuration.
* At the moment, **there must be at least one (analog) input channel specified** in the [params.m](params.m), as we can't access the NIDAQ timestamps otherwise. If no input channel is needed, just specify an unused channel (you can delete the recorded data afterwards).
* If digital channels are used, then there must be at least one analog channel specified (which is why we said, that at least one *analog* input channel should be specified). Otherwise, the clock is not initialized and the recording will fail.

## How to run multiple recordings at once?

As described in the [params.m](params.m) file, one may run several recordings in parallel and control these with a single computer. This, of course, requires one to have more than one experimental chamber.

All options, that are recording specific can be specified as matrices, where each row specifies the options for a particular recording.

For instance, assume we want to run two recordings at once, with the two identifiers:
* Cohorts: 1, Group: 1, Session: 3, Subject 2
* Cohorts: 1, Group: 2, Session: 3, Subject 4

We would then have to set the two identifiers to:
```Matlab
p.cohort = [1; 1];
p.group = [1; 2];
p.session = [3; 3];
p.subject = [2; 4];
```

For the remaining parameters, one can often either just specify them for one recording (in case they are shared among all recordings) or add a new row of parameters for each recording.

For instance, if both recordings should receive the same sounds, the `p.soundChannel` attribute can be set as follows:
 
```Matlab
p.soundChannel = {0, 1};
```

where channel 0 will output the signals of the left audio channel and channel 1 the once for the right audio channel, respectively. Both channels are assumed to be routed in both experimental chambers. This requires, that both recordings have the same sound design.

In case, someone wants to have distinct sound channels for each recording, one could specify the sound channels as follows:

```Matlab
p.soundChannel = {0, 1; 2, 3};
```

Where channels 0 and 1 will be used for recording 1 (identifier: 1,1,3,2) and channels 2 and 3 will be used for recording 2 (identifier: 1,2,3,4).

One may also use several behavior cameras per recording. Assume there are 2 cameras per recording specified. In recording 1, the first camera has an ROI of `[200, 30, 400, 400]` and the second an ROI of `[180, 10, 400, 400]`. If these ROIs should be adopted for recording 2, one can specify the parameter `p.bcROIPosition` as follows:

```Matlab
p.bcROIPosition = [200, 30, 400, 400, 180, 10, 400, 400];
```

If both recordings should have different ROIs for each camera (4 in total), the option has to be supplied as follows:

```Matlab
p.bcROIPosition = [200, 30, 400, 400, 180, 10, 400, 400; ...
                   150, 35, 400, 400, 160, 15, 400, 400];
```

## The Recording View

This is the GUI displayed during the recording. It logs the events that are currently scheduled and presents a live view of all behavior cameras.

### The Behavior Live View

In this part of the GUI, there is a preview of all behavior cameras. Note, that during the recording, the camera is triggered. For instance, if the recording is paused, then there are no triggers provided to the cameras via the NIDAQ and thus the image stalls.

### The Event Logger

The event logger should help the user to see what stimuli are presented to the animal, such that he can easily follow the recording. Events that are presented via the NIDAQ, are logged as soon as they are send to the NIDAQ. Thus, if the session runs in bulk mode, all events are logged at the beginning of the session. Otherwise, the events are logged as soon as their window is send to the NIDAQ (which depends on the option `p.continuousWin`).

For sounds played via the sound card, the events will be logged as soon as they are send to the sound card.

### The *Stop Recording* button

This button will interrupt the current recording and close all files. Note, as this interrupts a current NIDAQ session, the data actually send out by the NIDAQ must not match the output data stored in the recording folder.

### The *Pause* button

This is a new feature, that **hasn't been heavily tested yet**. The pause button only works in continous mode. The pause button does not immediately trigger a reaction. When the NIDAQ requests the next window of data (in continuous mode), the program handles the *pause request*. Instead of sending the next batch of data, it will force all output channels to be zero. A similar procedure is triggered when pressing the *Continue* button. 

Note, if sounds are played via the sound card, you may observe unwanted behavior. The reason lies in the delay between the request of a pause and the actual onset of the pause. If the sound onset lies in between this delay, then the sound is played, such that the pause is likely to start during the duration of the sound. A user should keep this in mind when using this feature.

As pausing the session causes an extension of the session duration, the recorded input data is larger than expected. This is corrected in an online fashion, such that pauses are filtered out in the output file `input_data.mat`. As this feature hasn't been heavily tested, there is always an additional file `input_data_raw.mat`, when using the continuous mode, which contains the raw input recordings (together with their timestamps). This is just to prevent data loss, in case there is a bug in the new implementation of the pause button.

If one wishes to use the raw data, he can filter out the paused time windows by using the matrix `output_windows` stored in the file `output_windows_debug.mat`. This matrix is an `n x 6` matrix, where `n` denotes the number of windows send to the NIDAQ. The meanings of each column are as follows:

* Start of the window in seconds (`-1` if it is a paused window)
* End of the window in seconds (`-1` if it is a paused window)
* Length of the window in time steps (the number of steps per second is defined by the NIDAQ rate)
* Cumulative number of steps of all windows that have been send so far (including this one)
* Cumulative number of steps of all windows that have been send so far (including this one), excluding the once that were paused
* `0` if normal output window, otherwise `1` (e.g., if pause)

## Output files

The software creates an output folder for each recording. Here is a short description of the files, that may be stored in this folder.

* `logfile.txt`: Contains the console logs, that where displayed during the runtime of the recording (identical for all parallel recordings).
* `params.m`: A copy of the parameters file, used to trigger the recording (identical for all parallel recordings).
* `input_data.mat`: Contains the recordings of all input channels as well as the relative NIDAQ timestamps plus the NIDAQ session start time. The recordings and timestamps purified from possible stall windows (such as pauses or wait windows (when waiting for input callbacks at the end of a continuous session)).
* `input_data_raw.mat`: This file is similar to `input_data.mat` and only created if the session runs in continuous mode. In contrast to `input_data.mat`, the data contained in this file is not purified from stall windows. This file is a backup, in case the purification process fails. In future versions, once the purification is sufficiently tested, the creation of this file should be optional.
* `output_data.mat`: Contains the data, that has been send to the NIDAQ (i.e., the data of all output channels). Stall windows are not contained.
* The folder also contains the behavior videos.
* If no design file is used, the folder will contain the auto-generated design.
* `output_windows_debug.mat`: See the [Pause Button](### The *Pause* button) section.
