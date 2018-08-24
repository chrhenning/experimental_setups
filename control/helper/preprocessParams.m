% Copyright 2018 Christian Henning
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
@title           :preprocessParams.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/31/2018
@version         :1.0
%}


function params = preprocessParams(params)
%PREPROCESSPARAMS Ensuring that all params have correct values and
%preprocessing them, such that we can easily access them later in the code.
%
%   For instance, the user sometimes does not have to copy an option for
%   all recordings, if it is the same value for all of them. Instead, we
%   copy them here.
%
%   Note, this function doesn't make sure that all input values are valid,
%   it rather should help to ensure that the user didn't make any
%   unintentional errors due to quick changes or unknown parameter format.
    p = params;
    
    % Number of recordings.
    nr = length(p.cohort);
    %% Make sure, that recordings differ in at least one index.
    assert(length(p.group) == nr && length(p.session) == nr && ...
        length(p.subject) == nr);
    recs = zeros(nr, 4);
    recs(:, 1) = p.cohort;
    recs(:, 2) = p.group;
    recs(:, 3) = p.session;
    recs(:, 4) = p.subject;
    recs = unique(recs, 'rows');
    if size(recs, 1) ~= nr
        error(['At least one of the identifiers ("cohort", "group", ' ...
            '"session" or "subject") must differ between recordings.']);
    end    
    
    %%%%%%%%%%%%%%%%
    %%% Channels %%%
    %%%%%%%%%%%%%%%%
    %% Input Parameters
    assert(all(size(p.inputChannel) == size(p.inputIsAnalog)) && ...
        all(size(p.inputChannel) == size(p.inputDAQDeviceID)));
    if ~isempty(p.inputChannel)
        % Otherwise, we don't know how to store the data.
        assert(size(p.inputChannel, 1) == 1 || ...
            size(p.inputChannel, 1) == nr);
    end    
    
    if ~all(size(p.inputChannel) == size(p.inputDescription))
        warning(['Sizes of parameters "inputChannel" and ' ...
            '"inputDescription" do not match.']);
    end
    
    %% Trigger Parameters
    assert(all(size(p.triggerAmplitude) == size(p.triggerChannel)) && ...
        all(size(p.triggerRate) == size(p.triggerChannel)) && ...
        all(size(p.triggerIsAnalog) == size(p.triggerChannel)) && ...
        all(size(p.triggerDAQDeviceID) == size(p.triggerChannel)));
    if ~isempty(p.triggerChannel)
        % Otherwise, we don't know how to store the data.
        assert(size(p.triggerChannel, 1) == 1 || ...
            size(p.triggerChannel, 1) == nr);
    end   

    %% Shock Parameters
    assert(all(size(p.shockChannel) == size(p.shockIsAnalog)) && ...
        all(size(p.shockChannel) == size(p.shockAmplitude)) && ...
        all(size(p.shockChannel) == size(p.shockDAQDeviceID)));
    if ~isempty(p.shockChannel)
        % Either all recordings have the same shocking design, or all are
        % treated as if they are different.
        assert(size(p.shockChannel, 1) == 1 || ...
            size(p.shockChannel, 1) == nr);
    end
    
    assert(strcmp(p.shockMode, 'default') || ...
        strcmp(p.shockMode, 'channel') || ...
        strcmp(p.shockMode, 'left-right'));
    if strcmp(p.shockMode, 'lrdesign')
        assert(size(p.shockChannel, 2) == 2);
    end
    if strcmp(p.shockMode, 'lrposition')
        assert(size(p.shockChannel, 2) == 2);
        % We either use the same LR switch for all or each has a different
        % one.
        if size(p.shockLRInput, 1) == 1
            p.shockMode = repmat(p.shockLRInput, nr, 1);
            if nr > 1
                warning(['All chambers use the same "p.shockLRInput" ' ...
                    'input']);
            end
        else
            assert(size(p.shockLRInput, 1) == nr);
        end
        
        error('Shocking mode "lrposition" not yet implemented');
    end
    
    %% Sound Parameters
    if p.useSoundCard == 0
        assert(all(size(p.soundScale) == size(p.soundChannel)) && ...
            all(size(p.soundDAQDeviceID) == size(p.soundChannel)));
        % Either all recordings have the same sound design, or all are
        % treated as if they are different.
        assert(size(p.soundChannel, 1) == 1 || ...
            size(p.soundChannel, 1) == nr);
        % Either we have both sound channels the same or we have a left and
        % a right channel.
        assert(size(p.soundChannel, 2) == 1 || ...
            size(p.soundChannel, 2) == 2);
    end
    
    %% Sound Event Parameters
    assert(all(size(p.soundEventAmplitude) == ...
            size(p.soundEventChannel)) && ...
        all(size(p.soundEventIsAnalog) == size(p.soundEventChannel)) && ...
        all(size(p.soundEventDAQDeviceID) == size(p.soundEventChannel)));
    if ~isempty(p.soundEventChannel)
        % Either all recordings have the same sounds design, or all are
        % treated as if they are different.
        assert(size(p.soundEventChannel, 1) == 1 || ...
            size(p.soundEventChannel, 1) == nr);
    end
    
    %% Digital Channels from Design File
    assert(all(size(p.digitalChannel) == size(p.digitalDAQDeviceID)));
    if ~isempty(p.digitalChannel)
        % If nr > 1, but only one channel supplied, then we need to assume
        % that the design is equal for all other recordings.
        assert(size(p.digitalChannel, 1) == 1 || ...
            size(p.digitalChannel, 1) == nr);
    end   
    
    %% Analog Channels from Design File
    assert(all(size(p.analogChannel) == size(p.analogScale)) && ...
        all(size(p.analogChannel) == size(p.analogDAQDeviceID)));
    if ~isempty(p.analogChannel)
        % If nr > 1, but only one channel supplied, then we need to assume
        % that the design is equal for all other recordings.
        assert(size(p.analogChannel, 1) == 1 || ...
            size(p.analogChannel, 1) == nr);
    end     

    %%%%%%%%%%%%%%%%%%%%%%%%
    %%% Behavior Cameras %%%
    %%%%%%%%%%%%%%%%%%%%%%%%
    ncams = numel(p.bcDeviceID);
    camsPerRec = size(p.bcDeviceID, 2);
    % There has to be at least one camera per recording.
    assert(size(p.bcDeviceID, 1) == nr);
    
    if numel(p.bcAdapterName) == 1
        bcAdapterName = cell(nr, camsPerRec);
        for i = 1:ncams
            bcAdapterName{i} = p.bcAdapterName{1};
        end
        p.bcAdapterName = bcAdapterName;
    else
        assert(all(size(p.bcAdapterName) == size(p.bcDeviceID)));
    end
    
    if numel(p.bcFormat) == 1
        bcFormat = cell(nr, camsPerRec);
        for i = 1:ncams
            bcFormat{i} = p.bcFormat{1};
        end
        p.bcFormat = bcFormat;
    else
        assert(all(size(p.bcFormat) == size(p.bcDeviceID)));
    end
    
    for i = 1:numel(p.bcCamType)
        assert(strcmp(p.bcCamType, 'guppy') || ...
            strcmp(p.bcCamType, 'imagingsource'));
    end
    if numel(p.bcCamType) == 1
        bcCamType = cell(nr, camsPerRec);
        for i = 1:ncams
            bcCamType{i} = p.bcCamType{1};
        end
        p.bcCamType = bcCamType;
    else
        assert(all(size(p.bcCamType) == size(p.bcDeviceID)));
    end
    
    
    if numel(p.bcExposureTime) == 1
        p.bcExposureTime = ones(nr, camsPerRec) * p.bcExposureTime;
    else
        assert(all(size(p.bcExposureTime) == size(p.bcDeviceID)));
    end

    if numel(p.bcGain) == 1
        p.bcGain = ones(nr, camsPerRec) * p.bcGain;
    else
        assert(all(size(p.bcGain) == size(p.bcDeviceID)));
    end
    
    assert(size(p.bcROIPosition, 2) == camsPerRec * 4);
    if size(p.bcROIPosition, 1) == 1
        p.bcROIPosition = repmat(p.bcROIPosition, nr, 1);
    else
        assert(size(p.bcROIPosition, 1) == nr);
    end

    assert(ischar(p.bcLoggingMode));
    assert(ischar(p.bcVideoFormat));
    assert(numel(p.bcFrameRate) == 1);
    assert(numel(p.bcQuality) == 1);
    
    if numel(p.bcTriggerActivation) == 1
        bcTriggerActivation = cell(nr, camsPerRec);
        for i = 1:ncams
            bcTriggerActivation{i} = p.bcTriggerActivation{1};
        end
        p.bcTriggerActivation = bcTriggerActivation;
    else
        assert(all(size(p.bcTriggerActivation) == size(p.bcDeviceID)));
    end

    assert(size(p.bcFramesPerTrigger, 2) == 1);
    if numel(p.bcFramesPerTrigger) == 1
        p.bcFramesPerTrigger = ones(nr, camsPerRec) * p.bcFramesPerTrigger;
    else
        assert(all(size(p.bcFramesPerTrigger) == size(p.bcDeviceID)));
    end
    
    if numel(p.bcPreviewRotation) == 1
        p.bcPreviewRotation = ones(nr, camsPerRec) * p.bcPreviewRotation;
    else
        assert(all(size(p.bcPreviewRotation) == size(p.bcDeviceID)));
    end
    if ~all(ismember(p.bcPreviewRotation, [0,1,2,3]))
        error(['All elements of "p.bcPreviewRotation" must be from ' ...
            '[0,1,2,3].']);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%
    %%% External Trigger %%%
    %%%%%%%%%%%%%%%%%%%%%%%%
    if p.useExtTrigger
        assert(ischar(p.extTriggerChannel));
        assert(isnumeric(p.extTriggerTimeout));
    end
    
    %%%%%%%%%%%%%%%%%%%%%%
    %%% Side Detection %%%
    %%%%%%%%%%%%%%%%%%%%%%
    % This only works, if we have two cameras per recording.
    if p.useOnlineSideDetection
        if size(p.bcDeviceID, 2) ~= 2
            error(['The online side detection only works with 2 ' ...
                'cameras per recording specified!']);
        end
        
        % At the moment, we don't support multiple recordings, as we
        % haven't tested if we can communicate with multiple arduinos.
        if size(p.bcDeviceID, 1) ~= 1
            error(['The online side detection does currently not ' ...
                'support multiple recordings.']);
        end
        
        if p.sideDetUsePriorRefFrames || p.sideDetUsePriorExcluded
            file_name = fullfile(p.rootDir, 'misc', 'prior_ref_frames', ...
                'reference_frames.mat');
            if exist(file_name, 'file') ~= 2
                error(['File ' file_name ' must have been generated ' ...
                    'when "sideDetUsePriorRefFrames" or ' ...
                    '"sideDetUsePriorExcluded" is active.']);
            end
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%
    %%% Simple Design %%%
    %%%%%%%%%%%%%%%%%%%%%
    assert(ischar(p.sdExpType));
    assert(numel(p.sdDuration) == 1);
    assert(numel(p.sdSamplingRate) == 1);
    assert(numel(p.sdBitDepth) == 1);
    assert(numel(p.sdSoundDuration) == 1);
    assert(numel(p.sdShockDuration) == 1);
    
    numSounds = size(p.sdSoundFreq, 2);
    assert(size(p.sdSoundOnsets, 2) == numSounds && ...
        size(p.sdSoundTypes, 2) == numSounds);
    
    if ~isempty(p.sdSoundFreq)
        if size(p.sdSoundFreq, 1) == 1
            p.sdSoundFreq = repmat(p.sdSoundFreq, nr, 1);
        else
            assert(size(p.sdSoundFreq, 1) == nr);
        end

        if size(p.sdSoundOnsets, 1) == 1
            p.sdSoundOnsets = repmat(p.sdSoundOnsets, nr, 1);
        else
            assert(size(p.sdSoundOnsets, 1) == nr);
        end

        if size(p.sdSoundTypes, 1) == 1
            sdSoundTypes = cell(nr, numSounds);
            for i = 1:nr
                for s = 1:numSounds
                    sdSoundTypes{i, s} = p.sdSoundTypes{1, s};
                end
            end
            p.sdSoundTypes = sdSoundTypes;
        else
            assert(size(p.sdSoundTypes, 1) == nr);
        end
    end

    assert(all(size(p.sdShockOnsets, 2) == ...
            size(p.sdShockIntensities, 2)) && ...
        all(size(p.sdShockOnsets, 2) == size(p.sdShockChannels, 2)));
    
    if ~isempty(p.sdShockOnsets)
        if size(p.sdShockOnsets, 1) == 1
            p.sdShockOnsets = repmat(p.sdShockOnsets, nr, 1);
        else
            assert(size(p.sdShockOnsets, 1) == nr);
        end

        if size(p.sdShockIntensities, 1) == 1
            p.sdShockIntensities = repmat(p.sdShockIntensities, nr, 1);
        else
            assert(size(p.sdShockIntensities, 1) == nr);
        end

        if size(p.sdShockChannels, 1) == 1
            p.sdShockChannels = repmat(p.sdShockChannels, nr, 1);
        else
            assert(size(p.sdShockChannels, 1) == nr);
        end
    end
    
    params = p;
end

