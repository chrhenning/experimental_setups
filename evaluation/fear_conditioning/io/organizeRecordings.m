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
@title           :organizeRecordings.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/08/2018
@version         :1.0

Function to read in the individual recordings in a structured way.
%}
function recordings = organizeRecordings( p )
%ORGANIZERECORDINGS A structured array of recordings is generated.
%
%   Returns
%   A struct with the fields 'recs' and 'props'. 'recs' is a list of
%   individual recordings (struct for each recording). 'props' contains
%   shared properties/statistics.
    logger = log4m.getLogger();
    
    designIter = DesignIterator(p.designDir);
    numRecs = designIter.numberOfRecordings();
    
    designProperties = designIter.getProperties();
    if ~strcmp(designProperties.experiment_type, 'FC')
        logger.error('organizeRecordings', ['Evaluation code is not ' ...
            'designed to support experiments of type ' ...
            designProperties.experiment_type '.']);
    end
    
    % Figure out, which recordings should be ignored according to the user.
    recsToIgnore = zeros(1, size(p.excludeRecordings, 1));
    for i = 1:length(recsToIgnore)
        args = num2cell(p.excludeRecordings(i,:));
        recsToIgnore(i) = designIter.toLinearIndex(args{:});
    end

    % We use the preliminary Grewe-Lab freezing detection pipeline to
    % measure the behavioral response.
    candidatePath = fullfile(p.freezingDir, 'candidates_extraction.mat');
    load(candidatePath, 'candidates');
    
    if numRecs ~= length(candidates)
        logger.warn('organizeRecordings', ['Number of recordings ' ...
            'defined in design file (' num2str(numRecs) ') does not ' ...
            'match the number of found freezing traces (' ...
            num2str(length(candidates)) ').']);
    end
    
    % Preprocess freezing candidate identifiers.
    % There is a minor flaw in the freezing output file at the moment
    % (02/17/18), such that relative paths have leading slashes "/".
    % Removing leading or closing slashes.
    % The flaw has already been corrected (04/05/18). However, we keep the
    % code to stay downwards compatible.
    relCandDirs = {candidates.relativeVideoFolder};
    for i = 1:length(relCandDirs)
       if startsWith(relCandDirs{i}, '/')
           relCandDirs{i} = relCandDirs{i}(2:end);
       end
       if endsWith(relCandDirs{i}, '/')
           relCandDirs{i} = relCandDirs{i}(1:end-1);
       end
    end
    
    % Structure in which we store everything needed for the evaluation.
    r = struct([]);
    
    [numCohorts, numGroups, numSessions, numSubjects] = ...
        designIter.maxDesignDims();
    
    % General properties to find out.
    eventTypes = [];
    minEventLen = []; % per type
    maxEventLen = []; % per type

    % Just a flag used to display information.
    soundCorrWarnDisplayed = 0;
    
    % Actual index used to access struct r. Needed because parts of the
    % loop below may be skipped (e.g., ignored recordings).
    i = 1;
    for ii = 1:numRecs        
        [recording, ident, identNames] = designIter.get(ii);
        % An object of this class allows easier access to the properties of
        % the struct "recording".
        recObj = RecordingDesign(recording, designProperties, ident, ...
            p.designDir);
        
        identStr = ['Cohort ' num2str(ident(1)) ' - ' identNames{1} ...
            ', Group ' num2str(ident(2)) ' - ' identNames{2} ...
            ', Session ' num2str(ident(3)) ' - ' identNames{3} ...
            ', Subject ' num2str(ident(4)) ' - ' identNames{4}];
        
        ignInd = find(recsToIgnore == ii, 1);
        if ~isempty(ignInd)
            recsToIgnore(ignInd) = -1;
            logger.warn('organizeRecordings', ['Ignoring recording ' ...
                identStr ' in evaluation.']);
            continue;
        end

        args = num2cell(ident);
        relDataDir = DesignIterator.getRelFolder(args{:});
        dataDir = fullfile(p.dataDir, relDataDir);

        cind = find(strcmp(relCandDirs, relDataDir), 1);
        if isempty(cind)
            logger.error('organizeRecordings', ['Could not find the ' ...
                'freezing trace of current recording: ' identStr '.']);
            continue;
        end
        candidate = candidates(cind);

        logger.debug('organizeRecordings', ...
            ['Reading data from recording: ' identStr '.']);
        
        % Assert that the recording duration (according to design) matches
        % the duration of the behavior recording.
        % "if" statement below is for downwards compatibility.
        if isfield(candidate, 'numberOfFrames')
            videoDuration = candidate.numberOfFrames / candidate.frameRate;
            absDiff = abs(videoDuration - recObj.getDuration()); 
            relDiff = absDiff / recObj.getDuration();
            if absDiff ~= 0
                warnMsg = ['The duration of the recording differs ' ... 
                    'from the length of the behavior video by ' ...
                    num2str(absDiff) ' seconds.'];
                logger.warn('organizeRecordings', warnMsg);
                
                % FIXME the constant here is somewhat arbitrary.
                if relDiff > 0.005
                    warning(warnMsg);
                end
            end
            
            % TODO A postprocessing pipeline should ensure, that the video
            % frames are associated to recording timeframes, such that we
            % don't have to deal with dropped frames or video errors in the
            % evaluation code.
        end
        
        % Read parameters from actual recording.
        paramsDataDir = fullfile(dataDir, 'params.mat');
        paramsExp = load(paramsDataDir, 'p');
        pRec = paramsExp.p;
        
        % Find out which of the recorded recordings defined in the params
        % file corresponds to the current one.
        pRecInd = -1;
        
        nr = length(pRec.cohort);
        tmpRecs = zeros(nr, 4);
        tmpRecs(:, 1) = pRec.cohort;
        tmpRecs(:, 2) = pRec.group;
        tmpRecs(:, 3) = pRec.session;
        tmpRecs(:, 4) = pRec.subject;
        for j = 1:nr
            if all(tmpRecs(j,:) == ident)
                pRecInd = j;
                break;
            end
        end
        assert(pRecInd ~= -1);
        
        % Read data recorded during recording.
        inputDataDir = fullfile(dataDir, 'input_data.mat');
        load(inputDataDir, 'timestamps', 'inputData', 'timestampOffset');
        
        logger.debug('organizeRecordings', ['Current recording took ' ...
            'place at: ' datestr(timestampOffset) '.']);
        
        % Resample time stamps
        % I.e., we wanna use the time resolution specified in the params
        % file.
        evalTimestamps = linspace(0, recObj.getDuration(), ...
            recObj.getDuration() * p.evalRate);
        
        r(i).designIndex = ii; % Note, this one may differ from i.
        
        r(i).relativeDataFolder = relDataDir;
        r(i).recordingStart = timestampOffset;
        r(i).relativeTimestamps = evalTimestamps;
        r(i).cohort = ident(1);
        r(i).group = ident(2);
        r(i).session = ident(3);
        r(i).subject = ident(4);
        
        r(i).sounds = struct();
        r(i).shocks = struct();
        r(i).freezing = struct();
        r(i).evaluation = struct();
        
        %% CS Events
        % NOTE: In the design file we use structured arrays, here we
        % now use normal arrays to describe events.
        
        % Note, there might be serveral digital/analog event channels
        % specified.
        [numDigEvs, ~] = recObj.numEvents('digital');
        [numAnaEvs, ~] = recObj.numEvents('analog');
        evInd = 1;
        eventLists = cell(1, 1+numDigEvs + numAnaEvs);
        
        eventLists{evInd} = convertEvents(recObj, 'sound', -1, p);
        for e = 1:numAnaEvs
            evInd = evInd + 1;
            eventLists{evInd} = convertEvents(recObj, 'analog', e, p);
        end
        for e = 1:numDigEvs
            evInd = evInd + 1;
            eventLists{evInd} = convertEvents(recObj, 'digital', e, p);
        end
        
        % If sounds have been played via the soundcard, we need the actual
        % onset times when the sound has been played (which may be
        % different from what has been specified due to OS scheduling.
        if pRec.useSoundCard && p.correctSoundsIfRecorded
            r(i).soundCorrection = struct();
            r(i).soundCorrection.intendedOnset = eventLists{1}.onset;
            
            % Note, here we need to use the original NIDAQ timestamps.
            correctSoundOnsets = recordedSoundOnsetTime( ...
                p.leftSoundInputChannelIndex, ...
                p.rightSoundInputChannelIndex, recObj, ...
                designProperties, inputData, pRec.rateDAQ, timestamps);
            
            r(i).soundCorrection.actualOnset = correctSoundOnsets;
            eventLists{1}.onset = correctSoundOnsets;
        elseif pRec.useSoundCard && ~soundCorrWarnDisplayed
            soundCorrWarnDisplayed = 1;
            logger.warn('organizeRecordings', ['Sounds of at least ' ...
                'one recording are played via the sound card, which ' ...
                'has no real-time guarantee. Though, timing ' ...
                'correction is disabled.']);
        end

        % Merge CS events to single event list.
        r(i).events = mergeEventLists(eventLists);        
        
        for e = 1:length(r(i).events.onset)            
            eventType = r(i).events.type{e};
            eventLen = r(i).events.duration(e);
            
            if ~any(ismember(eventType, eventTypes))
                eventTypes = [eventTypes, string(eventType)];
                minEventLen = [minEventLen inf];
                maxEventLen = [maxEventLen 0];
            end
            
            stInd = find(strcmp(eventTypes, eventType));
            minEventLen(stInd) = min(minEventLen(stInd), eventLen);
            maxEventLen(stInd) = max(maxEventLen(stInd), eventLen);
        end       
        
        %% US Events
        r(i).shocks.onset = zeros(1, recObj.numShocks());
        r(i).shocks.duration = zeros(1, recObj.numShocks());
        
        for s = 1:recObj.numShocks()
            curShock = recObj.getShock(s);
            
            r(i).shocks.onset(s) = curShock.onset;
            r(i).shocks.duration(s) = curShock.duration;
            
            % TODO Not clear if another channel value might be meaningful
            % in fear conditioning. And if so, do we need to treat
            % different shock channels differently during evaluation?
            assert(curShock.channel == -1);
        end
        
        %% Freezing   
        numCands = size(candidate.candidateWindows, 1);
        r(i).freezing.onset = zeros(1, numCands);
        r(i).freezing.duration = zeros(1, numCands);
        
        cw = candidate.candidateWindows;
        fr = candidate.frameRate;
        
        for c = 1:numCands
            r(i).freezing.onset(c) = cw(c, 1) / fr;
            r(i).freezing.duration(c) = (cw(c, 2) - cw(c, 1)) / fr;
        end
        
%         if i > 10
%             disp('FIXME')
%             break;
%         end

        i = i + 1;
    end    
    
    if ~all(recsToIgnore == -1)
        logger.warn('organizeRecordings', ['The parameter ' ...
            '"p.excludeRecordings" defines recordings not specified ' ...
            'in the design file.']);
    end
 
    recordings.recs = r;
    recordings.props = struct();
    recordings.props.numGroups = numGroups;
    recordings.props.numSessions = numSessions;  
    recordings.props.numCohorts = numCohorts;  
    recordings.props.numSubjects = numSubjects;  
    recordings.props.eventTypes = eventTypes;
    recordings.props.minEventLengths = minEventLen;
    recordings.props.maxEventLengths = maxEventLen;
    %recordings.props.rateDAQ = rateDAQ;
    recordings.props.design = designIter;
    
    logger.info('organizeRecordings', [num2str(length(r)) ' recordings' ...
        ' are going to be evaluated.']);
    logger.info('organizeRecordings', ['The recordings are split into:' ...
        ' '  num2str(numCohorts) ' cohorts with ' num2str(numGroups) ...
        ' groups and a maximum of ' num2str(numSessions) ' sessions. ' ...
        'There is a maximum of ' num2str(numSubjects) ' subjects ' ...
        'per session.']);
end

function events = convertEvents(recObj, eventSource, eventChannel, p)
% CONVERTEVENTS Convert an event struct from the design file to an internal
% array presentation.
%
% Arguments:
% - recObj: An object of the class RecordingDesign.
% - eventSource: The type of event: 'analog', 'digital', 'sound'.
% - eventChannel: The channel index of an analog or digital event. The
%                 parameter is ignored for sound events.
% - p: Evaluation params struct.
    logger = log4m.getLogger();

    switch eventSource
    case 'analog'
        [~, numEventsList] = recObj.numEvents('analog');
        numEvents = numEventsList(eventChannel);
        getEvent = @(ident) recObj.getAnalogEvent(eventChannel, ident);
    case 'digital'
        [~, numEventsList] = recObj.numEvents('digital');
        numEvents = numEventsList(eventChannel);
        getEvent = @(ident) recObj.getDigitalEvent(eventChannel, ident);
    case 'sound'
        numEvents = recObj.numSounds();
        getEvent = @(ident) recObj.getSound(ident);
    otherwise
        error(['Unknown event source: ' eventSource]);
    end

    events = struct();
    events.onset = zeros(1, numEvents);
    events.duration = zeros(1, numEvents);
    events.type = cell(1, numEvents);  
    events.source = cell(1, numEvents);  
    
    ii = 0;
    for i = 1:numEvents
        ii = ii + 1;
        
        events.source{ii} = eventSource;
        
        curEvent = getEvent(i);
        events.onset(ii) = curEvent.onset;
        events.duration(ii) = curEvent.duration;
        
        eventType = curEvent.type;
       
        % Rename event type, if requested by user.
        for j = 1:size(p.mergeEventTypes, 1)
            if any(ismember(p.mergeEventTypes{j, 1}, eventType))
                eventType = p.mergeEventTypes{j, 2};
                break;
            end
        end

        events.type{ii} = eventType;
        
        % Exclude current event if requested.
        exclude = 0;
        for e = 1:size(p.excludeEvents, 1)
            if strcmp(p.excludeEvents{e, 1}, eventSource) && ...
                strcmp(p.excludeEvents{e, 2}, eventType)
                exclude = 1;
                break;
            end
        end
        
        if exclude
            % We override current event data with next event.
            ii = ii - 1;
            continue;
        end
    end
    
    if ii < numEvents
        events.onset = events.onset(1, 1:ii);
        events.duration = events.duration(1, 1:ii);
        events.type = {events.type{1, 1:ii}};
        events.source = {events.source{1, 1:ii}};
        
        if strcmp(eventSource, 'sound')
            logger.debug('convertEvents', ['Some ' eventSource ' ' ...
                'events have been excluded.']);
        else
            logger.debug('convertEvents', ['Some ' eventSource ' ' ...
                'events from channel ' num2str(eventChannel) ...
                ' have been excluded.']);
        end
    end
end

function events = mergeEventLists(eventLists)
% MERGEEVENTLISTS Merge a cell list of event lists into a single event
% list.
%
% Hence, this function merges overlapping events, disregarding the event
% source, i.e., only considering the event type.
%
% Note, the function doesn't work if an event overlaps with multiple other
% events.
%
% Arguments:
% - eventLists: A cell list of event lists as produced by the function
%               convertEvents.
    events = eventLists{1, 1};
    
    for i = 2:numel(eventLists)
        curEvents = eventLists{1, i};
        
        for k = 1:length(curEvents.onset)
            type_k = curEvents.type{k};
            on_k = curEvents.onset(k);
            off_k = on_k + curEvents.duration(k);
            
            isConsidered = 0;
            
            % We assume events are sorted in this list.
            for l = 1:length(events.onset)
                type_l = events.type{l};
                on_l = events.onset(l);
                off_l = on_l + events.duration(l);
                
                % If types are identical and overlap occurs.
                if strcmp(type_k, type_l) && ...
                    off_k >= on_l && on_k <= off_l
                    events.onset(l) = min(on_l, on_k);
                    events.duration(l) = max(off_l, off_k) - ...
                        events.onset(l);
                    
                    % FIXME maybe we don't want the source information to
                    % get lost.
                    events.source{l} = 'merged';
                    
                    isConsidered = 1;
                    break;
                elseif on_k < on_l || l == length(events.onset)
                    if l == length(events.onset) && on_k >= on_l 
                        % Insert at the end of the event list.
                        l = l + 1;
                    end
                    
                    % Insert a new event before event l.
                    onset = zeros(1, length(events.onset) + 1);
                    duration = zeros(1, length(events.onset) + 1);
                    type = cell(1, length(events.onset) + 1);  
                    source = cell(1, length(events.onset) + 1);  
                    
                    onset(1:l-1) = events.onset(1:l-1);
                    onset(l) = curEvents.onset(k);
                    onset(l+1:end) = events.onset(l:end);
                    
                    duration(1:l-1) = events.duration(1:l-1);
                    duration(l) = curEvents.duration(k);
                    duration(l+1:end) = events.duration(l:end);
                    
                    if l > 1
                        [type{1:l-1}] = deal(events.type{1:l-1});
                        [source{1:l-1}] = deal(events.source{1:l-1});
                    end
                    type{l} = curEvents.type{k};
                    source{l} = curEvents.source{k};
                    if l < length(onset)
                        [type{l+1:end}] = deal(events.type{l:end});
                        [source{l+1:end}] = deal(events.source{l:end});
                    end
                    
                    events.onset = onset;
                    events.duration = duration;
                    events.type = type;
                    events.source = source;
                    
                    isConsidered = 1;
                    break
                end
            end
            
            assert(isConsidered == 1); % Just a sanity check.
        end
    end
end

