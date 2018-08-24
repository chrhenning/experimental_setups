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
@title           :isEventInWindow.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :03/16/2018
@version         :1.0
%}

function [eventInWin, onsetStep, offsetStep, evOnsetStep, evOffsetStep] ...
    = isEventInWindow(session, winStart, numStepsInWin, eventOnset, ...
                      eventDuration, eventDurInSteps)
%ISEVENTINWINDOW This method checks, whether a specific event occurs within
%a given time window.
%   
%   Arguments:
%   - session: The NIDAQ session (needed to know the daq rate).
%   - winStart: Start time of window (in seconds).
%   - numStepsInWin: Number of steps (NIDAQ steps) within the window, i.e.,
%                    length of window.
%   - eventOnset: Start time of event (in seconds).
%   - eventDuration: Duration of event (in seconds). Value is ignored if
%                    eventDurInSteps is given.
%   - eventDurInSteps: (optional) Duration of event (in NIDAQ time steps).
%
%   Returns:
%   - eventInWin: Flag, whether the event appears within the specified time
%                 window.
%   - onsetStep: Onset step of event relative to window start (-1 if event
%                not occurring in window).
%   - offsetStep: Offset step of event relative to window start (-1 if 
%                 event not occurring in window).
%   - evOnsetStep: Onset step of event in window relative to event start 
%                  (-1 if event not occurring in window).
%   - evOffsetStep: Offset step of event in window relative to event start 
%                   (-1 if event not occurring in window).
    %logger = log4m.getLogger();
    
    eventInWin = false;

    startStep = floor(winStart * session.Rate);
    endStep = startStep + numStepsInWin - 1;
    
    onsetStep = floor(eventOnset * session.Rate);
    if (~exist('eventDurInSteps', 'var'))
        numStepsEvent = floor(eventDuration * session.Rate);
    else
        numStepsEvent = eventDurInSteps;
    end
    offsetStep = onsetStep + numStepsEvent - 1;
    
    if ~(onsetStep > endStep || offsetStep < startStep)
        eventInWin = true;
        
        % Relative coordinates within event time coordinate system.
        evOnsetStep = 1 + max(0, startStep - onsetStep);
        evOffsetStep = numStepsEvent - max(0, offsetStep - endStep);
        
        % Possible corrections due to rounding errors.
        if evOnsetStep > numStepsEvent
            evOnsetStep = numStepsEvent;
        end
        if evOffsetStep < 1
            evOffsetStep = 1;
        end
        
        % Relative coordinates within window time coordinate system.
        onsetStep = max(startStep, onsetStep);
        % Relative onset within window.
        onsetStep = onsetStep - startStep + 1;

        offsetStep = min(endStep, offsetStep);
        offsetStep = offsetStep - startStep + 1;

        % Possible corrections due to rounding errors.
        if onsetStep < 1
            onsetStep = 1;
        end
        if offsetStep > numStepsInWin
            offsetStep = numStepsInWin;
        end
        
        % If corrections had to be applied, then it might be, that 
        % (offsetStep - onsetStep) ~= (evOffsetStep - evOnsetStep)
        %
        % If this is the case, then outcome would be fatal -> a simple
        % assignment, such as 
        % winData(onsetStep:offsetStep) = ...
        %    eventData(evOnsetStep:evOffsetStep)
        % would fail, causing the recording to crash. Instead, we capture
        % that case and display a warning.
        numWinSteps = offsetStep - onsetStep;
        numEvSteps = evOffsetStep - evOnsetStep;
        if numWinSteps ~= numEvSteps
            logger.error('isEventInWindow', ['Could not perfectly ' ...
                'match event to time window.'])
            
            % Don't know, if that can happen.
            if numWinSteps < 0 || numEvSteps < 0
                eventInWin = false;
                onsetStep = -1;
                offsetStep = -1;
                evOnsetStep = -1;
                evOffsetStep = -1;
                return;
            end
            
            delta = abs(numWinSteps - numEvSteps);
            onsetCorrection = floor(delta / 2);
            offsetCorrection = ceil(delta / 2);
            
            if numWinSteps > numEvSteps
                onsetStep = onsetStep + onsetCorrection;
                offsetStep = offsetStep - offsetCorrection;
            end
            
            if numEvSteps > numWinSteps
                evOnsetStep = evOnsetStep + onsetCorrection;
                evOffsetStep = evOffsetStep - offsetCorrection;
            end
        end
    else
        onsetStep = -1;
        offsetStep = -1;
        evOnsetStep = -1;
        evOffsetStep = -1;
    end
end

