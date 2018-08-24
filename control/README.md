# Conduct an Experiment

The *control software* controls an experimental setup (with a [NIDAQ](http://www.ni.com/data-acquisition/) device at its core).

The software is configured via the local file `params.m`. Afterwards, one can start a *recording* by running the script `run_experiment.m`. E.g., just enter

```Matlab
>> run_experiment
```

in the console (ensure, that the current Matlab folder is the folder that contains the script).

## General hints

* A contant HIGH signal for the duration of a recording can be generated via a trigger channel by setting `p.triggerRate` to 0. This is necessary, for instance, when triggering a recording with one of the custom Miniscopes.
* If for any reason, a recording has to be aborted, it is advisable to restart Matlab.
* The configurations in `params.m` are checked via the function `control/helper/preprocessParams.m`. This function doesn't produce user-friendly messages at the moment. If an assertion in this function fails for any reason, you have most likely a mistake in your `params.m`. Try to understand why the assertion failed and revise your configuration.
* At the moment, **there must be at least one (analog) input channel specified** in the `params.m`, as we can't access the NIDAQ timestamps otherwise. If no input channel is needed, just specify an unused channel (you can delete the recorded data afterwards).
* If digital channels are used, then there must be at least one analog channel specified (which is why we said, that at least one *analog* input channel should be specified). Otherwise, the clock is not initialized and the recording will fail.

## How to run multiple recordings at once?

As described in the `params.m` file, one may run several recordings in parallel and control these with a single computer. This, of course, requires one to have more than one experimental chamber.

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

