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
@title           :computeMeanBackground.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :04/03/2018
@version         :1.0
%}

function background = computeMeanBackground(vidPath, width, height)
%COMPUTEMEANBACKGROUND A memory (but not runtime) efficient implementation
%of computing the mean background image of the given video.
%
% The parameters "width" and "height" denote the size of the returned
% output image. If they differ from the frame size of the video, then all
% video frames are rescaled to this size before used for mean computation.

    videoObj = VideoReader(vidPath);
    
    nFrames = videoObj.NumberOfFrames;
    imSize = [height, width];
    
    background = zeros(imSize);
    
    parfor i = 1:nFrames
        frame = (read(videoObj, i));
        frame = imresize(frame, imSize);
        
        if size(frame,3)
            frame = mean(frame,3);
        end

        background = background + frame;
    end
    background = background / nFrames;

    background = uint8(background);
    
    delete(videoObj);
end

