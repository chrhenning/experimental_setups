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
@title           :playSounds.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/03/2018
@version         :1.0

Play sounds from design file via soundcard. Note, precise timing cannot be
ensured!
%}
function playSounds(session, sessionStartTime)
%PLAYSOUNDS Plays the sounds of the design for the first specified
%recording in this session.
%
%   The function plays only the sound events of the first recording in the
%   same order as given by the design file (no sorting is done).
%
%   FIXME: The function expects sound events to be ordered.
%   FIXME: Primitive function, does not play partial sounds if time already
%   progressed passed the sound onset.
    global errorOccurredDuringSession;

    logger = log4m.getLogger();
    logger.warn('playSounds', ['Sounds are played via sound card. ' ...
        'Precise timing cannot be ensured!']);

    %p = session.UserData.p;
    d = session.UserData.d;
    
    if d.numRecs > 1
        logger.warn('playSounds', ['Only sounds from recording 1 are ' ...
            'played. The other recordings are ignored.']);
    end 
    
    sampling_rate = d.properties.sound_sampling_rate;
    bit_depth = d.properties.sound_bit_depth;
    
    eps = 0.01;

    for i = 1:d.subjects{1}.numSounds()
        sndEvent = d.subjects{1}.getSound(i);
        
        onsetTime = getActualOnset(sndEvent.onset, sessionStartTime, ...
            session);
        
        while (onsetTime - eps) > elapsedTime(sessionStartTime)
            % If the actual start time is known yet.
            if isfield(session.UserData, 'triggerTime')
                sessionStartTime = session.UserData.triggerTime;
            end
            
            % If the recording has been stopped by the user, we exit this
            % function early.
            if session.UserData.d.recView.hasRecStopped()
                return;
            end
            
            % If the session has ended due to an occurred error, we also
            % return this function.
            if errorOccurredDuringSession
                return;
            end
            
            pause(min(1, (onsetTime-eps) - elapsedTime(sessionStartTime)));
            
            onsetTime = getActualOnset(sndEvent.onset, ...
                sessionStartTime, session);
        end
        
        while elapsedTime(sessionStartTime) < onsetTime
            % busy wait
        end
        
        sound(sndEvent.data, sampling_rate, bit_depth);
        
        logger.info('playSounds', ['Playing sound '  num2str(i) ...
            ', which has the sound type ' sndEvent.type '.']);
        
        % Log event in GUI.
        durMin = floor(sndEvent.onset / 60);
        durSec = round(mod(sndEvent.onset, 60));
        evStr = sprintf(['[%02d:%02d] - sound event : duration - %d ' ...
            'sec, type - %s.'], durMin, durSec, sndEvent.duration, ...
            sndEvent.type);
        session.UserData.d.recView.logEvent(evStr);
    end
end

function elapsedSecs = elapsedTime(refTime)
    % Compute the elapsed seconds since a reference time point.
    elapsedSecs = round((now - refTime) * 24 * 60 * 60);
end

function onset = getActualOnset(origOnset, startTime, session)
    % This method uses the function "correctOnset" to correct the onset
    % time. It will stall until the current pause is over.
    %
    % Args:
    % See method "correctOnset".
    %
    % Returns:
    % The new onset time.
    onset = -1;
    while onset == -1
        [onset, waitSec] = correctOnset(origOnset, startTime, session);
        if onset == -1
            pause(waitSec);
        end
    end
end

function [onset, waitSecs] = correctOnset(onset, startTime, session)
    % CORRECTONSET Correct the onset of an event, given that pause windows
    % may appear within the session.
    %
    % Note, this function does not consider the length of a sound or
    % whether this length will interfere with a requested pause window.
    %
    % Args:
    % - onset: The original onset of the event (acc. to design).
    % - startTime: The start time of the session.
    % - session: The current NIDAQ session.
    %
    % Returns:
    % - onset: The corrected onset. This is -1, if we are currently in a
    %          pause window, were no tones should be played.
    % - waitSecs: Usually -1, except if onset is -1. Then this number tells
    %             us, how long we have to wait until the end of the
    %             current pause window.
    waitSecs = -1;
    
    wins = session.UserData.d.outputDataWindows;
    if isempty(wins)
       % We cannot correct the onset yet. Though, that should be no
       % problem, as the first window is always no pause.
       return;
    end
    
    elapsedSecs = elapsedTime(startTime);    
    numSteps = floor(elapsedSecs * session.Rate);
    
    startSteps = [0; wins(1:end-1, 4)];
    % In which window are we currently in?
    latestWinInd = find(numSteps >= startSteps & numSteps < wins(:, 4), ...
        1, 'last');
    
    % Shouldn't happen, but we don't know yet the current window. Normally,
    % the window was queued to the NIDAQ long before we reach a time step
    % within the window.
    if isempty(latestWinInd)
        logger = log4m.getLogger();
        logger.warn('playSounds', ['Could not ensure that sound onset ' ...
            'time is correct.']);
        
        % All steps, that are considered pauses so far.
        pausedSteps = wins(end, 4) - wins(end, 5);
        % Simply add all steps, that were in paused windows so far.
        onset = onset + pausedSteps / session.Rate; 
        return;
    end
    
    % The session is currently paused, then we wait until the end of the
    % current window before we check again.
    if wins(latestWinInd, 6) == 1
        onset = -1;
        waitSecs = (wins(latestWinInd, 4) - numSteps) / session.Rate; 
        return;
    end
    
    numSteps = numSteps - (wins(latestWinInd, 4) - wins(latestWinInd, 5));
    % Actual time, considering pause windows.
    elapsedSecsActual = numSteps / session.Rate; 
    
    onset = onset + (elapsedSecs - elapsedSecsActual);
end

