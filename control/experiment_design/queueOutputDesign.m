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
@title           :queueOutputDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/02/2018
@version         :1.0

FIXME this function is very memory inefficient.
%}
function queueOutputDesign(session, ~)
%QUEUEOUTPUTDATA Control the queuing of data for output channels.
    
    logger = log4m.getLogger();

    p = session.UserData.p;
    d = session.UserData.d;
    
    if d.duration <= d.timeRef
        % FIXME we have to explicitly stop the continuous mode. We cannot
        % run "session.stop();" as this would also stop the processing of
        % the data that is still on the NIDAQ!
        % As a quick fix, we simply send only zeros to the NIDAQ and stop
        % it, when this method is called the next time.
        if d.stopSession
            session.stop();
        else
            session.UserData.d.stopSession = true;
            numOutputChannels = length(session.Channels) - ...
                numel(p.inputChannel);
            session.queueOutputData(zeros( ...
                floor(p.continuousWin * session.Rate), numOutputChannels));
        end

        return;
    end
    
    startTime = d.timeRef;
    if p.useBulkMode
        assert(startTime == 0);
        endTime = d.duration;
    else
        endTime = min(d.duration, startTime + p.continuousWin);
    end
    
    numSteps = floor((endTime - startTime) * session.Rate);
    numStepsDesired = (endTime - startTime) * session.Rate;
    
    if numSteps ~= numStepsDesired && startTime == 0
        logger.warn('queueOutputData', ['NIDAQ rate, duration of ' ...
            'recording and/or "p.continuousWin" does not allow  ' ...
            'perfect time discretization.']);
    end
    
    data2Queue = [];
    
    session.UserData.d = d;
    
    triggerDesign = getTriggerDesign(session, startTime, numSteps);
    data2Queue = prepareData4Queue(session, data2Queue, triggerDesign, ...
        'trigger', endTime);

    shockDesign = getShockDesign(session, startTime, numSteps);
    data2Queue = prepareData4Queue(session, data2Queue, shockDesign, ...
        'shock', endTime);
    
    if ~p.useSoundCard
        soundDesign = getSoundDesign(session, startTime, numSteps);
        data2Queue = prepareData4Queue(session, data2Queue, ...
            soundDesign, 'sound', endTime);
    end
    
    seventDesign = getSoundEventDesign(session, startTime, numSteps);
    data2Queue = prepareData4Queue(session, data2Queue, seventDesign, ...
        'sevent', endTime);
    
    digitalDesign = getDigitalDesign(session, startTime, numSteps);
    data2Queue = prepareData4Queue(session, data2Queue, digitalDesign, ...
        'digital', endTime);
    
    analogDesign = getAnalogDesign(session, startTime, numSteps);
    data2Queue = prepareData4Queue(session, data2Queue, analogDesign, ...
        'analog', endTime);
    
    %d = session.UserData.d;
    
    % Write designs to file.
    for i = 1:d.numRecs
        filepath = d.tempOutputFileNames{i};
        
        triggerData = [];
        if size(p.triggerChannel, 1) == 1
            triggerData = squeeze(triggerDesign);
        elseif size(p.triggerChannel, 1) == d.numRecs
            triggerData = squeeze(triggerDesign(:, i, :));
        end
        
        shockData = [];
        if size(p.shockChannel, 1) == 1
            shockData = squeeze(shockDesign);
        elseif size(p.shockChannel, 1) == d.numRecs
            shockData = squeeze(shockDesign(:, i, :));
        end
        
        soundData = [];
        if ~p.useSoundCard
            if size(p.soundChannel, 1) == 1
                soundData = squeeze(soundDesign);
            elseif size(p.soundChannel, 1) == d.numRecs
                soundData = squeeze(soundDesign(:, i, :));
            end
        end
        
        seventData = [];
        if size(p.soundEventChannel, 1) == 1
            seventData = squeeze(seventDesign);
        elseif size(p.soundEventChannel, 1) == d.numRecs
            seventData = squeeze(seventDesign(:, i, :));
        end
        
        digitalData = [];
        if size(p.digitalChannel, 1) == 1
            digitalData = squeeze(digitalDesign);
        elseif size(p.digitalChannel, 1) == d.numRecs
            digitalData = squeeze(digitalDesign(:, i, :));
        end
        
        analogData = [];
        if size(p.analogChannel, 1) == 1
            analogData = squeeze(analogDesign);
        elseif size(p.analogChannel, 1) == d.numRecs
            analogData = squeeze(analogDesign(:, i, :));
        end

        data = [triggerData, shockData, soundData, seventData, ...
            digitalData, analogData]';

        fid = fopen(filepath,'a');
        fwrite(fid, data, 'double');
        fclose(fid);
    end
    
    logger.debug('queueOutputData', ['Queueing output data for time ' ...
        'frame [' num2str(startTime) 's, ' num2str(endTime) 's].']);
    session.queueOutputData(data2Queue);
    
    d.timeRef = endTime;
    session.UserData.d = d;
end

function queueData = prepareData4Queue(session, queueData, design, ...
    ident, endTime)
%PREPAREDATA4QUEUE Process data such that it can be queued onto the NIDAQ.
%
%   The preparation process includes adding the data to the data, that is 
%   already prepared to be flushed onto the queue.
%
%   We assume that the function is called in the same order for the
%   different channels as the channels have been created in the method
%   setupChannels.m. Therefore, there is an assert in the code.
    p = session.UserData.p;
    d = session.UserData.d;
    
    % Make sure, that output channels are reset to zero after experiment.
    if endTime >= d.duration
    	design(end, :, :) = 0;
    end
    
    % Rearrange designs to fit channel indices.
    channelInd = numel(p.inputChannel) + 1 + size(queueData, 2);
    
    for i = 1:size(design, 2)
        for j = 1:size(design, 3)
            idx = d.channelInds.(ident)(i, j);
            assert(idx == channelInd);
            channelInd = channelInd + 1;
            
            queueData = [queueData, design(:, i, j)];
        end
    end
end

