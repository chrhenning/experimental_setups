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
@title           :setOutputListener.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/02/2018
@version         :1.0

Prepare output channels before queuing data on them.
%}


function session = setOutputListener(session)
%SETOUTPUTLISTENER Setup output channels/
%
% We assign a callback for queuing events (if continuous mode is used) and
% assign temporary output filenames (where we store the output design of
% all output channels).
    p = session.UserData.p;
    d = session.UserData.d;
    
    %% Some variables that will be modified during the session.
    % This will be our timer reference when queuing data on the NIDAQ.
    % I.e., we will queue data from d.timeRef until 
    % min(session_duration, d.timeRef + p.continuousWin)
    d.timeRef = 0;
    % This flag will tell use, whether we are currently pausing the
    % session.
    d.sessionPaused = 0;
    % This will be an array of size n x 6, where n is the number of output
    % windows pushed to the NIDAQ (including paused windows).
    % The four numbers per row will be: start of win (in sec), end of win
    % (in sec), num steps in win, cumulative number of steps of all wins 
    % (including this one), cumulative number of steps of all wins except
    % paused once and whether it is a pausing window.
    % This information can later be used, to handle pauses outside the data
    % queuing function.
    % Note, that if paused, the time windows have no meaning.
    d.outputDataWindows = [];
    % The total number of time frames pushed to the NIDAQ so far (including
    % paused windows).
    % assert(sum(outputDataWindows(:,3)) == totalStepsPushedSoFar);
    d.totalStepsPushedSoFar = 0;
    % The total number of time frames pushed to the NIDAQ, when the session
    % wasn't paused.
    % assert(sum(outputDataWindows(outputDataWindows(:, 6) == 0, 3)) ...
    %        == recStepsPushedSoFar); 
    d.recStepsPushedSoFar = 0;
    % The number of windows pushed to the NIDAQ after the last actual data
    % window has been send (i.e., while waiting for the input listener to
    % end the session.
    d.zeroCyclesAfterRec = 0;
    
    tempOutputFileNames = cell(1, d.numRecs);
    for i = 1:d.numRecs
        tempOutputFileNames{i} = fullfile(d.expDir{i}, 'output_data.bin');
    end
    d.tempOutputFileNames = tempOutputFileNames;
    
    if ~p.useBulkMode
        listVar = addlistener(session, 'DataRequired', @queueOutputDesign);
        d.outputListener = listVar;
    end
    
    d.stopSession = false;
    
    session.UserData.d = d;
end

