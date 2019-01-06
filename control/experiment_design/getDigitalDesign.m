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
@title           :getDigitalDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :03/16/2018
@version         :1.0

Note, the function name might be misleading. This function only handles the
digital events specified in the design file (p.digitalChannel), not digital
output channels in general.
%}
function design = getDigitalDesign(session, startTime, numSteps)
%GETDIGITALDESIGN Determine the channel values of all digital events in the
%given window.
    %logger = log4m.getLogger();
    
    p = session.UserData.p;
    d = session.UserData.d;
    
    design = zeros([numSteps, size(p.digitalChannel)]);

    for i = 1:numel(p.digitalChannel)
        [r, c] = ind2sub(size(p.digitalChannel),i);
        
        [~, numEvI] = d.subjects{r}.numEvents('digital');

        for e = 1:numEvI(c)
            event = d.subjects{r}.getDigitalEvent(c, e);
            
            [eventInWin, onsetStep, offsetStep, evOnInd, evOffInd] = ...
                isEventInWindow(session, startTime, numSteps, ...
                    event.onset, event.duration, numel(event.interp), ...
                    'digital', event.type, i);

            if eventInWin
                design(onsetStep:offsetStep, r, c) = ...
                    event.interp(evOnInd:evOffInd);
            end
        end
    end
end
