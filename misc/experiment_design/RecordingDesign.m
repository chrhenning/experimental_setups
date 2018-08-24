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
@title           :RecordingDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :05/19/2018
@version         :1.0

An interface that allows easy interaction with a recording from the design 
file.
%}
classdef RecordingDesign
    %RECORDINGDESIGN Allows interaction with the design of a single
    %recording without knowing the specifics of the design file format.
    %
    %   However, the specifics of certain events still have to be known, as
    %   the functions typically return structs, that have the same naming
    %   structure as in the design file.
    %
    %   The benefit of the class is, that it takes care of sampling and
    %   reading data from files.
    %
    %   Note, that one can set a universal sampling rate for all event
    %   types, which will add a special field "interp"; see
    %   "setCommonSmpRate" for details.
    
    properties (Access = private)
        % Location of design file containing recording.
        DesignDir
        % Identifier of recording within design (4 indices).
        DesignIdent
        % Properties according to design file.
        DesignProps
        % Duration of the recording.
        Duration 
        % Shocks struct from the design file of the recording.
        Shocks
        % Sounds struct from the design file of the recording. Sounds have
        % been already read into memory.
        Sounds
        % List of digital event channels (events.digital struct from design
        % file.
        DigitalList
        % List of analog event channels (events.analog struct from design
        % file.
        AnalogList
        % One can set a common sampling rate for all event types, which
        % will result in a special field 'interp' in all event structs that
        % contains the data interpolated to this sampling rate.
        CommonSmpRate
        
    end
    
    methods (Access = public)
        function obj = RecordingDesign(recordingStruct, designProps, ...
                ident, designDir)
            %RECORDINGDESIGN Constructs a class object from the struct
            %determining the design of an individual recording (as taken
            %from the design file).
            %
            % Args:
            % - recordingStruct: Struct specifying recording.
            % - designProps: Properties defined in design file.
            % - ident (default: -1): An array of indices [cohort, group,
            %   session, subject] that identifies the recording within the
            %   design file.
            % - designDir (default: -1): The location of the design file
            %   containing the recording.
            if (~exist('ident', 'var'))
                ident = -1;
            end
            if (~exist('designDir', 'var'))
                designDir = -1;
            end
            
            % Unsused attributes (reserved for future usage).
            obj.DesignDir = designDir;
            obj.DesignIdent = ident;
            
            obj.CommonSmpRate = -1;            
            obj.DesignProps = designProps;
            obj = obj.parseStruct(recordingStruct);      
        end
        
        function duration = getDuration(obj)
            % GETDURATION Return duration of recording.
            duration = obj.Duration;
        end
        
        function numSounds = numSounds(obj)
            % NUMSOUNDS Returns the number of sound events.
            numSounds = length(obj.Sounds);
        end
        
        function numShocks = numShocks(obj)
            % NUMSHOCKS Returns the number of US events.
            numShocks = length(obj.Shocks);
        end
        
        function [numChannels, numEvents] = numEvents(obj, ident)
            % NUMEVENTS Returns the number of digital or analog event
            % channels and the number of events associated with each
            % channel.
            %
            % Args:
            % - ident: 'digital' or 'analog'.
            %
            % Returns:
            % - numChannels: Number of digital or analog event channels.
            % - numEvents: List of length "numChannels". Each entry
            %   specifies the number of events in an event channel.
            if strcmp(ident, 'digital')
                evList = obj.DigitalList;
            else
                evList = obj.AnalogList;
            end
            
            numChannels = length(evList);
            numEvents = zeros(1, numChannels);
            for i = 1:numChannels
                numEvents(i) = length(evList(i).events);
            end
        end
        
        function shock = getShock(obj, ind, smpRate)
            % GETSHOCK Return the shock struct of the ind-th shock.
            %
            % Args:
            % - ind: Index of shock.
            % - smpRate (default: -1): Sampling Rate of digital shock 
            %   event.
            %
            % Returns:
            % The shock struct as in the design file. If sampling rate is
            % specified, then an additional field "data" is added, that
            % contains the actual digital signal.
            if (~exist('smpRate', 'var'))
                smpRate = -1;
            end
            
            shock = obj.Shocks(ind);
            
            if smpRate ~= -1
                shock.data = RecordingDesign.toDigitalArray(...
                    shock.duration, shock.rising, shock.falling, smpRate);
            end            
        end
        
        function [sound, smpRate] = getSound(obj, ind)
            % GETSOUND Returns the sound struct from the ind-th sound.
            %
            % Args:
            % - ind: Index of sound.
            %
            % Returns:
            % - sound: The sound struct as defined in the design file. The
            %   data field is (in any case) already filled with the sound
            %   data.
            % - smpRate: Sampling rate of the sound (as defined in the
            %   design properties).
            sound = obj.Sounds(ind);
            smpRate = obj.DesignProps.sound_sampling_rate;
        end
        
        function event = getDigitalEvent(obj, chInd, evInd, smpRate)
            % GETDIGITALEVENT Return the event struct of the evInd-th event
            % in the chInd-th channel.
            %
            % Args:
            % - chInd: Index of digital event channel.
            % - evInd: Index of event.
            % - smpRate (default: -1): Sampling Rate of digital event.
            %
            % Returns:
            % The event struct as in the design file. If sampling rate is
            % specified, then an additional field "data" is added, that
            % contains the actual digital signal.
            if (~exist('smpRate', 'var'))
                smpRate = -1;
            end
            
            event = obj.DigitalList(chInd).events(evInd);
            
            if smpRate ~= -1
                event.data = RecordingDesign.toDigitalArray(...
                    event.duration, event.rising, event.falling, smpRate);
            end            
        end
        
        function [event, smpRate] = getAnalogEvent(obj, chInd, evInd)
            % GETANALOGEVENT Return the event struct of the evInd-th event
            % in the chInd-th channel.
            %
            % Args:
            % - chInd: Index of analog event channel.
            % - evInd: Index of event.
            %
            % Returns:
            % - event: The event struct as defined in the design file. The
            %   data field is (in any case) already filled with the sound
            %   data.
            % - smpRate: Sampling rate of the analog event (as defined in 
            %   the design properties).
            event =  obj.AnalogList(chInd).events(evInd);
            smpRate = obj.DesignProps.analog_sampling_rate;
        end
        
        function channel = getEventChannel(obj, ident, chInd)
            % GETEVENTCHANNEL Return a whole channel struct for an analog
            % or digital event.
            %
            % Args:
            % - ident: 'digital' or 'analog'.
            % - chInd: Index of event channel.
            if strcmp(ident, 'digital')
                evList = obj.DigitalList;
            else
                evList = obj.AnalogList;
            end
            
            channel = evList(chInd);
        end
        
        function obj = setCommonSmpRate(obj, smpRate, verbose) 
            % SETCOMMONSMPRATE Set a universal sampling rate, that is the
            % same for all events (US events, sounds, digital/ analog
            % events).
            %
            %   This will interpolate the event data to the given sampling
            %   rate. This interpolated data is stored in the new field
            %   'interp' for all events. The event structs can be retrieved
            %   as usual with the getter functions of this struct.
            %
            % Args:
            % - smpRate: The universal sampling rate.
            % - verbose (default: true): Whether to show warnings in case
            %   smpRate is smaller than original sampling rates (note, for
            %   digital events, no sanity checks are applied).
            if (~exist('verbose', 'var'))
                verbose = true;
            end
            
            obj.CommonSmpRate = smpRate;      
            
            if verbose
                sndSmpRate = obj.DesignProps.sound_sampling_rate;
                if smpRate < sndSmpRate
                    warning(['Common sampling rate ' num2str(smpRate) ... 
                        ' is smaller than the original sound sampling ' ...
                        'rate ' num2str(sndSmpRate) '.']);
                end
                
                anaSmpRate = obj.DesignProps.analog_sampling_rate;
                if smpRate < anaSmpRate
                    warning(['Common sampling rate ' num2str(smpRate)  ...
                        ' is smaller than the original analog ' ...
                        'sampling rate ' num2str(anaSmpRate) '.']);
                end
            end
            
            % Generate digital data.
            for s = 1:obj.numShocks()
                event = obj.getShock(s);
                data = RecordingDesign.toDigitalArray(...
                    event.duration, event.rising, event.falling, smpRate);
                obj.Shocks(s).interp = data;
            end
            
            [nDigChannels, nDigEvents] = obj.numEvents('digital');
             for ee = 1:nDigChannels
                for ev = 1:nDigEvents(ee)
                    event = obj.getDigitalEvent(ee, ev);
                    data = RecordingDesign.toDigitalArray(...
                        event.duration, event.rising, event.falling, ...
                        smpRate);
                   	obj.DigitalList(ee).events(ev).interp = data; 
                end
             end
            
            % Interpolate analog data.
            for s = 1:obj.numSounds()
                event = obj.getSound(s);
                sndSmpRate = obj.DesignProps.sound_sampling_rate;
                
                % NOTE sounds have transposed dimensionality (m x 2).
                obj.Sounds(s).interp = RecordingDesign ...
                    .interpolateSignal(event.data', event.duration, ...
                                       sndSmpRate, smpRate)';
            end
            
            [nAnaChannels, nAnaEvents] = obj.numEvents('analog');
            for ee = 1:nAnaChannels
                for ev = 1:nAnaEvents(ee)
                    event = obj.getAnalogEvent(ee, ev);
                    anaSmpRate = obj.DesignProps.analog_sampling_rate;
                    
                    obj.AnalogList(ee).events(ev).interp = ...
                        RecordingDesign.interpolateSignal(event.data, ...
                            event.duration, anaSmpRate, smpRate);
                end
            end
        end
        
        function [tData, sndTraces, usTrace, dTraces, aTraces] = ...
                toCompleteTraces(obj, smpRate, digital, duration)
            % TOCOMPLETETRACES Convert the design into full traces that
            % cover the whole session duration.
            %
            % Args:
            % - smpRate: Sampling rate used for traces.
            % - digital (default: false): Whether traces represent binary
            %   blocks (in event or outside of event) or whether traces
            %   depict the actual data.
            % - duration (default: duration of recording): The length of
            %   the returned traces (in seconds).
            %
            % Returns:
            % - tData: The timestamps of the returned traces.
            % - sndTraces: An 2 x n array, where 2 is the number of sound
            %   channels. n is the number of data points (duration x
            %   smpRate).
            % - usTrace: A logical array of size 1 x n, depicting the time
            %   course of US events.
            % - dTraces: An m x n logical array, where m is the number of
            %   digital channels.
            % - aTraces: An m x n array, where m is the number of analog
            %   channels.
            if (~exist('digital', 'var'))
                digital = false;
            end
            if (~exist('duration', 'var'))
                duration = obj.Duration;
            end
            
            [nDigChannels, nDigEvents] = obj.numEvents('digital');
            [nAnaChannels, nAnaEvents] = obj.numEvents('analog');
            
            tData = 0:1/smpRate:duration-1/smpRate;         
            
            usTrace = zeros(1, numel(tData), 'logical');
            dTraces = zeros(nDigChannels, numel(tData), 'logical');
            
            if digital
                sndTraces = zeros(2, numel(tData), 'logical');
                aTraces = zeros(nAnaChannels, numel(tData), 'logical');
            else
                sndTraces = zeros(2, numel(tData));
                aTraces = zeros(nAnaChannels, numel(tData));
            end
            
            function [t, x] = toTraceHelper(event, isDigital, ...
                    origSmpRate, transposeData)
                offset = event.onset + event.duration;
                t = tData >= event.onset & tData < offset;
                
                if digital
                    x = 1;
                else
                    if isDigital
                        data = RecordingDesign.toDigitalArray(...
                            event.duration, event.rising, ...
                            event.falling, smpRate);
                    else
                        inData = event.data;
                        if transposeData % for sounds
                            inData = inData';
                        end
                        data = RecordingDesign.interpolateSignal(...
                            inData, event.duration, origSmpRate, smpRate);
                    end
                    
                    maxInd = min(sum(t), size(data, 2));
                    x =  data(1:maxInd);
                end
            end
            
            for s = 1:obj.numSounds()
                event = obj.getSound(s);
                sndSmpRate = obj.DesignProps.sound_sampling_rate;
                
                [t, data] = toTraceHelper(event, 0, sndSmpRate, 1);
                sndTraces(1, t) = data;
                if size(data, 1) == 2
                    sndTraces(2, t) = data;
                else 
                    sndTraces(2, t) = data;
                end
            end
            
            for s = 1:obj.numShocks()
                event = obj.getShock(s);
                
                [t, data] = toTraceHelper(event, 1, -1, 0);
                usTrace(t) = data;
            end
            
            for ee = 1:nDigChannels
                for ev = 1:nDigEvents(ee)
                    event = obj.getDigitalEvent(ee, ev);
                    
                    [t, data] = toTraceHelper(event, 1, -1, 0);
                    dTraces(ee, t) = data;
                end
            end
            
            for ee = 1:nAnaChannels
                for ev = 1:nAnaEvents(ee)
                    event = obj.getAnalogEvent(ee, ev);
                    anaSmpRate = obj.DesignProps.analog_sampling_rate;
                    
                    [t, data] = toTraceHelper(event, 0, anaSmpRate, 0);
                    aTraces(ee, t) = data;
                end
            end
            
        end
    end
    
    methods (Access = private)
        function obj = parseStruct(obj, recStruct)
            % PARSESTRUCT Read recording struct into internal attributes.
            %
            %   Sounds are read into memory if they are stored into files.
            obj.Duration = recStruct.duration;
            
            obj.Shocks = recStruct.shocks;
            
            sounds = recStruct.sounds;
            % Read sound file into memory.
            for i = 1:length(sounds)
                if isempty(sounds(i).filename)
                    continue
                end
                
                if obj.DesignDir == -1
                    error(['Cannot read sound file ' sounds(i).filename ...
                        ' as design directory is unknown!']);
                end
                
                tonePath = fullfile(obj.DesignDir, sounds(i).filename);
                if exist(tonePath, 'file') ~= 2
                    error(['Sound file ', tonePath, ' does not exist.']);
                end
                [sndData, sr] = audioread(tonePath);
                % Assert that sampling rate of this audio file is the same 
                % as the one specified in the design file.
                assert(sr == obj.DesignProps.sound_sampling_rate);
                sounds(i).data = sndData;
            end
            obj.Sounds = sounds;
            
            obj.DigitalList = recStruct.events.digital;
            obj.AnalogList = recStruct.events.analog;
        end
    end
    
    methods (Static)
        function obj = toClassObject(designDir, cohort, group, ...
            session, subject)
            %TOCLASSOBJECT Calls the constructor to construct a recording 
            %from a design file given the recordings indices.
            %
            % Args:
            % - designDir: Directory of design file.
            % - cohort: Index of cohort in design.
            % - group: Index of group in design.
            % - session: Index of session in design.
            % - subject: Index of subject in design.
            %
            % Returns:
            % An object of class RecordingDesign.
            dIter = DesignIterator(designDir);
            rInd = dIter.toLinearIndex(cohort, group, session, subject);
            
            [recStruct, ident, ~] = dIter.get(rInd);  
            props = dIter.getProperties();
            obj = RecordingDesign(recStruct, props, ident, designDir);
        end
        
        function darr = toDigitalArray(duration, rising, falling, smpRate)
            % TODIGITALARRAY Convert a list of falling and rising edges
            % into a continous signal given a certain sampling rate.
            %
            % Args:
            % - duration: Duration of the returned signal (in sec).
            % - rising: A list of rising edges in the digital signal,
            %   encoded in absolute timepoints from the start of the
            %   signal.
            % - falling: Same as rising, but a list of falling edges.
            % - smpRate: Sampling rate of the encoded signal.
            %
            % Returns:
            % A logical array, encoding the digital signal defined by
            % rising and falling edges.
            darr = zeros(1, ceil(duration * smpRate), 'logical');
            
            ri = 1;
            fi = 1;
            while ri <= length(rising) || fi <= length(falling) 
                if ri <= length(rising) && fi <= length(falling) 
                    if rising(ri) < falling(fi)
                        val = 1;
                        onset = rising(ri);
                        ri = ri + 1;
                    else
                        val = 0;
                        onset = falling(fi);
                        fi = fi + 1;
                    end
                elseif ri <= length(rising)
                    val = 1;
                    onset = rising(ri);
                    ri = ri + 1;
                else
                    val = 0;
                    onset = falling(fi);
                    fi = fi + 1;
                end
                
                onInd = ceil(onset * smpRate) + 1;
                darr(onInd:end) = val;
            end
        end
        
        function [rising, falling] = toDigitalEdges(signal, smpRate)
            % TODIGITALEDGES Convert a digital signal into a list of rising
            % and falling edges.
            %
            % Args:
            % - signal: A logical 1D array (size: 1 x n).
            % - smpRate: The sampling rate of the signal.
            %
            % Returns:
            % - rising: A list of timestamps of rising edges.
            % - falling: A list of timespamts of falling edges.            
            diffSig = diff(signal);
            risInds = find(diffSig == 1);
            falInds = find(diffSig == -1);
            
            numRising = numel(risInds);
            numFalling = numel(falInds);
            
            rising = zeros(1, numRising);
            falling = zeros(1, numFalling);
            
            for i = 1:numel(risInds)
                ri = risInds(i);
                rising(i) = ri / smpRate;
            end
            
            for i = 1:numel(falInds)
                fi = falInds(i);
                falling(i) = fi / smpRate;
            end
            
            if signal(1) == 1
                rising = [0, rising];
            end
            
            % Convention: Unknown data is assumed to be zero.
            if signal(end) == 1
                falling = [falling, numel(signal) / smpRate];
            end                
        end
        
        function newSignal = interpolateSignal(signal, duration, ...
                origSmpRate, newSmpRate)
            % INTERPOLATESIGNAL Interpolate a signal with a new sampling
            % rate.
            %
            %   This method uses linear interpolation and extrapolates data
            %   points outside the domain.
            %
            % Args:
            % - signal: The analog signal to be resampled. Note, that we
            %   assume a 1-dimensional signal. If an array of size (k,n) is
            %   given, it will be treated as k signals with each n data
            %   points.
            % - duration: The duration of the signal (in seconds).
            % - origSmpRate: The original sampling rate of the signal.
            % - newSmpRate: The new sampling rate of the generated signal.
            %
            % Returns:
            % The resampled series.
            if origSmpRate == newSmpRate
                newSignal = signal;
                return;
            end
            
            % It might be that the original sampling was wrong and the
            % duration does not match the intended one.
            actualDuration = size(signal, 2) / origSmpRate;
                            
            origTimestamps = 0:1/origSmpRate:actualDuration-1/origSmpRate;
            newTimestamps = 0:1/newSmpRate:duration-1/newSmpRate;

            newSignal = zeros(size(signal, 1), numel(newTimestamps));
            for i = 1:size(signal, 1)
                newSignal(i,:) = interp1(origTimestamps, signal(i,:), ...
                    newTimestamps, 'linear', 'extrap');   
            end
        end
    end    
end

