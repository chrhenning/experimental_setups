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
@title           :generate_fc_design_file.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :05/07/2018
@version         :1.0

Here we generate the design file that controls and determines the fear
conditioning experiment.
%}
function generate_fc_design_file(output_folder)
%GENERATE_FC_DESIGN_FILE This function generates a design file for a fear
%conditioning experiment.
%
%   This is an example scipt that generates a simple FC experiment for a
%   lesion study. The study consists of two cohorts (control mice and
%   lesioned mice). Additionally, each cohort is split into two groups, in
%   which CS+ and CS- stimuli are exchanged. Both, CS+ and CS- frequencies
%   are simple tones (single frequencies). In the conditioning session, the
%   CS+ tone is followed by a shock.
%   To show how to use digital events, the design comprises two digital
%   events. One for CS+ sounds and one for CS- sounds. I.e., these event
%   channels are set to 1 if a CS+ resp. CS- tone is played.
%
%   Examples:
%   >> generate_fc_design_file('./design');
    addpath(genpath('../../../misc/'));
    addpath(genpath('../../../lib/'));

    if ~isdir(output_folder)
        mkdir(output_folder);
    end
    
    % Set random seed to assert that different runs of this script lead to
    % the same result.
    rng(42);
    
    %% Configure design.
    %% Parameters of this script.
    num_subjects = 5; 
     
    % Length of each session.
    % Note, number of sessions is implicitly defined by the length of this
    % array.
    session_durations = ones(1,6) * 22 * 60; % in seconds
    
    sound_length = 25; % in seconds
    
    shock_duration = 2;
    % Note, this is currently not controlled by the computer, but we put it
    % here for future compatibility.
    shock_intensity = 6e-4; % in A
    
    % In which session do we pair CS+ with shocks?    
    conditioning_session = 3;
    
    % Frequency of CS+ and CS-
    cs1_freq= 6000; % CS+ for group 1 (CS- group 2)
    cs2_freq = 12000; % CS+ for group 2 (CS- group 1)
    
    sound_sampling_rate = 48000;
    sound_bit_depth = 16;
    
    %% Don't change the code from now on.
    %%%%%%%%%%%%%%
    % DON'T CHANGE
    num_groups = 2; % CS+ and CS- are exchanged.
    num_cohorts = 2; % Control + Lesion  
    %%%%%%%%%%%%%%
    assert(num_groups == 2);
    assert(num_cohorts == 2);
    assert(2 * max([cs1_freq, cs2_freq]) < sound_sampling_rate);
    
    disp(['Generating experiment with ' ...
        num2str(num_groups * num_cohorts * num_subjects) ' subjects.']);
    
    num_sessions = length(session_durations);
    assert(conditioning_session < num_sessions);
    
    %% Define events.
    % Distribute sound events over course of a session (we don't
    % distinguish between groups.
    % I.e., for each session (independent of cohort/group): random start
    % time of each sound event.
    event_times = cell(1, num_sessions);
    for i = 1:num_sessions
        % 12 sound presentations on each days (6 CS-, 6 CS+).
        event_times{1, i} = distribute_events(session_durations(i), ...
            6+6, sound_length, 20, 90, 30);
    end
    
    %% Assign CS+, CS- to events.
    cs_type = cell(1, num_sessions); % CS+ or CS-
    for i = 1:num_sessions
        num_events = length(event_times{1, i});
        % We assume half/half.
        assert(mod(num_events, 2) == 0);
        
        % Define, whether CS+ or CS-.
        types = zeros(1, num_events); % 1 is CS+
        if i <= conditioning_session
            % Alternating tone presentations.
            types(2:2:num_events) = 1;
            cs_type{1, i} = types;
        else
            % First half is CS-, second half is CS+.
            types(num_events/2+1:end) = 1;
            cs_type{1, i} = types;
        end
    end
    
    %% Define US Events.
    % Happening after CS+ presentation in conditioning session.
    us_events = cell(1, num_sessions);
    for i = 1:num_sessions
        if i ~= conditioning_session
            us_events{1, i} = zeros(1, 0);
            continue;
        end

        us_events{1, i} = event_times{1, i}(cs_type{1, i} == 1) ...
            + sound_length;
    end
    
    %% Plot design choices.
    fig = figure('Name', 'Basic Design');
    nr = ceil(num_sessions / 3);
    nc = 3;
    
    cols = linspecer(3);

    for i = 1:num_sessions
        xData = 0:1:session_durations(i); % in seconds
        csmData = zeros(1, length(xData));
        cspData = zeros(1, length(xData)); % Might differ between cohorts
        usData = zeros(1, length(xData));
    
        for j = 1:length(event_times{1, i})
            % Note, that time indices start at 1 not 0.
            s = floor(event_times{1, i}(j)) + 1;
            e = s + ceil(sound_length);
        
            if cs_type{1, i}(j)
                cspData(1, s:e) = 1;
            else
                csmData(1, s:e) = 1;
            end
        end
        
        for j = 1:length(us_events{1, i})
            % Note, that time indices start at 1 not 0.
            s = floor(us_events{1, i}(j)) + 1;
            % FIXME We can't see them in the graph, so we artificially make
            % them longer.
            e = s + ceil(shock_duration) + 4;
            
            usData(1, s:e) = 1;
        end
        
        cspData(cspData == 0) = NaN;
        csmData(csmData == 0) = NaN;
        usData(usData == 0) = NaN;
        
        subplot(nr, nc, i);
        p1 = plot(xData, csmData(1, :), 'DisplayName', 'CS- Sound', ...
            'LineWidth', 5, 'color', cols(1, :));
        hold on;
        p2 = plot(xData, cspData(1, :), 'DisplayName', 'CS+ Sound', ...
            'LineWidth', 5, 'color', cols(2, :));
        
        xlabel('Time (s)');
        ylabel('');
        yticks(gca, []);
        
        if ~isempty(us_events{:, i})
            p3 = plot(xData, usData(1, :), 'DisplayName', 'US', ...
                'LineWidth', 5, 'color', cols(3, :));
            
            legend(fliplr([p1, p2, p3]));
        else             
            legend(fliplr([p1, p2]));
        end
        
        title(['Session: ', num2str(i)]);
    end
    
    savefig(fig, fullfile(output_folder, 'experiment.fig'));
    
    %% Generate Sound files.
    % Store sounds in a subfolder and use relative paths as identifier.
    rel_sound_folder = 'sounds';
    cs1_name = 'cs1.wav';
    cs2_name = 'cs2.wav';
    sound_folder = fullfile( output_folder, rel_sound_folder);
    
    if ~isdir(sound_folder)
        mkdir(sound_folder);
    end
    
    disp(['Sounds are stored in folder: ' sound_folder]);

    % CS 1 sound
    ss = simple_tone(sound_length, cs1_freq, 0.0, 0.02, 1, ...
        sound_sampling_rate);
    filename = fullfile(sound_folder, cs1_name);
    audiowrite(filename, ss, sound_sampling_rate, ...
        'BitsPerSample', sound_bit_depth, 'Comment', ...
        ['CS 1 tone with frequency: ' num2str(cs1_freq)]);
    disp(['Created sound file ' filename ' with frequency ' ...
        num2str(cs1_freq) '.']);

    % CS 2 sound
    ss = simple_tone(sound_length, cs2_freq, 0.0, 0.02, 1, ...
        sound_sampling_rate);
    filename = fullfile(sound_folder, cs2_name);
    audiowrite(filename, ss, sound_sampling_rate, ...
        'BitsPerSample', sound_bit_depth, 'Comment', ...
        ['CS 2 tone with frequency: ' num2str(cs2_freq)]);
    disp(['Created sound file ' filename ' with frequency ' ...
        num2str(cs2_freq) '.']);
    
    %% The exp struct will contain the experimental design.    
    exp.properties.sound_sampling_rate = sound_sampling_rate;
    % We don't define analog events in this experiment anyway.
    exp.properties.analog_sampling_rate = sound_sampling_rate;
    exp.properties.sound_bit_depth = sound_bit_depth;
    exp.properties.experiment_type = 'FC'; % fear conditioning
    
    exp.design = struct();
    
    % Both cohorts have exactly the same design.
    cohorts = struct();
    cohorts(1).names = {'Control', 'Lesion'};
    c = 1;
    cohorts(c).infos = struct();

    groups = struct();
    groups(1).names = {'A'};
    groups(2).names = {'B'};

    for g = 1:num_groups
        groups(g).infos = struct();

        % CS+ and CS- differ between groups.
        if g == 1
            csp_file = fullfile(rel_sound_folder, cs1_name);
            csp_freq = cs1_freq;
            csm_file = fullfile(rel_sound_folder, cs2_name);
            csm_freq = cs2_freq;
        else
            csp_file = fullfile(rel_sound_folder, cs2_name);
            csp_freq = cs2_freq;
            csm_file = fullfile(rel_sound_folder, cs1_name);
            csm_freq = cs1_freq;
        end                    

        sessions = struct();
        for s = 1:num_sessions
            sessions(s).names = {['Session' num2str(s)]};
            sessions(s).infos = struct(); 
            if s < conditioning_session
                sessions(s).infos.type = 'Habituation';
            elseif conditioning_session == s
                sessions(s).infos.type = 'Conditioning';
            else
                sessions(s).infos.type = 'Readout';
            end

            subjects = struct();
            % All subjects within a cohort/group/session are treated 
            % equally.
            names = cell(1, num_subjects);
            for m = 1:num_subjects
                names{m} = ['M' num2str(m)];
            end
            subjects.names = names;
            subjects.infos = struct();
            subjects.duration = session_durations(s);
            
            shocks = struct([]);
            if conditioning_session == s
                assert(~isempty(us_events{s}));
                for sck = 1:length(us_events{s})
                    shocks(sck).onset = us_events{s}(sck);
                    shocks(sck).duration = shock_duration;
                    shocks(sck).intensity = shock_intensity;
                    % This option is only meaningful for active
                    % avoidance experiments.
                    shocks(sck).channel = -1;
                    
                    % Rising and falling edges of the digital event. We
                    % want to have constant high signal.
                    shocks(sck).rising = [0];
                    shocks(sck).falling = [shock_duration];
                end
            else
                assert(isempty(us_events{s}));
            end
            subjects.shocks = shocks;

            sounds = struct([]);
            for snd = 1:length(event_times{s})
                et = cs_type{s}(snd);

                if et
                    % CS+ events.
                    fn = csp_file;
                    sounds(snd).type = 'CS+';
                    freq = csp_freq;
                else
                    % CS- events.
                    fn = csm_file;
                    sounds(snd).type = 'CS-';
                    freq = csm_freq;
                end

                sounds(snd).onset = event_times{s}(snd);
                sounds(snd).duration = sound_length;

                sounds(snd).infos = struct();
                sounds(snd).infos.frequency = freq;

                % We don't use this option. Instead, we store tones
                % externally in files.
                sounds(snd).data = [];
                sounds(snd).filename = fn;
            end
            subjects.sounds = sounds;

            events = struct();
            events.analog = struct([]);
            events.digital = struct([]);

            % We have two digital events (one for CS+ and one for CS-.
            events.digital(1).infos = struct();
            events.digital(1).description = 'CS+ Sounds';
            events.digital(1).events = struct([]);
            
            events.digital(2).infos = struct();
            events.digital(2).description = 'CS- Sounds';
            events.digital(2).events = struct([]);

            csp_ind = 0;
            csm_ind = 0;
            for evt = 1:length(event_times{s})
                et = cs_type{s}(evt);
                if et
                    type = 'CS+';
                    csp_ind = csp_ind + 1;
                    ind = csp_ind;
                else
                    type = 'CS-';
                    csm_ind = csm_ind + 1;
                    ind = csm_ind;
                end
                et = et + 1; % Convert to index.
                
                events.digital(et).events(ind).infos = struct();
                events.digital(et).events(ind).onset = event_times{s}(evt);
                events.digital(et).events(ind).duration = sound_length;
                events.digital(et).events(ind).type = type;
                
                % Constant 1 event.
                events.digital(et).events(ind).rising = [0];
                events.digital(et).events(ind).falling = [sound_length];
            end
            subjects.events = events;

            sessions(s).subjects = subjects; 
        end
        groups(g).sessions = sessions;
    end
    cohorts(c).groups = groups;

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