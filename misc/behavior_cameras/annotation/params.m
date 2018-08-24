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
@created         :02/15/2018
@version         :1.0

Annotate given video files with additional information, such as sound, 
shock and freezing events.

Note, only works for fear conditioning experiments!
%}

function p = params()
%PARAMS Specify parameters for video annotation.

    % Where to store the annotated videos? (Must be different from
    % p.videoDir.
    p.resultDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'annotated_vids'); 

    % Design Folder
    p.designDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'design'); 

    % Root directory of recordings. I.e., where to find the behavior
    % videos.
    p.videoDir = fullfile('/', 'home', 'USERNAME', 'experiment', ...
        'recordings');
    
    % Where are the freezing traces stored?
    % Note freezing traces must have been extracted with the software
    % written by the GreweLab (Repository: Freezing Detection).
    p.freezingDir = fullfile('/', 'home', 'USERNAME', 'workspace', ...
        'freezing'); 

    % The recordings to be considered. If empty, we consider all
    % recordings (very runtime consuming).
    % This is an m x 4 matrix, where m stands for the number of rows and
    % each row consists of an identifier (cohort, group, session, subject).
    % Example:
    % p.recordings = [1, 1, 5, 1; 1, 1, 5, 2; 1, 1, 6, 1; 1, 1, 6, 2; ...
    %                 2, 1, 6, 1; 2, 1, 6, 2];
    p.recordings = [2, 1, 1, 1];
        
    % Output video quality.
    p.quality = 75;
    
    % Positions of text elements in videos. The positions are relative
    % between 0 and 1.
    
    % Position of heading.
    p.posHeading = [0.5, 0.05]; % Anchor: Center
    % Position of US presentation notification.
    p.posUS = [0.075, 0.5]; % Anchor: LeftCenter
    % Position of sound presentation notification.
    % Note, if sounds are played via soundcard, there timing might not
    % exactly match the one given in the design file. Note, that we do not
    % attempt to correct that here.
    p.posSound = [0.075, 0.95]; % Anchor: LeftBottom
    % Position of digital events.
    p.posDigital = [0.075, 0.85]; % Anchor: LeftBottom
    % Position of analog events.
    p.posAnalog = [0.075, 0.75]; % Anchor: LeftBottom
    % Position of notification for detected freezing behavior.
    p.posFreezing = [0.925, 0.95]; % Anchor: RightBottom
    
    % Ignore freezing detection.
    % If enabled, freezing traces are ignored.
    p.ignoreFreezing = 0;
    % If enabled, no centroid markers will be drawn in the image.
    p.ignoreCentroids = 0;
end

