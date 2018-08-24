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
@title           :ni_analog_digital_example.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :18/03/2017
@version         :1.0
%}


function ni_analog_digital_example(duration, frequency, triggerSession, ...
    analogInChannel, analogOutChannel, digitalInChannel, ...
    digitalOutChannel, deviceID )
%NI_ANALOG_DIGITAL_EXAMPLE A simple code example that highlights how to use
%analog and digital input/output channel.
%
%   This function generates 1 digital + 1 analog input channel plus 1
%   digital + 1 analog output channel. The digital output outputs a high
%   signal for the whole session. The analog output outputs a sine wave
%   with the given frequency.
%
%   Arguments:
%   - 'duration': Duration of session in seconds.
%   - 'frequency': Frequency of analog output sine wave.
%   - 'triggerSession' (default: false): Whether the session should be
%        triggered by an external high signal via the PFI channel
%        'Dev1/PFI1'.
%   - 'analogInChannel' (default: 0): Channel ID of analog input.
%   - 'analogOutChannel' (default: 1): Channel ID of analog output.
%   - 'digitalInChannel' (default: 'Port0/Line0'): Channel ID of digital
%        input.
%   - 'digitalOutChannel' (default: 'Port0/Line1'): Channel ID of digital
%        output.
%   - 'deviceID' (default: 'dev1'): NIDAQ Device ID.
%
%   Examples: 
%   >> ni_analog_digital_example(10, 4000);

    if (~exist('triggerSession', 'var'))
        triggerSession = false;
    end
    if (~exist('analogInChannel', 'var'))
        analogInChannel = 0;
    end
    if (~exist('analogOutChannel', 'var'))
        analogOutChannel = 0;
    end
    if (~exist('digitalInChannel', 'var'))
        digitalInChannel = 'Port0/Line0';
    end
    if (~exist('digitalOutChannel', 'var'))
        digitalOutChannel = 'Port0/Line1';
    end
    if (~exist('deviceID', 'var'))
        deviceID = 'dev1';
    end

    s = daq.createSession('ni');
    s.Rate = 1000;

    % Add input channels.
    % At least one analog channels is necessary when using digital
    % channels, to set the internal clock.
    addAnalogInputChannel(s, deviceID, analogInChannel, 'Voltage');
    addDigitalChannel(s, deviceID, digitalInChannel, 'InputOnly');

    addAnalogOutputChannel(s, deviceID, analogOutChannel, 'Voltage');
    addDigitalChannel(s, deviceID, digitalOutChannel, 'OutputOnly');

    % If true, then the session is not starting before an external trigger 
    % is received.
    if triggerSession
        addTriggerConnection(s, 'external', 'Dev1/PFI1', 'StartTrigger');
        % How long should we wait for a trigger before raising an error.
        s.ExternalTriggerTimeout = 60;
    end

    % Generate sine wave, that is outputed via the analog channel.
    x = linspace(0, duration, duration * s.Rate);
    y = sin(2 * pi * frequency * x);

    % The digital channel simply outputs 1 the whole time.
    data = ones(duration * s.Rate, 2);
    data(:,1) = y;
    % Make sure that both output channels are reset to 0 at the end of the
    % session.
    data(end,:) = 0;

    queueOutputData(s, data);

    dataIn = startForeground(s);

    figure('Name', 'Analog + Digital Input Recordings');
    plot(x, dataIn(:, 1), 'Color', 'k', 'DisplayName', 'Analog');
    hold on;
    plot(x, dataIn(:, 2), 'Color', 'r', 'DisplayName', 'Digital');
    legend;
    xlabel('Time (s)');

    release(s);
end

