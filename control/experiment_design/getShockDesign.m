% Copyright 2018 Christian Henning, Rik Ubaghs
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
@title           :getShockDesign.m
@author          :ch, ru
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0
%}

function design = getShockDesign(session, startTime, numSteps)
%GETSHOCKDESIGN Ditribute foot shocks for given window.
    %logger = log4m.getLogger();
    
    p = session.UserData.p;
    d = session.UserData.d;
    
    design = zeros([numSteps, size(p.shockChannel)]);

    for i = 1:size(p.shockChannel, 1)
        for s = 1:d.subjects{i}.numShocks()
            event = d.subjects{i}.getShock(s);
           
            [eventInWin, onsetStep, offsetStep, evOnInd, evOffInd] = ...
                isEventInWindow(session, startTime, numSteps, ...
                    event.onset, event.duration, -1, 'us');

            if eventInWin
                channelInd = event.channel;
                switch p.shockMode
                    case 'default'
                        design(onsetStep:offsetStep, i, 1) = ...
                            event.interp(evOnInd:evOffInd);
                    case 'channel'
                        design(onsetStep:offsetStep, i, channelInd) = ...
                            event.interp(evOnInd:evOffInd);
                    case 'lrdesign'
                        % Channel 1: Trigger shock.
                        design(onsetStep:offsetStep, i, 1) = ...
                            event.interp(evOnInd:evOffInd);
                        
                        % Channel 2: Decide whether shock is left or right.
                        if channelInd == 2 % 1 for right chamber.
                            design(onsetStep:offsetStep, i, 1) = 1;
                        end
                    case 'lrposition'
                        myError('getShockDesign', 'Not yet implemented');
                end                        
            end
        end
        
        if strcmp(p.shockMode, 'default')
            % Copy first channel to other shock channels of recording.
            for j = 2:size(p.shockChannel, 2)
                design(:, i, j) = design(:, i, 1);
            end
        end
        
        % Apply amplitude argument to annalog channels.
        for j = 1:numel(p.shockChannel)
            if p.shockIsAnalog(i, j)
                design(:, i, j) = design(:, i, j) * p.shockAmplitude(i, j);
            end
        end
    end
end
