% Copyright 2017 Christian Henning
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
@title           :ni_sound_example.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :12/05/2017
@version         :1.0
%}

function ni_sound_example(duration, frequency)
%NI_SOUND_EXAMPLE Output a tone via the NIDAQ.
%   NI_SOUND_EXAMPLE(duration, frequency)
%
%   This function will create a NIDAQ session and output a single-frequency
%   tone for a given duration on channel AO 0 and AO 1. Thus, these
%   channels have to be connected to a male Stereo Cinch connector, which
%   is connected to some output speakers.
%
%   Example:
%   ni_sound_example(10, 2000);

    s = daq.createSession('ni');
    s.Rate = 48000;
    % Note, the tone will be played for ceil(duration / winLen) * winLen
    % seconds.
    winLen = 1;
    queuedTimesteps = winLen * s.Rate;
    s.IsContinuous = true;
    s.NotifyWhenScansQueuedBelow = queuedTimesteps*0.9;

    s.addAnalogOutputChannel('Dev1', [0, 1], 'Voltage');

    % We simply generate the tone for the complete session, such that the
    % concatenation points are correct.
    ceiledDuration = ceil(duration / winLen) * winLen;
    x = linspace(0, ceiledDuration, ceiledDuration * s.Rate);
    y = sin(2 * pi * frequency * x);
    s.UserData.y = y;
    s.UserData.index = 1;
    s.UserData.duration = duration;
    s.UserData.winLen = winLen;
    %plot(x, y);

    queueData(s);
    lh = addlistener(s, 'DataRequired', @queueData);
    lhe = addlistener(s,'ErrorOccurred',@errorOccurred);

    prepare(s);

    startBackground(s);
    wait(s, duration);

    stop(s);
    release(s);

    delete(lh);
    delete(lhe);
end

function queueData(src, ~)
    
    if src.UserData.duration <= 0
        % FIXME: This stops early and flushes data still on the NIDAQ.
        src.stop();
        return;
    end
    startInd = floor((src.UserData.index - 1) * src.Rate + 1);
    endInd = floor(src.UserData.index * src.Rate);
    y = src.UserData.y(startInd: endInd);
    src.queueOutputData([y', y']);
    
    src.UserData.index = src.UserData.index + 1;
    src.UserData.duration = src.UserData.duration - src.UserData.winLen;
end

function errorOccurred(~, event)
    disp(['ERROR ', getReport(event.Error)]);
end

