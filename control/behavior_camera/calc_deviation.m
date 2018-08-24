% Copyright 2018 Benjamin Ehret, Christian Henning
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
@title           :calc_deviation.m
@author          :be, ch
@contact         :christian@ini.ethz.ch
@created         :06/01/2018
@version         :1.0
%}

function calc_deviation(obj, ~, refFrame, roiMask, camIdx)
% CALC_DEVIATION Compute difference of current frame to reference frame.
%
%   This method will update the global variable 'camRefDiff'.
%
% Args:
% - refFrame: Reference freame.
% - camIdx: Linear index of camera (to access 'camRefDiff' correctly).
    global camRefDiff
    
    % Get most recently aquired frame.
    frame = mean(peekdata(obj, 1), 3);
    
    subFrame = frame - refFrame;
    subFrame = abs(subFrame(roiMask));
    diffScore = mean(subFrame(:));
    camRefDiff(camIdx) = diffScore;
end