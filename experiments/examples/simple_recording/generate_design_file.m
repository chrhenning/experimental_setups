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
@title           :generate_design_file.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :08/10/2018
@version         :1.0

Here we generate the design file that describes the structure of an 
experiment (in terms of "number of subjects/sessions/..."), but does not
define any stimuli or events that are presented during a recording.
%}
function generate_design_file(output_folder)
%GENERATE_DESIGN_FILE This script generates a design file with no stimuli
%defined per recording.
%
%   The design file simply defines the structure of the recording.
%   Therefore the user can only configure the number of cohorts, groups,
%   sessions and subjects as well as the length of each session.
%
%   Examples:
%   >> generate_design_file('./design');
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
    num_cohorts = 2;
    num_groups = 2;
    % Number of subjects per cohort/group.
    % Note, this is a matrix, where the number of rows is equal to the
    % number of cohorts and the number of columns is equal to the number of
    % groups.
    % Each element of this matrix specifies the number of subjects in the
    % corresponding cohort+group.
    % You can also specify a single number, if the number is the same for 
    % all cohorts/groups.
    num_subjects_per_cg = 5; 
     
    % Length of each session.
    % Note, number of sessions is implicitly defined by the length of this
    % array.
    session_durations = ones(1,6) * 22 * 60; % in seconds
    
    %% Don't change the code from now on.
    if numel(num_subjects_per_cg) == 1
        num_subjects_per_cg = repmat(num_subjects_per_cg, num_cohorts, ...
            num_groups);
    end
    assert(all(size(num_subjects_per_cg) == [num_cohorts, num_groups]));
    
    disp(['Generating experiment with ' ...
        num2str(sum(num_subjects_per_cg)) ' subjects.']);
    disp(['There will be ' num2str(num_cohorts) ' cohorts and ' ...
        num2str(num_groups) ' groups in this experiment.']);
    
    num_sessions = length(session_durations);
    
    %% The exp struct will contain the experimental design.    
    % Just set some default values.
    exp.properties.sound_sampling_rate = 48000;
    exp.properties.analog_sampling_rate = 48000;
    exp.properties.sound_bit_depth = 16;
    exp.properties.experiment_type = 'UN'; % unknown
    
    exp.design = struct();
    
    cohorts = struct();
    for c = 1:num_cohorts
        cohorts(c).names = {['Cohort' num2str(c)]};
        cohorts(c).infos = struct();

        groups = struct();

        for g = 1:num_groups
            groups(g).names =  {['Group' num2str(g)]};
            groups(g).infos = struct();               

            sessions = struct();
            for s = 1:num_sessions
                sessions(s).names = {['Session' num2str(s)]};
                sessions(s).infos = struct(); 

                subjects = struct();
                % All subjects within a cohort/group/session are treated 
                % equally.
                num_subjects = num_subjects_per_cg(c, g);
                names = cell(1, num_subjects);
                for m = 1:num_subjects
                    names{m} = ['M' num2str(m)];
                end
                subjects.names = names;
                subjects.infos = struct();
                subjects.duration = session_durations(s);
                
                disp(['Generating recording for cohort ' num2str(c) ...
                    ', group ' num2str(g) ', session ' num2str(s) ...
                    ' with ' num2str(num_subjects) ' subjects and of ' ...
                    'length ' num2str(subjects.duration/60) ' min.']);

                shocks = struct([]);
                subjects.shocks = shocks;

                sounds = struct([]);
                subjects.sounds = sounds;

                events = struct();
                events.analog = struct([]);
                events.digital = struct([]);

                subjects.events = events;

                sessions(s).subjects = subjects; 
            end
            groups(g).sessions = sessions;
        end
        cohorts(c).groups = groups;
    end

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