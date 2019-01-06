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
@title           :resetAllChannels.m
@author          :ch
@contact         :henningc@ethz.ch
@created         :08/29/2018
@version         :1.0
%}
function resetAllChannels(p)
%RESETALLCHANNELS Set all output channels to LOW.

    s = daq.createSession('ni');
    
    % Input channels
    % Note, in case of using digital channels, at least one analog channel
    % is required. This analog channel might be found within the inputs
    % only, so we have to add them to the session.
    if ~isempty(p.inputChannel)
        addChannels(s, p.inputChannel, p.inputDAQDeviceID, ...
            p.inputIsAnalog, 0);
    end
    
    % Trigger Channels
    if ~isempty(p.triggerChannel)
        addChannels(s, p.triggerChannel, p.triggerDAQDeviceID, ...
            p.triggerIsAnalog);
    end
    
    % Shock Channels
    if ~isempty(p.shockChannel)
        addChannels(s, p.shockChannel, p.shockDAQDeviceID, ...
            p.shockIsAnalog);              
    end
    
    % Sound Channels
    if ~p.useSoundCard
        addChannels(s, p.soundChannel, p.soundDAQDeviceID, ...
            ones(size(p.soundChannel)));
    end
    
    % Sound Event Channels
    if ~isempty(p.soundEventChannel)
        addChannels(s, p.soundEventChannel, ...
            p.soundEventDAQDeviceID, p.soundEventIsAnalog);
    end
    
    % Digital Channels from Design File
    if ~isempty(p.digitalChannel)
        addChannels(s, p.digitalChannel, p.digitalDAQDeviceID, ...
            zeros(size(p.digitalChannel)));
    end
       
    % Analog Channels from Design File
    if ~isempty(p.analogChannel)
        addChannels(s, p.analogChannel, p.analogDAQDeviceID, ...
            zeros(size(p.analogChannel)));
    end
    
    numOutputChannels = length(s.Channels) - numel(p.inputChannel);
    
    data = zeros(1, numOutputChannels);
    queueOutputData(s, data);

    startForeground(s);
    
    release(s);
end

function addChannels(session, channels, deviceID, isAnalog, isOutput)
% ADDCHANNELS Add analog and digital output channels to the session.
    if (~exist('isOutput', 'var'))
        isOutput = 1;
    end

    for i = 1:numel(channels)
        if isOutput
            if isAnalog(i)
                session.addAnalogOutputChannel(deviceID{i}, ...
                    channels{i}, 'Voltage');
            else
                session.addDigitalChannel(deviceID{i}, ...
                    channels{i}, 'OutputOnly');
            end
        else
            if isAnalog(i)
                session.addAnalogInputChannel(deviceID{i}, ...
                    channels{i}, 'Voltage');
            else
                session.addDigitalChannel(deviceID{i}, ...
                    channels{i}, 'InputOnly');
            end
        end
    end
end
