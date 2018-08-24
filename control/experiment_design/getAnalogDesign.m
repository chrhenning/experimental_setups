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
@title           :getAnalogDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :03/16/2018
@version         :1.0

Note, the function name might be misleading. This function only handles the
analog events specified in the design file (p.analogChannel), not analog
output channels in general.
%}

function design = getAnalogDesign(session, startTime, numSteps)
%GETANALOGDESIGN Determine the channel values of all analog events in the
%given window.
    %logger = log4m.getLogger();
    
    p = session.UserData.p;
    d = session.UserData.d;
    
    design = zeros([numSteps, size(p.analogChannel)]);

    for i = 1:numel(p.analogChannel)
        [r, c] = ind2sub(size(p.analogChannel),i);
        
        [~, numEvI] = d.subjects{r}.numEvents('analog');

        for e = 1:numEvI(c)
            event = d.subjects{r}.getAnalogEvent(c, e);

            [eventInWin, onsetStep, offsetStep, evOnInd, evOffInd] = ...
                isEventInWindow(session, startTime, numSteps, ...
                    event.onset, event.duration, numel(event.interp));

            if eventInWin
                design(onsetStep:offsetStep, r, c) = ...
                    event.interp(evOnInd:evOffInd) * p.analogScale(r, c);
            end
        end
    end
end

