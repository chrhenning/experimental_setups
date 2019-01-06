% Copyright 2018 Rik Ubaghs, Christian Henning
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
@title           :setInputListener.m
@author          :ru, ch
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0
%}

function session = setInputListener(session)
%SETINPUTLISTENER Setup listener for input channels.
%   session = SETINPUTLISTENER(session)

    p = session.UserData.p;
    d = session.UserData.d;
    
    tempInputFileNames = cell(1, d.numRecs);
    % This file will contain the raw recordings, where no correction has
    % been applied to.
    tempInputRawFileNames = cell(1, d.numRecs);
    for i = 1:d.numRecs
        tempInputFileNames{i} = fullfile(d.expDir{i}, 'input_data.bin');
        tempInputRawFileNames{i} = fullfile(d.expDir{i}, ...
            'input_data_raw.bin');
    end
    d.tempInputFileNames = tempInputFileNames;
    d.tempInputRawFileNames = tempInputRawFileNames;
    
    % No pauses in this mode (also no problems with ending the session).
    if p.useBulkMode
        d.tempInputRawFileNames = tempInputFileNames;
        d.tempInputFileNames = [];
    end
    
    % We could further specify when the callback functions is called by
    % setting NotifyWhenDataAvailableExceeds.
    listVar = addlistener(session, 'DataAvailable', ...
        @(src, event) inputDataCallback(src, event));

    d.inputListener = listVar;
    session.UserData.d = d;
end