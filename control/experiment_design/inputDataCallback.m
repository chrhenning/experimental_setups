% Copyright 2018 Christian Henning, Rik Ubaghs
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
@title           :inputDataCallback.m
@author          :ch, ru 
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0
%}

function inputDataCallback(src, evt)
%INPUTDATACALLBACK Callback for input channel listener.
%   INPUTDATACALLBACK(src, evt)
%
%   Add the time stamps and the data values to the temporary input data
%   file of each recording. If size(p.inputChannel, 1) is 1, then all
%   reacordings get all the data. If it is numRecs, then each gets data
%   from different channels (note that other options are not allowed.

    p = src.UserData.p;
    d = src.UserData.d;

    % TriggerTime is a timestamp computed by datenum(datetime('now'))
    % everytime the acqusition is triggered by startBack-/Foreground. 
    % Note, we only call startBack-/Foreground once.
    if isfield(src.UserData, 'triggerTime')
        % FIXME there should be no assertions in the code.
        assert(src.UserData.triggerTime == evt.TriggerTime);
    else
        d.recView.setRecStartTime(evt.TriggerTime, src);
    end
    src.UserData.triggerTime = evt.TriggerTime;

    % This assertion cannot trigger, as this was tested while
    % preprocessing the parameters.
    assert(size(p.inputChannel, 1) == 1 || ...
        size(p.inputChannel, 1) == d.numRecs);
    
    for i = 1:d.numRecs
        filepath = d.tempInputRawFileNames{i};
        
        if size(p.inputChannel, 1) == 1
            inputData = evt.Data;
        else
            inputData = evt.Data(:, d.channelInds.input(i, :));
        end

        data = [evt.TimeStamps, inputData]';
        
        fid = fopen(filepath, 'a');
        fwrite(fid, data, 'double');
        fclose(fid);
        
        % We don't wanna write input data, that was gathered during pauses.
        % That is why we need to filter the inputData and timestamps before
        % writing them into the file.
        if p.correctRecordedInputs && ~p.useBulkMode
            data = correctTime(src, evt.TimeStamps, inputData);
            
            filepath = d.tempInputFileNames{i};
            fid = fopen(filepath, 'a');
            fwrite(fid, data, 'double');
            fclose(fid);
        end
    end
    
    % Check, whether all the data of this recording has been read so far
    % and we can interrupt the contiuous mode.
    if ~p.useBulkMode
        lastTS = evt.TimeStamps(end);
        wins = src.UserData.d.outputDataWindows;
        if ~isempty(wins)
            % How much data has been pushed to the NIDAQ so far?
            pushedDur = wins(end, 5) / src.Rate; 
            if pushedDur < (src.UserData.d.duration - 0.001)
                % Full recording has not been pushed to the NIDAQ yet.
                return;
            end

            % We take the last unpaused window, as the windows appended to
            % the session, when all data has been pushed to the NIDAQ, are
            % paused windows.
            winInd = find(wins(:, 6) == 0, 1, 'last');
            
            pausedSteps = wins(winInd, 4) - wins(winInd, 5);
            pausedSecs = pausedSteps / src.Rate; 
            lastTS = lastTS - pausedSecs;
        end
        
        lastTS = lastTS - 1/src.Rate;
        
        if lastTS >= src.UserData.d.duration 
            % We can safely end the session.
            src.stop();
        end
    end
end

function data = correctTime(session, timeStamps, inputData)
% CORRECTTIME Since there might be pauses during the session, we don't
% wanna write this paused data into the written binary files. This function
% will correct the timestamps (to make them look as there were no pauses)
% and makes sure that no input data (recorded during a pause) makes it to
% the output file.
%
% Args:
% - session: The current NIDAQ session.
% - timeStamps: The timestamps delivered for the current input callback.
% - inputData: The input data recorded and delivered to the current input
%   callback.
%
% Returns:
% The data that can be written to the binary output file. I.e. we
% concatenate, the corrected timestamps and the input data along the column
% axes and then transpose this matrix (such that rows represent channels.
%    -> data = [correctedTimeStamps, correctedInputData]';\
    global inputDataCorrectionFailed;
    logger = log4m.getLogger();

    wins = session.UserData.d.outputDataWindows;
    if isempty(wins)
       % We cannot correct the data yet. Though, that should be no
       % problem, as the first window is always no pause.
       return;
    end
    
    numStepsStart = floor(timeStamps(1) * session.Rate); 
    
    startSteps = [0; wins(1:end-1, 4)];
    % In which window is the first timestamp?
    currWinInd = find(numStepsStart >= startSteps & ...
        numStepsStart < wins(:, 4), 1, 'last');
    
    % This should not happen, as we
    if isempty(currWinInd)
        inputDataCorrectionFailed = 1;
        logger.error('inputDataCallback', ['Could not find window for ' ...
            'current time stamp.']);
        data = [timeStamps, inputData]';
        return;
    end
    
    % First timestamp in current window.
    fi = 1;
    
    while 1
        currWinEnd = wins(currWinInd, 4) / session.Rate; 
        % Last timestamp in current window.
        li = find(timeStamps < currWinEnd, 1, 'last');

        % How many paused steps happened so far?
        pausedSteps = wins(currWinInd, 4) - wins(currWinInd, 5);
        pausedSecs = pausedSteps / session.Rate; 

        % Subtract the seconds, that were paused so far from the timesteps.
        % Note, the timestamps might become negative, if the current window
        % is paused as well. However, as these timestamps would be within a 
        % pause, they are not writte into a file.
        timeStamps(fi:li) = timeStamps(fi:li) - pausedSecs;
        
        % If current window is a pause, we don't wanna write this data into
        % a file.
        if wins(currWinInd, 6) == 1
            inds = true(numel(timeStamps), 1);
            inds(fi:li) = 0;
            timeStamps = timeStamps(inds);
            inputData = inputData(:, inds);
            
            fi = fi - 1;
            li = fi;
        end
    
        if li >= numel(timeStamps)
            break;
        else
            currWinInd = currWinInd + 1;
            fi = li + 1;
            
            % Should not happen.
            if currWinInd > size(wins, 1)
                inputDataCorrectionFailed = 1;
                logger.error('inputDataCallback', ['Could not find ' ...
                    'window for current time stamp.']);
                data = [timeStamps, inputData]';
                return;
            end  
        end
    end

    data = [timeStamps, inputData]';
end

