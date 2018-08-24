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
@title           :createSimpleDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/31/2018
@version         :1.0

Generate a simple design file fore each recording.

Note, if one wants to reuse the design file later, one has to change the
parametrization in the params file. Disregarding the current configs, the
generated design file will only contain the experimental design for a
single recording, which can be indexed by:
    p.cohort = 1;
    p.session = 1;
    p.group = 1;
    p.subject = 1;
%}

function dataObj = createSimpleDesign(dataObj)
%CREATESIMPLEDESIGN Auto generate a design folder according to the specs
%made in the control params file.
    p = dataObj.p;
    d = dataObj.d;

    exp.properties.sound_sampling_rate = p.sdSamplingRate;
    exp.properties.analog_sampling_rate = p.sdSamplingRate;
    exp.properties.sound_bit_depth = p.sdBitDepth;
    exp.properties.experiment_type = p.sdExpType;
    
    d.properties = exp.properties;
    d.subjects = cell(1, d.numRecs);
    % All recordings must have the same length.
    assert(length(p.sdDuration) == 1);
    d.duration = p.sdDuration;
    
    exp.design = struct();
    
    for i = 1:d.numRecs
        designDir = fullfile(d.expDir{i}, 'auto_generated_design');
        mkdir(designDir);
        relSoundDir = 'sounds';
        soundDir = fullfile(designDir, relSoundDir);
        mkdir(soundDir);
        
        cohorts = struct();
        cohorts.infos = struct();
        cohorts.names = {['Cohort' num2str(p.cohort)]};
        
        groups = struct();
        groups.infos = struct();
        groups.names = {['Group' num2str(p.group)]};
        
        sessions = struct();
        sessions.infos = struct();
        sessions.names = {['Session' num2str(p.session)]};
        
        subjects = struct();
        subjects.infos = struct();
        subjects.names = {['Subject' num2str(p.subject)]};
        subjects.duration = p.sdDuration;
        
        shocks = struct([]);
        for s = 1:size(p.sdShockOnsets, 2)
            shocks(s).onset = p.sdShockOnsets(i, s);
            shocks(s).duration = p.sdShockDuration;
            shocks(s).intensity = p.sdShockIntensities(i, s);
            shocks(s).channel = p.sdShockChannels(i, s);
            shocks(s).rising = 0;
            shocks(s).falling = p.sdShockDuration;
        end
        subjects.shocks = shocks;
        
        sounds = struct([]);
        for s = 1:size(p.sdSoundOnsets, 2)
            sounds(s).infos = struct();
            sounds(s).type = p.sdSoundTypes{i, s};
            sounds(s).onset = p.sdSoundOnsets(i, s);
            sounds(s).duration = p.sdSoundDuration;
            sounds(s).data = [];
            
            freq = p.sdSoundFreq(i, s);
            tone = simple_tone(p.sdSoundDuration, freq, 0, ...
                p.sdSoundDuration/20, 1, p.sdSamplingRate);
            % A tone should be fully defined by its frequency. I.e., all
            % tones have the same length in auto generated designs.
            assert(length(p.sdSoundDuration) == 1);
            relTonePath = fullfile(relSoundDir, ...
                ['sound_' num2str(freq) '.wav']);
            tonePath = fullfile(designDir, relTonePath);
            if exist(tonePath, 'file') ~= 2
                audiowrite(tonePath, tone, p.sdSamplingRate, ...
                    'BitsPerSample', p.sdBitDepth);
            end
            sounds(s).filename = relTonePath;
        end
        subjects.sounds = sounds;
        
        events = struct();
        events.analog = struct([]);
        events.digital = struct([]);
        subjects.events = events;
        
        sessions.subjects = subjects; 
        groups.sessions = sessions;
        cohorts.groups = groups;
        
        experiment = exp;
        experiment.design.cohorts = cohorts;
        
        save(fullfile(designDir, 'experiment.mat'), 'experiment', '-v7.3');
        
        % Read just created design file.
        subject = RecordingDesign.toClassObject(designDir, 1, 1, 1, 1);
        
        d.subjects{i} = subject;
    end
    
    dataObj.d = d;
end

