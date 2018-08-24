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
@title           :params.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/14/2018
@version         :1.0

Parametrize the postprocessing of behavior videos.

The script does not rely on the design file and simply processes all videos
in the videoDir. The relative folder structure is kept.

The program only works with avi files!

Note, when you want to normalize videos, please compress them first to
speed up the process. Note, when running the program several times, do not
decrease the quality unintentionally every time.

FIXME: Normalization seems to not yield to the desired effect (even if the
mean difference intensity is normalized to the reference value correctly).
%}

function p = params()
%PARAMS Specify parameters for video postprocessing.

    % Design Folder
    %p.designDir = '/home/christian/workspace/expFeb18/design';

    % Root directory of recordings. I.e., where to find the behavior
    % videos.
    p.videoDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'recordings');
    
    % Where to store the postprocessed videos? (Must be different from
    % p.videoDir.
    p.resultDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'recordings_processed'); 

    % Whether or not to copy all other files (except avi-files) from
    % p.videoDir to p.resultDir.
    % NOTE This option does currently ignore subdirectories.
    p.copyFiles = 1;
    
    % Desired output height and width of the processed videos.
    p.width = 400;
    p.height = 400;
    
    % JPEG Compression Quality of output videos.
    p.quality = 75;
    
    % Use a contrast enhancement technique (note, result will be grayscale
    % image).
    % The following options are allowed:
    %    'none', 'imadjust', 'histeq', 'adapthisteq'
    p.contrastEnhancement = 'none';
    
    % Inter-Video Noramlization.
    % Note, does not work in combination with p.contrastEnhancement or
    % p.applyDFOF.
    % To ease automatic freezing detection, it would be desirable that mice
    % pixels always have the same intensity in each video independent of
    % the background. Therefore, one can run a normalization
    % (runtime and memory exhausting!) that works as follows.
    %
    % The first video will be used as reference video for all other videos.
    % 1. Compute mean of first video.
    % 2. For all frames:
    %       Compute mean-difference image (dF = frame - mean).
    %       Compute the intensity of I of dF.
    % 3. use the average value of I (meanI) as scaling reference alpha for
    %    all videos.
    %
    % Now, that we have a reference, we can normalize or rescale all videos
    % accordingly. I.e., for all videos do
    % 4. Compute meanI.
    % 5. Rescale each frame by alpha/meanI.
    p.normalizeMeanMovementIntensity = 0;
    % Whether to use mean or median to compute video background.
    p.useMedian = 0;    
    
    % Delta-F over F
    % Note, does not work in combination with 
    % p.normalizeMeanMovementIntensity or p.applyDFOF.
    % Computes the mean image B of a video. We compute the new frames F_n
    % from the original frames F_o via the following formula:
    %   F_n = F_o / B - 1
    %
    % Background pixels should correspond to a value 0 in the new frames.
    % Object pixels to a value unequal zero. The resulting video should be
    % less dependent on the general background illumination.
    p.applyDFOF = 0;
end

