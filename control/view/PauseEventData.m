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
@title           :PauseEventData.m
@author          :ch
@contact         :henningc@ethz.ch
@created         :08/27/2018
@version         :1.0

Capsulates data, that the GUI can use to know whether a pause request or a
continue request was performed.
%}
classdef (ConstructOnLoad) PauseEventData < event.EventData
   properties
      IsPausing
   end
   
   methods
      function data = PauseEventData(isPausing)
         data.IsPausing = isPausing;
      end
   end
end