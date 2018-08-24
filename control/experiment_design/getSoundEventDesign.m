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
@title           :getSoundEventDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/03/2018
@version         :1.0
%}
function design = getSoundEventDesign(session, startTime, numSteps)
%GETSOUNDEVENTDESIGN Set the channel to one for the sound events occurring
%in the given window.
    %logger = log4m.getLogger();
    
    p = session.UserData.p;
    d = session.UserData.d;
    
    design = zeros([numSteps, size(p.soundEventChannel)]);

    for i = 1:size(p.soundEventChannel, 1)
        for s = 1:d.subjects{i}.numSounds()
            event = d.subjects{i}.getSound(s);
            
            soundDurInSteps = size(event.sound, 1);
            
            [eventInWin, onsetStep, offsetStep, ~, ~] = ...
                isEventInWindow(session, startTime, numSteps, ...
                    event.onset, event.duration, soundDurInSteps);

            if eventInWin
                design(onsetStep:offsetStep, i, 1) = 1;
            end
        end
        
        % Copy for other sound event channels.
        for j = 2:size(p.soundEventChannel, 2)
            design(:, i, j) = design(:, i, 1);
        end
        
        % Apply amplitude to sound event channels.
        for j = 2:size(p.soundEventChannel, 2)
            if p.soundEventIsAnalog(i, j)
                design(:, i, j) = design(:, i, j) * ...
                    p.soundEventAmplitude(i, j);
            end
        end
    end
end




