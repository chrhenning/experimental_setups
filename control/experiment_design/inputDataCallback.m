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
@title           :inputDataCallback.m
@author          :ru, ch
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
    end
    src.UserData.triggerTime = evt.TriggerTime;
    
    % This assertion cannot trigger, as this was tested while
    % preprocessing the parameters.
    assert(size(p.inputChannel, 1) == 1 || ...
        size(p.inputChannel, 1) == d.numRecs);
    
    for i = 1:d.numRecs
        filepath = d.tempInputFileNames{i};
        
        if size(p.inputChannel, 1) == 1
            inputData = evt.Data;
        else
            inputData = evt.Data(:, d.channelInds.input(i, :));
        end

        data = [evt.TimeStamps, inputData]';
        
        fid = fopen(filepath,'a');
        fwrite(fid, data, 'double');
        fclose(fid);
    end
end