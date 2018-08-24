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
@title           :getSoundDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/02/2018
@version         :1.0
%}
function design = getSoundDesign(session, startTime, numSteps)
%GETSOUNDDESIGN Ditribute sound events over given window.
%
%   Note, this function doesn't check whether sounds are overlapping.
    %logger = log4m.getLogger();
    
    p = session.UserData.p;
    d = session.UserData.d;
    
    design = zeros([numSteps, size(p.soundChannel)]);

    for i = 1:size(p.shockChannel, 1)
        for s = 1:d.subjects{i}.numSounds()
            event = d.subjects{i}.getSound(s);
            soundDurInSteps = size(event.interp, 1);
            
            [eventInWin, onsetStep, offsetStep, evOnInd, evOffInd] = ...
                isEventInWindow(session, startTime, numSteps, ...
                    event.onset, event.duration, soundDurInSteps);

            if eventInWin               
                design(onsetStep:offsetStep, i, 1) = ...
                    event.interp(evOnInd:evOffInd, 1) * ...
                    p.soundScale(i, 1);
                
                % Right channel.
                if size(p.soundChannel, 2) == 2
                    sind = 1;
                    if size(event.data, 2) == 2
                        sind = 2;
                    end
                    design(onsetStep:offsetStep, i, 2) = ...
                        event.interp(evOnInd:evOffInd, sind) * ...
                        p.soundScale(i, 2);
                end
            end
        end
    end
end


