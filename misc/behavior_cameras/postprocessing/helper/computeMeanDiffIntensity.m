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
@title           :computeMeanDiffIntensity.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/15/2018
@version         :1.0
%}

function [intensity, offset] = computeMeanDiffIntensity(vidPath, useMedian)
%COMPUTEMEANDIFFINTENSITY Computation of the mean intensity in mean
%subtracted video frames.
%   This function computes the mean (or median) video frame, which is
%   considered as static background. A mean (or median) subtracted frame
%   is considered to be a moving object, whose average intensity is going
%   to be computed and returned.
%   The returned offset can be used to find the right normalization factor
%   (Please read the enclosed documentation about how to calculate the
%   normalization factor per frame).
%
%   Note, this method is very memory exhausting, as we read the whole video
%   to memory (independent of the parameter useMedian).

    videoObj = VideoReader(vidPath);
    
    nFrames = videoObj.NumberOfFrames;
    %nFrames = 100; disp('FIXME');
    imSize = [videoObj.Height, videoObj.Width];
    
    stack = zeros([imSize, nFrames], 'single');
    
    videoFrames = read(videoObj, [1 nFrames]);
    if length(size(videoFrames)) == 4
        stack = squeeze(mean(videoFrames, 3));
    end
    stack = single(stack);
    
    if useMedian
        background = median(stack,3);
    else
    	background = mean(stack,3);
    end
    
    intensity = 0;
    
    parfor i = 1:nFrames
        frame = stack(:,:,i);
        
        % It doesn't 
        diffFrame = 0.5 * ((frame - background) + 255);
        diffIntensity = mean(diffFrame(:));
        
        intensity = intensity + diffIntensity;
    end
    
    intensity = intensity / nFrames;
    
    % The constant offset used to compute the normalization.
    % offset = 0.5 * 1/nFrames * 1/prod(imSize) * nFrames * ...
    %    prod(imSize) * 255;
    offset = 0.5 * 255;
    
    delete(videoObj);
end

