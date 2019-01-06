% Copyright 2018 Christian Henning, Rik Ubaghs
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%{
@title           :params.m
@author          :ch, ru
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0

Note, please set Matlab priority high in Windows task manager, before using
this program.

As a convention that allows later automatic discrimination, one should
always assign a lower channel ID to the left audio channel than to the
right.

For arrays (or cell arrays), it holds that each recording is a new row
e.g., p.triggerChannels = {0, 1; 2, 3} - 2 recordings, each with 2 
triggers). 
If multiple recordings are chosen but only one row is defined 
(e.g., p.triggerChannels = {0, 1}), then these channels are assumed to be
shared between all recordings.
DON'T ASSIGN A CHANNEL TWICE.

Note, the NIDAQ device ID can be obtained by calling daq.getDevices.

For channels that can be digital or analog: the amplitude is ignored when
the channel is assigned as digital channel.

Note, when using digital channels, at least one analog channel must be
assigned to setup clock signal.
%}

function p = params()
%PARAMS builds object containing all parameters to run behavior annotation.

    %% Specify recording.
    % This options must be changed before every new recording!
    % These variables specify the relative folder name of the recording within
    % 'p.rootDir'. Additionally, when using a design file, they specify the
    % experiment design.
    % One can run multiple  recordings. The 4 arrays always must have the
    % same length.
    % ALWAYS CHECK THAT THE FOLLOWING OPTIONS ARE CORRECT!
    p.cohort = [1];
    p.group = [1];
    p.session = [1];
    p.subject = [1];
    
    %% External experiment design.
    % An external experiment design file must adhere certain format (see
    % documentation).
    % Note, the sound and shock specifications are taken from the design
    % file and the settings of this config file are ignored.
    p.useDesignFile = 1;
    p.designDir = fullfile('C:', 'Users', 'USERNAME', 'experiment', ...
        'design');


    %% Experiment Directory
    % Where should we store all the recordings;
    p.rootDir = fullfile('C:', 'Users', 'USERNAME', 'experiment', ...
        'recordings');
    
    %% NIDAQ settings
    % If sounds are played via the NIDAQ (rather than the soundcard), this
    % value must be at least as high as the sound sampling rate!
    % Note, the NIDAQ might not support the exact rate you wish and set
    % another close rate, that is possible by the hardware.
    p.rateDAQ = 1000;
    
    %% Record or play sounds with NIDAQ?
    % Whether onee wants to use the sound card rather than the NIDAQ to
    % play the sound events.
    % If sounds are played, they may be recorded via the input channels,
    % this allows to measure time delays later on (note, that the sound
    % card doesn't operate in realtime.
    % When using the sound card, please set the Matlab priority to
    % "Realtime" in the task manager.
    % Note, when recording sounds, the NIDAQ rate might be considerately
    % smaller than the Nyquist rate of the recorded sounds.
    p.useSoundCard = 1;
    
    %% NIDAQ operating mode
    % If one uses the NIDAQ board in bulk mode, then all outputs for the
    % whole recording are generated and send to the NIDAQ board. This mode
    % is recommended, when the DAQ rate and recording length are relatively
    % small.
    % Otherwise, one should use the continuous mode. In the continuous
    % mode, the complete outputs are only generated for a fraction of the
    % recording length (e.g., 1 min), and then queued to the NIDAQ. This
    % mode requires far less working memory.
    p.useBulkMode = 0;
    % When using the continuous mode, the program sends data to the NIDAQ
    % for the duration of a certain time window.
    p.continuousWin = 10; % in seconds 
    
    %% Input Parameters
    % Note, that sounds can only be recorded correctly if the rateDAQ is at
    % least twice as high as the highest frequency component of the sounds.
    % FIXME we always need at least one input channel in order to get the
    % timestamps correctly.
    p.inputChannel = {'Port0/Line0', 'Port0/Line1', 0}; 
    p.inputIsAnalog = [0, 0, 1]; % Analog or digital channel?
    p.inputDAQDeviceID = {'dev1', 'dev1', 'dev1'};
    % The input channel description is not used by this software, but might
    % be helpful later on when analyzing the recordings.
    p.inputDescription = {'digital input 0', 'digital input 1', ...
        'analog input 0'};
    
    %% Trigger Parameters
    % Define output channels, that should be used as triggers.
    % A triggerRate of 0 results in a constant HIGH signal for the duration
    % of the recording.
    % Otherwise, the trigger output will be a square waveform where the
    % pulse width is half of the period (as defined by the trigger rate).
    p.triggerChannel = {'Port0/Line2'}; 
    p.triggerRate = [20]; % in Hz
    p.triggerIsAnalog = [0]; % Analog or digital channel?
    p.triggerAmplitude = [1]; % in V
    p.triggerDAQDeviceID = {'dev1'};
    
    %% Shock Parameters
    % The output channel connected to the foot shocker.
    p.shockChannel = {'Port0/Line3'};
    p.shockIsAnalog = [0]; % Analog or digital channel?
    p.shockAmplitude = [1]; % in V
    p.shockDAQDeviceID = {'dev1'};
    
    % Shocking Mode
    % When having multiple shockers (e.g., in active avoidance
    % experiments), then the control software has to decide how to
    % distribute the shocks to these shockers. The following operation
    % modes are available:
    % - 'default': All shock channels defined per recording receive all
    %              shocks specified in the design file ("channel" field in
    %              design file is ignored).
    % - 'channel': In this case, the "channel" field of the "shocks" struct
    %              in the design file determines where the shocks are
    %              distributed. 
    %              Note, design option "shock.channel" determines the index 
    %              of p.shockChannel.
    %              Example: p.shockChannel = {0; 2}; 
    %                       If shock.channel == 1, then channel 0 receives
    %                       the shock.
    %                       If shock.channel == 2, then channel 2 receives
    %                       the shock.
    % - 'lrdesign': An additional output channel determines whether the
    %               shock is delivered to the left or right chamber
    %               (typical active avoidance setup). I.e., we expect to
    %               have 2 shock channels, the first one is simply HIGH 
    %               when a shock is supplied, the second one is HIGH when 
    %               the shock should be supplied to the right chamber, left
    %               otherwise. I.e., the design field "shock.channel"
    %               determines whether the shock is provided to the left
    %               (shock.channel == 1) or right (shock.channel == 2).
    % - 'lrposition': This is similar to the option 'lrdesign', except that
    %                 not the design decides whether the shock is supplied
    %                 left or right. Instead, an additional digital input
    %                 makes that decision (0 == left, 1 == right).
    %                 FIXME: Not implemented! Use Shuttle Detection Box for
    %                 this purpose.
    p.shockMode = 'default';
    % If shocking mode is 'lrposition', then we need the index of the
    % digital input, that determines left or right.
    % TODO: Linear or 2D index?
    p.shockLRInput = [];
    
    %% Sound Parameters
    % Only if p.useSoundCard == 0.
    p.soundChannel = {}; % analog channels only
    p.soundScale = [];
    p.soundDAQDeviceID = {};
    
    %% Sound Event Parameters
    % This is an optional binary signal, that turns 1 when a sound event is
    % being played.
    p.soundEventChannel = {}; 
    p.soundEventIsAnalog = []; % Analog or digital channel?
    p.soundEventAmplitude = []; % in V
    p.soundEventDAQDeviceID = {};
    
    %% Digital Channels from Design File
    % Please specify as many digital channels as specified in the design of
    % the recordings. Note, they are expected to have the same order as in
    % the design.
    p.digitalChannel = {'Port0/Line4'}; 
    p.digitalDAQDeviceID = {'dev1'};
    
    %% Analog Channels from Design File
    % Please specify as many analog channels as specified in the design of
    % the recordings. Note, they are expected to have the same order as in
    % the design.
    % Ensure that p.rateDAQ corresponds to the sampling rate of the analog
    % events!
    p.analogChannel = {}; 
    p.analogScale = []; 
    p.analogDAQDeviceID = {};
    
    %% Behavior Cameras
    p.bcAdapterName = {'gentl'};
    %p.bcAdapterName = {'tisimaq_r2013_64'};
    p.bcDeviceID = [1, 2];
    p.bcFormat = {'Mono8'};
    %p.bcFormat = {'RGB24 (752x480)'};
    
    % Cameras from different vendors might have different interfaces.
    % Currently, we support the following cameras:
    % - 'guppy': Tested with Allied Vision Guppy PRO F125B.
    % - 'imagingsource': Tested with ImagingSource DMK 23FV024.
    p.bcCamType = {'guppy'};
    
    % It is recommended to set the camera settings with the Image
    % Acquisition Toolbox once and then copy-paste them here.
    % General Settings
    p.bcExposureTime = [45000];
    p.bcGain = [3.9849];
    
    % Region of Interest
    % ROI is a 4-tuple: (X-Offset, Y-Offset, Width, Height).
    % Each row has n*4 values, where n is the number of cameras per
    % recording.
    p.bcROIPosition = [264, 0, 800, 800, 264, 0, 800, 800];
    
    % File logging
    p.bcLoggingMode = 'disk';
    p.bcVideoFormat = 'Motion JPEG AVI';
    p.bcFrameRate = 20;
    p.bcQuality = 75;
    
    % Trigger settings
    p.bcTriggerActivation = {'RisingEdge'};
    p.bcFramesPerTrigger = [1];
    % DON'T CHANGE THE TRIGGER SETTINGS. The prgram is designed to work
    % only with these settings at the moment.
    p.bcTriggerMode = 'On';
    p.bcTriggerRepeat = Inf;
    p.bcTriggerType = 'hardware';
    
    % You can rotate the preview of the camera image. Note, this only
    % effects the preview (videos are stored without rotation).
    % Specify the number of 90 degree rotations (number between 0 and 3).
    p.bcPreviewRotation = 0;
    
    %% Use External Trigger to Start Acquisition
    % Use this option to trigger the start of the recording with an
    % external signal.
    p.useExtTrigger = 0;
    % Specify PFI channel to receive recording trigger.
    p.extTriggerChannel = 'dev1/PFI1';
    % Specify timeout for waiting of trigger.
    p.extTriggerTimeout = 60; % in seconds    
    
    %% Online Cage Side Detection
    % This option is sensible in active avoidance experiments. The option
    % expects two cameras per recording, each pointing on one of the half
    % cages. The algorithm detects under which camera the mouse is
    % currently moving and communicates this location via a serial port.
    % TODO Build in ROI selection (such that parts of the other half cage
    % are ignored by each camera).
    % TODO Handle reference frame properly.
    p.useOnlineSideDetection = 0;
    % Serial port, to which current location is send to.
    p.sideDetSerialPort = 'COM3';
    % Whether to show excluded area in camera preview.
    p.sideDetPreviewExcluded = 1;
    % You can generate "reference frames" and "excluded areas" (which are
    % required by the algorithm) in advance with the script 
    % "take_reference_frame.m".
    % Use a priori defined reference frames.
    % Recommended for fixed cage and constant illumination.
    p.sideDetUsePriorRefFrames = 0;
    % Use a priori defined excluded areas.
    % Recommended for fixed camera position relative to cage.
    p.sideDetUsePriorExcluded = 1; 
    
    %% Simple Design
    % When not using a design file (p.useDesignFile == 0), then one can use
    % the following settings to generate a very simple (limited) design for
    % a recording.
    
    % The duration of the whole experiment.
    p.sdDuration = 10; % in seconds

    % Sound Parameters
    p.sdExpType = 'FC'; % 'FC', 'AA' or 'UN'
    p.sdSamplingRate = 32000;
    p.sdBitDepth = 24;
    p.sdSoundDuration = 2; % in seconds
    p.sdSoundFreq = [3000, 6000]; % in Hz
    p.sdSoundOnsets = [3, 7]; % in seconds
    p.sdSoundTypes = {'CS+', 'CS-'};  
    
    % Shock Parameters
    p.sdShockDuration = 1; % in seconds
    p.sdShockOnsets = [5, 9];
    % Unused option, no effect yet.
    p.sdShockIntensities = [6e-4, 6e-4]; % in A
    p.sdShockChannels = [-1, -1]; % in A
    
    %% Miscellaneous Options
    % Online correction of recorded data.
    % This option only makes sense if not using the bulk mode.
    % This option is only temporarily, as the algorithm hasn't been fully
    % tested.
    % If using the continuous mode, the user has the option to pause the
    % current session. During that time, it might be desirable, that the
    % written input recordings (as well as their timestamps) are paused as
    % well. Therefore, we can run an online correction, that corrects the
    % timestamps and ignores the input data coming from pausing frames.
    % When should I disable this option? Simply speaking, either if you run
    % out of resources (for instance, this option will cause the generation
    % of two output files, one corresponds to the raw data in case the
    % algorithm fails) or if your session fails because of this algorithm
    % :) (in which case, you should report the bug).
    p.correctRecordedInputs = 1;
end

