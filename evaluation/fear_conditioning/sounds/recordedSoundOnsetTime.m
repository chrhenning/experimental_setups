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
@title           :recordedSoundOnsetTime.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/08/2018
@version         :1.0

Find the onset times of played sound in recorded input channels of a DAQ
board.
%}

function onsetTimes = recordedSoundOnsetTime( leftChannel, ...
    rightChannel, recObj, designProperties, ...
    inputRecordings, daqRate, relTimestamps)
%RECORDEDSOUNDONSETTIME Find the onset times of sound presentations in DAQ
%input channel recordings.
%
%   FIXME This method uses several fixed hyperparameters whereas the
%   similarity threshold should be the only severe one.
    logger = log4m.getLogger();

    assert(leftChannel ~= -1 || rightChannel ~= -1);
    if leftChannel == -1
        leftChannel = rightChannel;
    elseif rightChannel == -1
        rightChannel = leftChannel;
    end
    
    %% Compute trace of sound candidates from recorded sound.
    sr = designProperties.sound_sampling_rate;
    % Squared recording.
    sq_rec = (inputRecordings(leftChannel, :) + ...
        inputRecordings(rightChannel, :)).^2;
    % Smoothing window.
    sw = 0.01 * daqRate;
    sm_rec = smooth(sq_rec, sw).';
    
    % Now, we can threshold the smoothed recordings to get a binary trace.
    sound_on_off = sm_rec > 1e-3;
    
    % Now we have the onsets of all individual sounds, however a single CS
    % presentation might consist of several sounds.
    tempOnsetIndices = find(diff(sound_on_off) == 1) + 1;
    if sound_on_off(1) == 1
        tempOnsetIndices = [1, tempOnsetIndices];
    end
    
    %% Compare trace to actual sounds that should occur.
    % We do pattern matching of the tresholded traces.
    onsetIndices = zeros(1, recObj.numSounds());
    sooLen = length(sound_on_off);
    ind = 1;
    for s = 1:recObj.numSounds()
        soundDesign = recObj.getSound(s);
        soundData = soundDesign.data;
        slen = soundDesign.duration;
        
        % Compute a pattern of the sound that can be matched with the
        % recording.
        if size(soundData, 2) == 2
            sq_sound = (soundData(:, 1) + soundData(:, 2)).^2;
        else
            sq_sound = soundData(:, 1).^2;
        end
        sound_pattern_raw = interp1(0:1/sr:slen-1/sr, sq_sound, ...
            0:1/daqRate:slen, 'linear', 'extrap');
        sound_pattern_sm = smooth(sound_pattern_raw, sw).';
        sound_pattern = sound_pattern_sm > 1e-3;
        
        % Try to find matching. Usually, there should be no iterations
        % necessary, if no substantial noise is in the recording.
        while ind <= length(tempOnsetIndices)
            sind = tempOnsetIndices(ind);
            send = sind + min(sooLen, slen * daqRate);
            similarity = norm(sound_pattern - sound_on_off(1, sind:send));

            % FIXME fixed threshold might not always work.
            if similarity < 115
                break;
            end
            
            logger.warn('recordedSoundOnsetTime', ['Onset of recorded ' ...
                'sound is ambiguous. Similarity of current candidate ' ...
                'to actual sound waveform is: ' num2str(similarity) '.']);
            
            ind = ind + 1;
        end
        
        onsetIndices(s) = tempOnsetIndices(ind); 
        
        % We assume non-overlapping sounds.
        ind = find(tempOnsetIndices > send, 1);
    end
    
    assert(length(onsetIndices) == recObj.numSounds());
    
    onsetTimes = relTimestamps(onsetIndices);
    
%     figure
%     xData = (1:length(sound_on_off))/daqRate;
%     plot(xData, sound_on_off);
%     hold on
%     scatter(tempOnsetIndices/daqRate, ones(1, length(tempOnsetIndices)));
%     plot(xData, inputRecordings(leftChannel, :))
%     scatter(onsetTimes, ones(1, length(onsetTimes)));
end

