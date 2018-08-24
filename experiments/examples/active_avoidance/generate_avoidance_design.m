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
@title           :generate_avoidance_design.m
@author          :be
@contact         :behret@ethz.ch
@created         :05/07/2018
@version         :1.0
%}
function generate_avoidance_design(output_folder)
%GENERATE_AVOIDANCE_DESIGN This function generates a design file for an 
%active avoidance experiment.
%
% The setup is fairly simple. There is a certain number of events per
% session. Each events consists of a sound followed by a shock.
%
% The file additionally implements a digital signal that is 1 for the whole
% duration of the event (sound + shock), that can be used as control signal
% for the shuttle detection box we use in the lab (note, that this box will
% decide on which side of the cage the shock is routed).
%
% Examples:
% >> generate_avoidance_design('C:\Users\Grewe-Lab\Desktop\design_aa');
    addpath(genpath('../../../misc/'));
    addpath(genpath('../../../lib/'));

    if ~isdir(output_folder)
        mkdir(output_folder);
    end
    
    %% Configure design.
    rng(42);
    
    % We design the experiment for only 1 cohort and 1 group.
    num_subjects = 5;
    
    % Number of sessions.
    num_sessions = 8;
    % Length of each session, 
    session_durations = ones(1, num_sessions) * 40 * 60; % in seconds
    
    % Events are sound events only.
    sound_length = 10; % in seconds
    
    num_events_per_session = 50;
    
    shock_duration = 5;
    % Note, this is currently not controlled by the computer, but we put it
    % here for future compatibility.
    shock_intensity = 2e-4; % in A
    
    % Frequency of CS tone.
    cs_frequency = 6000;
    
    sound_sampling_rate = 32000;
    sound_bit_depth = 16;
    
    %% Don't change the code from now on.
    assert(2 * cs_frequency < sound_sampling_rate);
    
    disp(['Generating experiment with ' ...
        num2str(sum(num_subjects(:))) ' subjects.']);
    
    %% Define events.
    % Distribute sound events over course of a session (we don't
    % distinguish between groups.
    event_times = cell(1, num_sessions); % CS start times.
    for i = 1:num_sessions
        event_times{1, i} = distribute_events(session_durations(i), ...
            num_events_per_session, sound_length + shock_duration, 20, ...
            120, 30);
    end
    
    %% Define US Events.
    % Happening after all sound presentations.
    us_events = cell(1, num_sessions);
    for i = 1:num_sessions
        us_events{1, i} = event_times{1, i} + sound_length;
    end
    
    %% Plot design choices.
    fig = figure('Name', 'Basic Design');
    nr = ceil(num_sessions / 3);
    nc = 3;
    
    cols = linspecer(2);

    for i = 1:num_sessions
        xData = 0:1:session_durations(i); % in seconds
        csData = zeros(1, length(xData));
        usData = zeros(1, length(xData));
    
        for j = 1:length(event_times{1, i})
            % Note, that time indices start at 1 not 0.
            s = floor(event_times{1, i}(j)) + 1;
            e = s + ceil(sound_length);
            
            csData(1, s:e) = 1;
        end
        
        for j = 1:length(us_events{1, i})
            % Note, that time indices start at 1 not 0.
            s = floor(us_events{1, i}(j)) + 1;
            e = s + ceil(shock_duration);
            
            usData(1, s:e) = 1;
        end

        csData(csData == 0) = NaN;
        usData(usData == 0) = NaN;
        
        subplot(nr, nc, i);
        p1 = plot(xData, csData(1, :), 'DisplayName', 'CS Sound', ...
            'LineWidth', 5, 'color', cols(1, :));
        hold on;
        p2 = plot(xData, usData(1, :), 'DisplayName', 'US', ...
                'LineWidth', 5, 'color', cols(2, :));
        
        xlabel('Time (s)');
        ylabel('');
        ylim([0.5 1.5]);
        
        legend(fliplr([p1, p2]));

        title(['Session: ', num2str(i)]);
    end
    
    savefig(fig, fullfile(output_folder, 'experiment.fig'));
    
    %% Generate Sound files.
    % Store sounds in a subfolder and use relative paths as identifier.
    rel_sound_folder = 'sounds';
    cs_name = 'cs.wav';
    sound_folder = fullfile( output_folder, rel_sound_folder);
    
    if ~isdir(sound_folder)
        mkdir(sound_folder);
    end
    
    disp(['Sounds are stored in folder: ' sound_folder]);

    % CS sound
    cs_tone = simple_tone(sound_length, cs_frequency, 0.0, 0.02, 1, ...
        sound_sampling_rate);
    
    filename = fullfile(sound_folder, cs_name);
    audiowrite(filename, cs_tone, sound_sampling_rate, ...
        'BitsPerSample', sound_bit_depth, 'Comment', ...
        ['CS tone with frequency: ' num2str(cs_frequency)]);
    disp(['Created sound file ' filename ' with frequency ' ...
        num2str(cs_frequency) '.']); 
   
    %% The exp struct will contain the experimental design.
    exp.properties.sound_bit_depth = sound_bit_depth;
    exp.properties.analog_sampling_rate = sound_sampling_rate;
    exp.properties.sound_sampling_rate = sound_sampling_rate;
    exp.properties.experiment_type = 'AA'; % active avoidance
    
    exp.design = struct();
    
    cohorts = struct();
    cohorts(1).names = {'Cohort'};
    cohorts(1).infos = struct();

    groups = struct();
    groups(1).names = {'Group'};    
    groups(1).infos = struct();
    
    c = 1;
    g = 1;
                 
    sessions = struct();
    for s = 1:num_sessions
        sessions(s).names = {['Session' num2str(s)]};
        sessions(s).infos = struct(); 

        subjects = struct();
        % All subjects within a cohort/group/session are treated 
        % equally.
        names = cell(1, num_subjects(c, g));
        for m = 1:num_subjects(c, g)
            names{m} = ['M' num2str(m)];
        end
        subjects.names = names;
        subjects.infos = struct();
        subjects.duration = session_durations(s);
        
        shocks = struct([]);
        for sck = 1:length(us_events{s})
            shocks(sck).onset = us_events{s}(sck);
            shocks(sck).duration = shock_duration;
            shocks(sck).intensity = shock_intensity;
            % The shock chamber should be dynamic not predefined.
            shocks(sck).channel = -1;
            shocks(sck).rising = [0];
            shocks(sck).falling = [shock_duration];
        end
        subjects.shocks = shocks;

        sounds = struct([]);
        for evt = 1:length(event_times{s})
            fn = fullfile(rel_sound_folder, cs_name);
            freq = cs_frequency;

            sounds(evt).onset = event_times{s}(evt);
            sounds(evt).duration = sound_length;
            sounds(evt).type = 'CS';
            sounds(evt).infos = struct();
            sounds(evt).infos.frequency = freq;

            % We don't use this option. Instead, we store tones
            % externally in files.
            sounds(evt).data = [];
            sounds(evt).filename = fn;
        end
        subjects.sounds = sounds;

        % We don't have dedicated analog events.
        events = struct();
        events.analog = struct([]);
        events.digital = struct([]);
        
        % We need a digital signal, that is on for the whole duration of an
        % event (including sound and shock). This signal will control the
        % external shuttle detection box.).
        events.digital(1).infos = struct();
        events.digital(1).description = ...
            'Control signal for Shuttle Detection Box';
        events.digital(1).events = struct([]);
        for evt = 1:length(event_times{s})
            events.digital(1).events(evt).infos = struct();
            events.digital(1).events(evt).onset = event_times{s}(evt);
            % The plus 1 allows some slack.
            events.digital(1).events(evt).duration = sound_length + ...
                shock_duration + 1;
            events.digital(1).events(evt).type = 'event';
            % Constant 1 event.
            events.digital(1).events(evt).rising = [0];
            events.digital(1).events(evt).falling = [sound_length + ...
                shock_duration];
        end
        
        subjects.events = events;

        sessions(s).subjects = subjects; 
    end
    groups(1).sessions = sessions;    
    cohorts(1).groups = groups;

    exp.design.cohorts = cohorts;
    
    experiment = exp;
    % Store design in file.
    disp('Writing design to file ...');
    save(fullfile(output_folder, 'experiment.mat'), 'experiment', '-v7.3');
    
    % JSON might be good for visualization.
    if true
        expStr = jsonencode(experiment);
        fid = fopen(fullfile(output_folder, 'experiment.json'), 'w');
        fprintf(fid, '%s\n', expStr);
        fclose(fid);
    end
    
    disp(['Experiment stored in folder ', output_folder]);
end