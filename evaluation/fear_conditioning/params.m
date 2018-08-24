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
@title           :params.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/08/2018
@version         :1.0

There are three types of conditional event sources according to the design 
file: analog, digital and sound events. Each of these events has a
specified 'type' attribute (e.g., type = 'CS+'). Note, that shocks don't
have a type attribute. The evaluation software is interested in this 'type'
attribute, i.e., it does not distinguish between a 'CS+' analog, digital or 
sound event. Therefore, it is usually wise to give all events a different
'type' attribute. Later, one can merge or exclude events based on their 
source and type attribute.

Note, overlapping events with the same type are merged (e.g., concurrent
digital and sound event with type 'CS+').

Note, events do not include US events (shocks according to the design
file).
%}

function p = params()
%PARAMS Contains parameters needed to evaluate a fear conditioning
%experiment.

    %%%%%%%%%%%
    % General %
    %%%%%%%%%%%

    % Where is the data, recorded during the experiments, stored?
    % This corresponds to the option "p.rootDir" in the params file of the
    % control software.
    p.dataDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'recordings');
    
    % Where are the results of the feezing detection stored?
    % Note, the freezing detection software is not part of this
    % repostitory.
    p.freezingDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'freezing'); 
    
    % Where is the experiment design file stored?
    p.designDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'design'); 
    
    % Where to store the outputs of the evaluation?
    p.resultDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'evaluation'); 
    
    % Delete previous results.
    % If resultDir is already existing, then we will delete it, if this
    % option is true, otherwise the process is aborted.
    p.deletePrevResults = true;

    % One might wish to exclude recordings, in case something went wrong
    % during the recording.
    % This is an mx4 matrix. Each row represents an recording (cohort,
    % group, session, subject).
    p.excludeRecordings = [];
    
    %%%%%%%%%%
    % Sounds %
    %%%%%%%%%%
    
    % FIXME Timing correction does not work reliably for huge differences
    % in sound and NIDAQ sampling rates. Might require manual tuning.
    
    % TODO The correction of recordings should be placed in an addtitional
    % post-processing pipeline, as it is helpful for all experiments.
    
    % If sounds have been recorded (i.e., played via sound card and
    % recorded via DAQ analog input channels), then one should compare 
    % their timing with what is stated in the design.
    % Note, this option is not considered if sounds haven't been played via
    % the sound card.
    p.correctSoundsIfRecorded = true;
    % We assume that the input channel order is consistent throughout the
    % experiment.
    % What is the index (within the array of input channel indices, i.e.,
    % p.inputChannels) of the channel that recorded the left sound channel?
    % Assign -1 if channel was not recorded.
    % Note, in case of parallel recordings, the indices specify the column
    % index, e.g., p.inputChannels = [0, 1; 2, 3]: For both recordings, the
    % first channel in the row is the left one, i.e., 
    % p.leftSoundInputChannelIndex = 1 for both.
    p.leftSoundInputChannelIndex = 1;
    p.rightSoundInputChannelIndex = 2;
    
    %%%%%%%%%%%%%%%%%%%%%%
    % Evaluation General %
    %%%%%%%%%%%%%%%%%%%%%%
    
    % Time resolution of evaluation.
    % The NIDAQ rate is typically much higher than the measured behavioral
    % response (often to realize certain analog sampling rates). Here, the
    % user can specify what the time resolution should be at which we
    % compare the behavioral response to occurred events (e.g., the time
    % resolution of the stored plots).
    p.evalRate = 20; % in Hz
    
    % Merge event types. 
    % In case you want to merge several event types in the design file into
    % a new event type, that is considered during the evaluation.
    % This option is a cell array of size m x 2, where m is the number of
    % new "merged" event types. The first column is a cell array of char
    % arrays, denoting event types from the design file that should be
    % merged. The second column is the name of the new event type.
    % The merge process will affect all event sources. 
    % Example:
    % p.mergeEventTypes = { ...
    %     {'CS+ 1', 'CS+ 2'}, 'CS+'; ...
    %     {'CS- 1', 'CS- 2'}, 'CS-' ...
    % };
    % p.mergeEventTypes = { ...
    %    {'CS+ Light'}, 'CS+'
    % };

    % Use the new event type names for the remaining params file.
    p.mergeEventTypes = { };

    % Exclude events.
    % One may exclude events, if they should not be subject to a behavior
    % evaluation. 
    % This options is a cell array of size m x 2, where m is the number of
    % "excluded" events. The first column specifies the event source, the
    % second specifies the event type.
    % Example:
    % p.excludeEvents = { ...
    %    'digital', 'CS+'; ...
    %    'analog', 'CS+' ...
    % };
    p.excludeEvents = { };
    
    % List of conditioned event types, that the subject should freeze to,
    % I.e., the CS+ event types. All other event types are considered as
    % CS-.
    % Note, the property event type is taken from the design file.
    % Example:
    % p.reinforcedEventTypes = {'CS+ low', 'CS+ high'};
    p.reinforcedEventTypes = {'CS+'};
    
    %%%%%%%%%%%%%%%%%%%%%
    % Freezing Behavior %
    %%%%%%%%%%%%%%%%%%%%%
    
    % Some evaluation measures only look at event presentations. The window
    % determines how many seconds before and after the event presentation
    % are additionally considered around the event presentation for these 
    % measures.
    p.eventPresentationWindow = 5; % in seconds
    
    %%%%%%%%%%%%%%%%
    % Other Params %
    %%%%%%%%%%%%%%%%
    
    % The conjoined plots are very time consuming when having a high
    % temporal resolution. Therefore, you can specify a custom temporal
    % resolutions for these plots here.
    p.conjoinedPlotsRate = 0.1; % in Hz
end

