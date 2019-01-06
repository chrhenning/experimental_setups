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
@title           :getTriggerData.m
@author          :ch, ru
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0
%}

function design = getTriggerDesign(session, startTime, numSteps)
%GETTRIGGERDESIGN Generate trigger output data for given window.
    logger = log4m.getLogger();

    p = session.UserData.p;
    %d = session.UserData.d;
    
    design = zeros([numSteps, size(p.triggerChannel)]);

    for i = 1:numel(p.triggerChannel)
        [r, c] = ind2sub(size(p.triggerChannel), i);
        
        if p.triggerRate(i) > 0
            % FIXME We don't really have to enforce that (we could just 
            % delete the error)
%             if floor(p.triggerRate(i)) ~= p.triggerRate(i)
%                 errMsg = 'Trigger rate should be an integer.';
%                 myError('getTriggerDesign', errMsg);
%             end

            % Note, that half of the period should be one and the other
            % half zero.
            periodSize = session.Rate / p.triggerRate(i);
            
            % Compute a whole period.
            % FIXME becomes really memory insufficient when
            % triggerRate << 1.
            singleCycle = [ ...
                ones(floor(periodSize/2), 1); ...
                zeros(ceil(periodSize/2), 1)];
            
            if p.triggerIsAnalog(i)
                singleCycle = singleCycle * p.triggerAmplitude(i);
            end
            periodSize = numel(singleCycle);
            
            % The start time might be in the middle of a period. Similarly,
            % the end time might also be in the middle of a period. So the
            % full trace consists of a start cycle, many in between cycles
            % and one end cycle.
            stepsNeeded = numSteps;
            
            % Start index in first cycle.
            startIndex = floor(mod(startTime * session.Rate, ...
                periodSize)) + 1;

            traceStart = singleCycle(startIndex:end, :);
            % What if there is less than one period in the current window?
            if numel(traceStart) > stepsNeeded
                traceStart = ...
                    singleCycle(startIndex:startIndex+stepsNeeded-1, :);
            end
            stepsNeeded = stepsNeeded - numel(traceStart);
            
            numFullCycles = floor(stepsNeeded / periodSize);
            traceMiddle = repmat(singleCycle, numFullCycles, 1);
            stepsNeeded = stepsNeeded - numel(traceMiddle);
            
            traceEnd = singleCycle(1:stepsNeeded, :);
            stepsNeeded = stepsNeeded - numel(traceEnd);
            
            assert(stepsNeeded == 0);
            
            allCycles = [traceStart; traceMiddle; traceEnd];
            design(:, r, c) = allCycles;
        else
            logger.warn('getTriggerDesign', ['Having a trigger rate ' ...
                'smaller or equal to zero. Setting trigger signal to ' ...
                'constant high']);
            design(:, r, c) = ones(numSteps, 1);
            
            if p.triggerIsAnalog(i)
                design(:, r, c) = design(:, r, c) * p.triggerAmplitude(i);
            end
        end
    end
end
