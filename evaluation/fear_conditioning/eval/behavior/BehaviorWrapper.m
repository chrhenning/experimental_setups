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
@title           :BehaviorWrapper.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :04/06/2018
@version         :1.0

An interface to the behavior (currently only freezing) of the animal during
a recording.
%}
classdef BehaviorWrapper
    %BEHAVIORWRAPPER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        % Index of this recording within evaluation struct.
        RecInd
        % The recording struct for the associated recording as extracted by
        % "organizeRecordings.m". 
        % FIXME: This is now stored twice. It would be better, if the
        % evaluation data structure would be its own class, such that we
        % could store a reference to an object.
        Recording
        % The binary freezing trace of the animal.
        FrezTrace
        % Time resolution used for traces.
        Rate
    end
    
    methods (Access = public)
        function obj = BehaviorWrapper(recording, recInd, freztrace, p)
            %DESIGNITERATOR Construct an instance of this class.
            %   obj = BehaviorWrapper(recording, recInd, freztrace)
            
            obj.Recording = recording;
            obj.RecInd = recInd;
            obj.FrezTrace = freztrace;
            obj.Rate = p.evalRate;
        end
        
        function [preTrace, trace, postTrace] = getEventFreezing(obj, ...
                eventInd, postWin, preWin)
            % GETEVENTFREEZING Return the freezing behavior around an event
            % presentation.
            %
            % Arguments:
            % - eventInd: Index of event, which occurred in associated 
            %             recording.
            % - postWin: How many seconds after the event presentations
            %            should be considered as well.
            % - preWin (default: postWin): Seconds to consider before event
            %                              presentation.
            %
            % Returns:
            % The freezing traces before (according to preWin), during and
            % after (according to postWin) the event presentation.
            if (~exist('preWin', 'var'))
                preWin = postWin;
            end
            
            event = obj.Recording.events;
            tData = obj.Recording.relativeTimestamps;
            
            preTrace = zeros(1, ceil(preWin * obj.Rate));
            trace = zeros(1, ceil(event.duration(eventInd) * obj.Rate));
            postTrace = zeros(1, ceil(postWin * obj.Rate));

            % First moment in time, where event is presented.
            son = event.onset(eventInd);
            % First moment in time, where event is not presented anymore.
            soff = son + event.duration(eventInd);

            % TODO Maybe we should display warnings or return support
            % values in case (spre < 0) or (spost > tData(end)).
            % Support can be computed by using minInd/maxInd below.
            spre = son - preWin;
            spost = soff + postWin;

            % Extract freezing traces for each of the 3 windows.
            frezPre = obj.FrezTrace(tData >= spre & tData < son);
            frezDur = obj.FrezTrace(tData >= son & tData < soff);
            frezPost = obj.FrezTrace(tData >= soff & tData < spost);

            preLim = size(preTrace, 2);
            durLim = size(trace, 2);
            postLim = size(postTrace, 2);

            if ~isempty(frezPre)
                minInd = max(1 + preLim - length(frezPre), 1);
                preTrace(1, minInd:preLim) = frezPre(1:min(end, preLim));
            end

            if ~isempty(frezDur)
                maxInd = min(length(frezDur), durLim);
                trace(1, 1:maxInd) = frezDur(1:maxInd);
            end

            if ~isempty(frezPost)
                maxInd = min(length(frezPost), postLim);
                postTrace(1, 1:maxInd) = frezPost(1:maxInd);
            end 
        end
        
        function [preTrace, trace, postTrace, traceSupport] = ...
            getEventFreezingStandard(obj, eventInd, eventDuration, ...
                postWin, preWin)
            % GETEVENTFREEZINGSTANDARD Returns the same as 
            % "getEventFreezing", except that the event has a standardized
            % duration "eventDuration".
            %
            % The return value 'trace' will have a length that corresponds
            % to the parameter 'eventDuration' (in seconds).
            % The actual trace (as returned by 'getEventFreezing' will
            % start at index 1 of the returned 'trace'. If the actual trace
            % is shorter, then the remainder of 'trace' is padded with
            % zeros. If it is longer, the remainder is cropped.
            %
            % The function returns an additional argument 'traceSupport',
            % which is a binary array that is 1 everywhere where the
            % returned 'trace' has an actual data point.
            if (~exist('preWin', 'var'))
                preWin = postWin;
            end
            
            [preTrace, traceOrig, postTrace] = obj.getEventFreezing( ...
                eventInd, postWin, preWin);
            
            trace = zeros(1, ceil(eventDuration * obj.Rate));
            traceSupport = zeros(1, ceil(eventDuration * obj.Rate), ...
                'logical');
            
            %preLen = size(preTrace, 2);
            durLen = size(traceOrig, 2);
            %postLen = size(postTrace, 2);

            if durLen > 0
                maxInd = min(durLen, size(trace, 2));
                trace(1:maxInd) = traceOrig(1:min(end, size(trace, 2)));
                traceSupport(1:maxInd) = 1;
            end
        end
        
        function [trace, support] = ...
            getEventFreezingStandardSingle(obj, eventInd, ...
                eventDuration, postWin, preWin)
            % GETEVENTFREEZINGSTANDARDSINGLE Returns the same as
            % 'getEventFreezingStandard', except that the output doesn't
            % distinguish anymore between pre-, during- and posttrace.
            %
            % The returned trace has thus the length preWin + eventDuration
            % + postWin (in seconds). Additionally, the support array 
            % has also the correct support values for pre- and
            % post-windows.
            if (~exist('preWin', 'var'))
                preWin = postWin;
            end
            
            [preTrace, traceOrig, postTrace, traceSupport] = ...
                getEventFreezingStandard(obj, eventInd, eventDuration, ...
                    postWin, preWin);
                
            preLen = size(preTrace, 2);
            durLen = size(traceOrig, 2);
            postLen = size(postTrace, 2);
                
            trace = zeros(1, preLen + durLen + postLen);
            support = ones(1, size(trace, 2), 'logical');
            
            trace(1:preLen) = preTrace;
            trace(preLen+1:preLen+durLen) = traceOrig;
            trace(preLen+durLen+1:preLen+durLen+postLen) = postTrace;
            
            support(preLen+1:preLen+durLen) = traceSupport;
            
            % Compute pre and post support.
            % TODO Better compute all supports in 'getEventFreezing' and
            % loop them through.
            event = obj.Recording.events;
            tData = obj.Recording.relativeTimestamps;

            % First moment in time, where event is presented.
            son = event.onset(eventInd);
            % First moment in time, where event is not presented anymore.
            soff = son + event.duration(eventInd);
            
            spre = son - preWin;
            spost = soff + postWin;
            
            deltaPre = tData(1) - spre;
            if deltaPre > 0 % spre < tData(1)
                startInd = min(preLen, ceil(deltaPre * obj.Rate));
                support(1:startInd) = 0;
            end
            
            deltaPost = spost - tData(end);
            if deltaPre > 0 % spost > tData(end)
                endInd = max(preLen+durLen+1, ...
                    ceil(size(trace, 2) + 1 - deltaPost * obj.Rate));
                support(endInd:end) = 0;
            end
        end
        
        function trace = getFreezing(obj)
            trace = obj.FrezTrace;
        end
    end
end

