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
@title           :check_design_file.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/22/2018
@version         :1.0

A method to check if a design file adheres the specified format.

This method can be used to check if a user-generated design file has the
correct format to be used by the Fear Conditioning setup control and
evaluation.

Changelog:
- 03/15/18: Augmented design file, such that active avoidance experiments
            (AA) are feasible. Additionally, added ability to specify
            arbitrary digital and analog events. Design files generated
            before this date can be converted to the current format by
            using this function.
- 05/09/18: Analog events (sounds and pure analog events) have a duration
            field now. The "sound" field in sounds has been renamed to
            "data". The "name" field in events has been renamed to
            "description". The events hava now a "type" field. Digital
            events (pure digital and shocks) have are now defined by there
            "rising" and "falling" edges, such that one can specify a
            complex digital event but independent of a specific sampling
            rate.
%}

function check_design_file(design_folder)
%CHECK_DESIGN_FILE This function checks whether a design file has the
%correct format.
%
%   Please check the output carefully for errors and/or warnings.
%
%   The function might try to repair a damaged design file and store it in
%   a new file.
    global DISP_WARN;
    DISP_WARN = 0;
    global DESIGN_FOLDER;
    DESIGN_FOLDER = design_folder;
    global DESIGN_PROPS;

    if ~isdir(design_folder)
        error(['Folder ' design_folder ' does not exist']);
    end
    
    design_file = fullfile(design_folder, 'experiment.mat');
    
    if exist(design_file, 'file') ~= 2
       error(['Design file ' design_file ' does not exist']); 
    end
    
    load(design_file, 'experiment');
    
    if exist('experiment', 'var') ~= 1
       error(['Design file ' design_file ' does not contain a variable' ...
           ' "experiment".']); 
    end
    
    exp = experiment;
    
    %% Check properties.
    % Default properties.
    sound_sampling_rate = 48000; 
    sound_bit_depth = 24;
    
    if ~isfield(exp, 'properties')
        error('Field "properties" is missing.');
    end
    
    props = exp.properties;
    if ~isfield(props, 'sound_sampling_rate')
        exp.properties.sound_sampling_rate = sound_sampling_rate;
        warn(['Field "sound_sampling_rate" is missing. A default ' ...
            'value of ' num2str(sound_sampling_rate) ' has been set.']);
    end
    if ~isfield(props, 'sound_bit_depth')
        exp.properties.sound_bit_depth = sound_bit_depth;
        warn(['Field "sound_bit_depth" is missing. A default ' ...
            'value of ' num2str(sound_bit_depth) ' has been set.']);
    end
    if ~isfield(props, 'analog_sampling_rate')
        exp.properties.analog_sampling_rate = ...
            exp.properties.sound_sampling_rate;
        warn(['Field "analog_sampling_rate" is missing. It has been ' ...
            'set to the "sound_sampling_rate".']);
    end
    
    % Experiment type is an optional property that helps identifying the
    % intended experiment type (at the moment: fear conditioning (FC) or
    % active avoidance (AA).
    if ~isfield(props, 'experiment_type')
        exp.properties.experiment_type = 'FC';
        warn(['Field "experiment_type" is missing. A default ' ...
            'value "FC" has been set.']);
    else
        if strcmp(props.experiment_type, 'UN')
            % This does not have to have any effects, as long as the user
            % knows what he is doing.
            warning('Experiment type is marked as "UNKNOWN".');
        elseif ~(strcmp(props.experiment_type, 'FC') || ...
                 strcmp(props.experiment_type, 'AA'))
            error(['Value "' props.experiment_type '" of field ' ...
                '"experiment_type" is unknown.']);
        end
    end    
    
    DESIGN_PROPS = exp.properties;
    
    %% Check actual design.
    if ~isfield(exp, 'design')
        error('Field "design" is missing.');
    end
    
    if ~isfield(exp.design, 'cohorts')
        error('Field "cohorts" is missing.');
    end
    
    exp.design.cohorts = check_cohorts(exp.design.cohorts);
    
    if DISP_WARN
        fn = fullfile(design_folder, 'experiment_repaired.mat');
        warning(['The design file format was not perfectly correct. ' ...
            'We attempted to repair the issues and wrote the repaired ' ...
            'design file into: ' fn]);
        experiment = exp;
        save(fn, 'experiment', '-v7.3');
        
        % JSON might be good for visualization.
        if true
            expStr = jsonencode(experiment);
            fid = fopen(fullfile(design_folder, ...
                'experiment_repaired.json'), 'w');
            fprintf(fid, '%s\n', expStr);
            fclose(fid);
        end
    else
        disp('### Design file was successfully checked with no issues.');
    end
end

function cohorts = check_cohorts(cohorts)
    for i = 1:length(cohorts) 
        cohorts = check_repeated(cohorts, i, 'cohort');
        
        if ~isfield(cohorts, 'groups') || ~isstruct(cohorts(i).groups)
            error(['Field "groups" is missing in cohort ' num2str(i) '.']);
        end
        
        cohorts(i).groups = check_groups(cohorts(i).groups);
    end
end

function groups = check_groups(groups)
    for i = 1:length(groups) 
        groups = check_repeated(groups, i, 'group');
        
        if ~isfield(groups, 'sessions') || ~isstruct(groups(i).sessions)
            error(['Field "sessions" is missing in group ' num2str(i) ...
                '.']);
        end
        
        groups(i).sessions = check_sessions(groups(i).sessions);
    end
end

function sessions = check_sessions(sessions)
    for i = 1:length(sessions) 
        sessions = check_repeated(sessions, i, 'session');
        
        if ~isfield(sessions, 'subjects') || ...
                ~isstruct(sessions(i).subjects)
            error(['Field "subjects" is missing in session ' num2str(i) ...
                '.']);
        end
        
        sessions(i).subjects = check_subjects(sessions(i).subjects);
    end
end

function subjects = check_subjects(subjects)
    for i = 1:length(subjects) 
        subjects = check_repeated(subjects, i, 'subject');
        
        if ~isfield(subjects, 'duration') || ...
                ~isnumeric(subjects(i).duration)
            error(['Field "duration" is missing in subject ' num2str(i) ...
                '.']);
        end
        
        if ~isfield(subjects, 'shocks') || ~isstruct(subjects(i).shocks)
            error(['Field "shocks" is missing in subject ' num2str(i) ...
                '.']);
        end
        
        shocks = subjects(i).shocks;
        for j = 1:length(subjects.shocks)
            if ~isfield(shocks, 'onset') || ~isnumeric(shocks(j).onset)
                error(['Field "onset" is missing in shock ' num2str(j) ...
                    '.']);
            end
            if ~isfield(shocks, 'duration') || ...
                    ~isnumeric(shocks(j).duration)
                error(['Field "duration" is missing in shock ' ...
                    num2str(j) '.']);
            end
            % Note, the intensity of the shock might not be controlled by
            % the computer (as currently the case in our control software
            % (03/13/18)).
            if ~isfield(shocks, 'intensity') || ...
                    ~isnumeric(shocks(j).intensity)
                error(['Field "intensity" is missing in shock ' ...
                    num2str(j) '.']);
            end
            % The channel association can indicate to the control software
            % how to deliver a shock. E.g., when conducting an AA
            % experiment, then this might indicate whether to shock left
            % (0) or right (1). The default -1 indicates that the control
            % software has to decide how to apply shocks.
            if ~isfield(shocks, 'channel')
                [shocks.channel] = deal(-1);
                warn(['Field "channel" is missing in shock field. ' ...
                    'Default value "-1" has been set.']);
            end
            
            if ~isnumeric(shocks(j).channel)
                error(['Field "channel" has invalid value in shock ' ...
                    num2str(j) '.']);
            end
            
            % These two fields were missing in previous versions.
            % Relative time points of rising edges in digital event.
            if ~isfield(shocks, 'rising') || ...
                    ~isfield(shocks, 'falling') || ...
                    (~isempty(shocks(j).rising) && ...
                        any(shocks(j).rising == -1))
                if j == 1 
                    [shocks.rising] = deal(-1);
                end
                % We assume a constant high signal.
                shocks(j).rising = 0;
                shocks(j).falling = shocks(j).duration;
                warn(['Fields "rising" and "falling" are missing in s' ...
                    'hock ' num2str(j) '. Constant high signal assumed.']);
            end
        end
        subjects(i).shocks = shocks;
        
        if ~isfield(subjects, 'sounds') || ~isstruct(subjects(i).sounds)
            error(['Field "sounds" is missing in subject ' num2str(i) ...
                '.']);
        end
        
        subjects(i).sounds = check_sounds(subjects(i).sounds);
        
        if ~isfield(subjects, 'events') || ~isstruct(subjects(i).events)
            subjects(i).events = struct();
            subjects(i).events.analog = struct([]);
            subjects(i).events.digital = struct([]);
            warn(['Field "events" is missing in subject ' num2str(i) ...
                '.']);
        end
        
        subjects(i).events = check_events(subjects(i).events);
    end
end

function events = check_events(events)
%CHECK_EVENTS Events are either analog or digital signals that are
%delivered to analog or digital output channels directly.
%
%   E.g., a digital event might be the triggering of a light. Note, sounds
%   are analog events but they should be assigned to the corresponding
%   sounds field of a subject, as this may allow the control software to
%   play them via the sound card (and not necessarily via the NIDAQ).
%   Additionally, for sounds a certain sampling rate can be enforced.
    global DESIGN_PROPS;

    % Analog events
    if ~isfield(events, 'analog') || ~isstruct(events.analog)
        events.analog = struct([]);
        warn('Field "analog" is missing in field "events".');
    end
    analog = events.analog;

    % For each analog channel.
    for i = 1:length(analog) 
        if ~isfield(analog, 'infos') || ~isstruct(analog(i).infos)
            warn(['Field "infos" is missing in analog event ' ...
                num2str(i) '.']);
            analog(i).infos = struct();
        end
        
        % Field "description" was called "name" in a previous version.
        if isfield(analog, 'name') && ~isfield(analog, 'description')
            [analog(:).description] = deal(analog(:).name);
            analog = rmfield(analog, 'name');
            warn(['Field "name" was renamed to "description" in ' ...
                'analog events.']);
        end
        
        if ~isfield(analog, 'description') || ...
                ~ischar(analog(i).description)
            error(['Field "description" is missing in analog event ' ...
                num2str(i) '.']);
        end
        
        if ~isfield(analog, 'events') ||~isstruct(analog(i).events)
            error(['Field "events" is missing in analog event ' ...
                num2str(i) '.']);
        end

        aevents = analog(i).events;
        
        % For all events in that channel
        for j = 1:length(aevents) 
            if ~isfield(aevents, 'infos') || ~isstruct(aevents(j).infos)
                warn(['Field "infos" is missing in analog event ' ...
                    num2str(j) ' of channel ' num2str(j)  '.']);
                aevents(i).infos = struct();
            end

            if ~isfield(aevents, 'onset') || ~isnumeric(aevents(j).onset)
                error(['Field "onset" is missing in analog event ' ...
                    num2str(j) ' of channel ' num2str(j)  '.']);
            end

            if ~isfield(aevents, 'data') 
                error(['Field "data" is missing in analog event ' ...
                    num2str(j) ' of channel ' num2str(j)  '.']);
            end
            
            % The field type was missing in a previous design format
            % version.
            default_type = 'analog';
            if ~isfield(aevents, 'type') || ~ischar(aevents(j).type)
                [aevents.type] = deal(default_type);
                warn(['Field "type" was set to default value "' ...
                    default_type '" in analog event channel ' ...
                    num2str(j)  '.']);
            end
            
            % This field was missing in a previous format version.
            if ~isfield(aevents, 'duration') || ...
                    ~isnumeric(aevents(j).duration) || ...
                    aevents(j).duration == -1
                if j == 1
                    [aevents.duration] = deal(-1); 
                end                
                aevents(j).duration = size(aevents(j).data, 1) / ...
                    DESIGN_PROPS.analog_sampling_rate;
                warn(['Field "duration" was set to ' ...
                    num2str(aevents(j).duration) ...
                    ' seconds in analog event ' num2str(j) ...
                    ' of channel ' num2str(j)  '.']);
            end
        end
        
        analog(i).events = aevents;
    end
    
    events.analog = analog;
    
    % Digital events
    if ~isfield(events, 'digital') || ~isstruct(events.digital)
        events.digital = struct([]);
        warn('Field "digital" is missing in field "events".');
    end
    digital = events.digital;
    
    % For each digital channel.
    for i = 1:length(digital) 
        if ~isfield(digital, 'infos') || ~isstruct(digital(i).infos)
            warn(['Field "infos" is missing in digital event ' ...
                num2str(i) '.']);
            digital(i).infos = struct();
        end
        
        % Field "description" was called "name" in a previous version.
        if isfield(digital, 'name') && ~isfield(digital, 'description')
            [digital(:).description] = deal(digital(:).name);
            digital = rmfield(digital, 'name'); 
            warn(['Field "name" was renamed to "description" in ' ...
                'digital events.']);
        end      
        
        if ~isfield(digital, 'description') || ...
                ~ischar(digital(i).description)
            error(['Field "description" is missing in digital event ' ...
                num2str(i) '.']);
        end
        
        if ~isfield(digital, 'events') ||~isstruct(digital(i).events)
            error(['Field "events" is missing in digital event ' ...
                num2str(i) '.']);
        end

        devents = digital(i).events;
        
        % For all events in that channel
        for j = 1:length(devents) 
            if ~isfield(devents, 'infos') || ~isstruct(devents(j).infos)
                warn(['Field "infos" is missing in digital event ' ...
                    num2str(j) ' of channel ' num2str(j)  '.']);
                devents(i).infos = struct();
            end

            if ~isfield(devents, 'onset') || ~isnumeric(devents(j).onset)
                error(['Field "onset" is missing in digital event ' ...
                    num2str(j) ' of channel ' num2str(j)  '.']);
            end

            if ~isfield(devents, 'duration') || ...
                    ~isnumeric(devents(j).duration)
                error(['Field "duration" is missing in digital event ' ...
                    num2str(j) ' of channel ' num2str(j)  '.']);
            end
            
            % The field type was missing in a previous design format
            % version.
            default_type = 'digital';
            if ~isfield(devents, 'type') || ~ischar(devents(j).type)
                [devents.type] = deal(default_type);
                warn(['Field "type" was set to default value "' ...
                    default_type '" in digital event channel ' ...
                    num2str(j)  '.']);
            end
            
            % These two fields were missing in previous versions.
            % Relative time points of rising edges in digital event.
            if ~isfield(devents, 'rising') || ...
                    ~isfield(devents, 'falling') || ...
                    (~isempty(devents(j).rising) && ...
                        any(devents(j).rising == -1))
                if j == 1
                    [devents.rising] = deal(-1);
                end
                % We assume a constant high signal.
                devents(j).rising = 0;
                devents(j).falling = devents(j).duration;
                warn(['Fields "rising" and "falling" are missing in ' ...
                    'digital event ' num2str(j) ' of channel ' ...
                    num2str(j)  '. Constant high signal assumed.']);
            end
        end
        
        digital(i).events = devents;
    end
    
    events.digital = digital;
end

function sounds = check_sounds(sounds)
    global DESIGN_FOLDER;
    global DESIGN_PROPS;

    for i = 1:length(sounds) 
        sndData = [];
        
        if ~isfield(sounds, 'infos') || ~isstruct(sounds(i).infos)
            warn(['Field "infos" is missing in sound ' num2str(i) '.']);
            sounds(i).infos = struct();
        end
        
        if ~isfield(sounds, 'type') || ~ischar(sounds(i).type)
            error(['Field "type" is missing in sound ' num2str(i) '.']);
        end
        
        if ~isfield(sounds, 'onset') || ~isnumeric(sounds(i).onset)
            error(['Field "onset" is missing in sound ' num2str(i) '.']);
        end
        
        if ~isfield(sounds, 'filename') 
            error(['Field "filename" is missing in sound ' num2str(i) ...
                '.']);
        end
        
        % In an older version of the design format, the field data was
        % called sound.
        if isfield(sounds, 'sound') && ~isfield(sounds, 'data') 
            [sounds(:).data] = deal(sounds(:).sound);
            sounds = rmfield(sounds, 'sound');
            warn(['Field "sound" was renamed to "data" in ' ...
                'sounds.']);
        end       
        
        if ~isfield(sounds, 'data') 
            error(['Field "data" is missing in sound ' num2str(i) '.']);
        else
            sndData = sounds(i).data;
        end
        
        if ~isempty(sounds(i).filename) && ~isempty(sounds(i).data)
            error(['Either "filename" or "sound" must be set, but not ' ...
                'both; in sound ' num2str(i) '.']);
        end
        
        if ~isempty(sounds(i).filename)
            if ~ischar(sounds(i).filename) 
                error(['Field "filename" must be char array in sound ' ...
                    num2str(i) '.']);
            end
            
            fn = fullfile(DESIGN_FOLDER, sounds(i).filename);
            if ~exist(fn, 'file')
                error(['Could not find sound file: ' fn]);
            else
                [sndData, sr] = audioread(fn);
                assert(sr == DESIGN_PROPS.sound_sampling_rate);
            end
        end
        
        % This field was missing in a previous format version.
        if ~isfield(sounds, 'duration') || ...
                ~isnumeric(sounds(i).duration) || sounds(i).duration == -1
            if i ==1
                [sounds.duration] = deal(-1);
            end
            sndDur = size(sndData, 1) / DESIGN_PROPS.sound_sampling_rate;
            sounds(i).duration = sndDur;
            warn(['Field "duration" was set to ' num2str(sndDur) ...
                ' seconds in sound ' num2str(i) '.']);
        end
    end
end

function structa = check_repeated(structa, ind, name)
    % Some fields are the same for cohorts, groups, sessions and subjects.
    if ~isfield(structa, 'names') || isempty(structa(ind).names)
        error(['Field "names" is missing in ' name ' ' num2str(ind) '.']);
    end

    disp(['Checking ' name ' ' num2str(ind) ' with names: ' ...
        strjoin(structa(ind).names)]);

    if length(structa(ind).names) > 1
        disp(['The following ' name 's share the same design: ' ...
            strjoin(structa(ind).names)]);
    end

    if ~isfield(structa, 'infos') || ~isstruct(structa(ind).infos)
        warn(['Field "infos" is missing in ' name ' ' num2str(ind) '.']);
        structa(ind).infos = struct();
    end
end

function warn(message)
    % Wrapper for method warning.
    global DISP_WARN;
    DISP_WARN = 1;
    
    % Stacktrace is just confusing here.
    warning off backtrace
    
    warning(message);
end

