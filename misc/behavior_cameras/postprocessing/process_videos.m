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
@title           :process_videos.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/14/2018
@version         :1.0

Postprocessing of behavior videos. The script is parametrized via the file
params.m.
%}
addpath(genpath(fileparts(mfilename('fullpath'))));

p = params();

% We cannot run any of the following methods in parallel, as normalization
% and DFOF require mean computation on the original video.
assert(p.normalizeMeanMovementIntensity == 0 || ...
    (strcmp(p.contrastEnhancement, 'none') && p.applyDFOF == 0));
assert(p.applyDFOF == 0 || ...
    (strcmp(p.contrastEnhancement, 'none') && ...
    p.normalizeMeanMovementIntensity == 0));

% FIXME strings might be different even though folders are the same.
if strcmp(p.videoDir, p.resultDir)
    error('Video and result folder must differ!');
end

if exist(p.videoDir, 'file') ~= 7
    error('Input folder does not exist');
end

% Merge results, i.e., skip existing files.
mergeResults = 0;

% Remove previous results, if existing.
if exist(p.resultDir, 'file') == 7
    choice = questdlg(['The result folder already exists.' ...
            newline 'Do you want to delete the old results?' ...
            newline newline p.resultDir], ...
        'Folder already exists', 'Yes', 'Merge', 'Cancel', 'Cancel');

    if strcmp(choice, 'Yes')
        rmdir(p.resultDir, 's');
        disp('Deleted previous results');
    elseif strcmp(choice, 'Merge')
        mergeResults = 1;
        disp('Existing files will be skipped.');
    else
        error('Cannot overwrite previous results.');
    end
end

% Reference offset.
refOffset = -1;
% Reference mean difference intensity.
refMeanInt = -1;


%% Recursively find all avi files.
videoFiles = dir(fullfile(p.videoDir, '**', filesep, '*.avi'));
disp(['Found ' num2str(length(videoFiles)) ' video files to process.']);

%% Compress each video.
for i = 1:length(videoFiles)
    origVidPath = fullfile(videoFiles(i).folder, videoFiles(i).name);
    
    assert(startsWith(videoFiles(i).folder, p.videoDir))
    relVidDir = videoFiles(i).folder(length(p.videoDir)+1:end);
    disp(['Processing video with relative path: ', relVidDir]);
    
    resultVidDir = [p.resultDir relVidDir];
    
    if exist(resultVidDir, 'file') ~= 7
        mkdir(resultVidDir);
    end
    
    resultVidPath = fullfile(resultVidDir, videoFiles(i).name);
    disp(['Output video is stored in: ', resultVidPath]);
    
    %% Move or copy non-avi files.
    if p.copyFiles
        allFiles = dir(videoFiles(i).folder);
        for j = 1:length(allFiles)
            if allFiles(j).isdir
                continue;
            end
            
            [~, ~, ext] = fileparts(allFiles(j).name);
            if ext == '.avi'
                continue
            end
                        
            fname = fullfile(allFiles(j).folder, allFiles(j).name);
            % In case there are two videos in the current resultVidPath or
            % we merge the results, then we only need to copy other files 
            % once.
            if exist(fullfile(resultVidDir, allFiles(j).name), 'file')
                continue;
            end
            
            disp(['Copying ' fname]);
            copyfile(fname, resultVidDir);
            %movefile(fname, resultVidDir);
        end
    end
    
    if mergeResults && exist(resultVidPath, 'file')
        disp('Video already exists. Skipping file ...');
        continue;
    end
    
    %% Compute normalization reference.
    normalizeVideo = p.normalizeMeanMovementIntensity;
    
    if p.normalizeMeanMovementIntensity && refMeanInt == -1
        [refMeanInt, refOffset] = computeMeanDiffIntensity(origVidPath, ...
            p.useMedian);
        
        disp(['Reference intensity for moving objects is ' ...
            num2str(refMeanInt) '.']);
        
        % This video does not have to be normalized.
        normalizeVideo = 0;
    end
    
    %% Compute mean intensity used for normalization.
    normFactor = 1;
    if normalizeVideo
        [meanIntensity, offset] = computeMeanDiffIntensity(origVidPath, ...
            p.useMedian);
        
        normFactor = (refMeanInt - offset) / (meanIntensity - offset);
        assert(normFactor > 0);
        
        disp(['Normalization: Video is rescaled by a factor ' ...
            num2str(normFactor) '.']);
    end  
    
    %% Compute mean background of video.
    if p.applyDFOF
        background = computeMeanBackground(origVidPath, p.width, p.height);
        background = double(background);
        
        % Used to rescale all frames via the same linear transformation.
        minDFOF = nan;
        maxDFOF = nan;
    end
       
    %% Process Video
    videoObj = VideoReader(origVidPath);
    
    if videoObj.Width / videoObj.Height ~= p.width / p.height
        warning(['The processing will change the aspect ratio of the ' ...
            'video.']);
    end

    videoWriter = VideoWriter(resultVidPath, 'Motion JPEG AVI');
    videoWriter.FrameRate = videoObj.FrameRate;
    videoWriter.Quality = p.quality;

    open(videoWriter);
    disp('Writing output video to file');

    while hasFrame(videoObj)
        frame = readFrame(videoObj);
        frame = imresize(frame, [p.height, p.width]);
        
        if normalizeVideo
            frame = frame * double(normFactor);
            % Cropping pixel values larger than 1.
            frame = mat2gray(frame, [0.0 255.0]);
            %frame(frame > 255) = 255;
        end
        
        if p.applyDFOF
            frame = double(frame) ./ background - 1;
            
            if isnan(minDFOF)
                minDFOF = min(frame(:));
                maxDFOF = max(frame(:));
            end
            
            frame = mat2gray(frame, [minDFOF maxDFOF]);
        end
        
        switch p.contrastEnhancement
            case 'imadjust'
                frame = imadjust(rgb2gray(frame));
            case 'histeq'
                frame = histeq(rgb2gray(frame));
            case 'adapthisteq'
                frame = adapthisteq(rgb2gray(frame));
        end
        
        writeVideo(videoWriter, frame);
    end

    close(videoWriter);
    delete(videoObj);
end

disp('Postprocessing finished successfully.');