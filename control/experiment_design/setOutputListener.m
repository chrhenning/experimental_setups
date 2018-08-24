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
    
    % This will be our timer reference when queuing data on the NIDAQ.
    % I.e., we will queue data from d.timeRef until 
    % min(session_duration, d.timeRef + p.continuousWin)
    d.timeRef = 0;
    
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

