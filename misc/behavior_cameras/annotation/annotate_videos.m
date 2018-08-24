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
@title           :annotate_videos.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/15/2018
@version         :1.0

This script is meant to augment behvior videos. For example, indications
for sound events, US stimuli or detected freezing behavior are textually
added.

The script is parametrized by the enclosed params file.
%}
addpath(genpath('../../../misc/'));

p = params();

% FIXME strings might be different even though folders are the same.
if strcmp(p.videoDir, p.resultDir)
    error('Video and result folder must differ!');
end

designIter = DesignIterator(p.designDir);

numRecs = size(p.recordings, 1);
if isempty(p.recordings)
    numRecs = designIter.numberOfRecordings();
    recInds = 1:1:numRecs;
else
    recInds = zeros(1, numRecs);
    for i = 1:numRecs
        args = num2cell(p.recordings(i,:));
        recInds(i) = designIter.toLinearIndex(args{:});
    end
end
disp(['Annotating videos from ' num2str(numRecs) ' recordings.']);

% Remove previous results, if existing.
if exist(p.resultDir, 'file') == 7
    choice = questdlg(['The result folder already exists.' ...
            newline 'Do you want to delete the old results?' ...
            newline newline p.resultDir], ...
        'Folder already exists', 'Yes', 'No', 'Cancel', 'Cancel');

    if strcmp(choice, 'Yes')
        rmdir(p.resultDir, 's');
        disp('Deleted previous results');
    else
        error('Cannot overwrite previous results.');
    end
end

if ~p.ignoreFreezing || ~p.ignoreCentroids
    candidatePath = fullfile(p.freezingDir, 'candidates_extraction.mat');
    load(candidatePath, 'candidates');

    % They may have leading or closing slashes.
    relCandDirs = {candidates.relativeVideoFolder};
    for i = 1:length(relCandDirs)
       if startsWith(relCandDirs{i}, '/')
           relCandDirs{i} = relCandDirs{i}(2:end);
       end
       if endsWith(relCandDirs{i}, '/')
           relCandDirs{i} = relCandDirs{i}(1:end-1);
       end
    end
end


for i = 1:numRecs
    r = recInds(i);
    [recStruct, ident, identNames] = designIter.get(r);
    properties = designIter.getProperties();
    recording = RecordingDesign(recStruct, properties, ident, p.designDir);
    
    [nDigChannels, nDigEvents] = recording.numEvents('digital');
    [nAnaChannels, nAnaEvents] = recording.numEvents('analog');
    
    disp(['Working on recording: Cohort - ' identNames{1} ', Group - ' ...
        identNames{2} ', Session - ' identNames{3} ', Subject - ' ...
        identNames{4} '.']);
    heading = ['Cohort: ' identNames{1} ', Group: ' identNames{2} ...
        ', Session: ' identNames{3} ', Subject: ' identNames{4}];
        
    args = num2cell(ident);
    relVidDir = DesignIterator.getRelFolder(args{:});
    vidDir = fullfile(p.videoDir, relVidDir);
    
    if ~p.ignoreFreezing || ~p.ignoreCentroids
        cind = find(strcmp(relCandDirs, relVidDir), 1);
        if isempty(cind)
            error('Could not find freezing trace of recording.');
        end
        candidate = candidates(cind);
    end
    
    if exist(vidDir, 'file') ~= 7 
        error(['Video directory does not exist: ' vidDir]);
    end
    
    videoFiles = dir(fullfile(vidDir, '*.avi'));
    % TODO we only support fear conditioning videos atm (a single video per
    % recording).
    assert(length(videoFiles) == 1 && ...
        strcmp(videoFiles(1).name, 'behavior.avi'));
    
    vidPath = fullfile(vidDir, videoFiles(1).name);
    
    resultVidDir = fullfile(p.resultDir, relVidDir);
    resultVidPath = fullfile(resultVidDir, videoFiles(1).name);
    
    if exist(resultVidDir, 'file') ~= 7
        mkdir(resultVidDir);
    end
    
    videoObj = VideoReader(vidPath);
    imSize = [videoObj.Height, videoObj.Width];
    posHeading = p.posHeading .* fliplr(imSize);
    posUS = p.posUS .* fliplr(imSize);
    posSound = p.posSound .* fliplr(imSize);
    posDigital = p.posDigital .* fliplr(imSize);
    posAnalog = p.posAnalog .* fliplr(imSize);
    posFreezing = p.posFreezing .* fliplr(imSize);

    videoWriter = VideoWriter(resultVidPath, 'Motion JPEG AVI');
    videoWriter.FrameRate = videoObj.FrameRate;
    videoWriter.Quality = p.quality;
    
    open(videoWriter);

    dt = 1 / videoObj.FrameRate;
    
    frameInd = 1;
    while hasFrame(videoObj)
%         if frameInd > 6000
%             break
%         end

        t = (frameInd-1) * dt;
        
        frame = readFrame(videoObj);
        
        % Heading
        frame = insertText(frame, posHeading, {heading}, 'FontSize', ...
            12, 'BoxColor', {'green'}, 'BoxOpacity', 0.4, 'TextColor', ...
            'white', 'AnchorPoint', 'Center');
        
        % Shocks
        for ss = 1:recording.numShocks()
            usEvent = recording.getShock(ss);
            if usEvent.onset <= t && t <= usEvent.onset + usEvent.duration
                frame = insertText(frame, posUS, {'US presentation'}, ...
                    'FontSize', 12, 'BoxColor', {'red'}, 'BoxOpacity', ...
                    0.4, 'TextColor', 'white', 'AnchorPoint', 'LeftCenter');
                break;
            end
        end
        
        % Sounds
        for ss = 1:recording.numSounds()
            sound = recording.getSound(ss);
            if sound.onset <= t && t <= sound.onset + sound.duration
                st = sound.type;
                frame = insertText(frame, posSound, ...
                    {['Sound presentation: ' st]}, 'FontSize', 12, ...
                    'BoxColor', {'yellow'}, 'BoxOpacity', 0.4, ...
                    'TextColor', 'white', 'AnchorPoint', 'LeftBottom');
                break;
            end
        end
        
        % Digital
        insertDigital = 0;
        digitalStr = '';
        for ee = 1:nDigChannels
            description = recording.getEventChannel('digital', ee)...
                .description;
            for ev = 1:nDigEvents(ee)
                event = recording.getDigitalEvent(ee, ev);
                if event.onset <= t && ...
                    t <= event.onset + event.duration
                    if insertDigital
                        digitalStr = [digitalStr, '; '];
                    end
                    insertDigital = 1;
                   
                    digitalStr = [digitalStr description ' (' ...
                        event.type ')'];
                    break;
                end
            end            
        end
        if insertDigital
            frame = insertText(frame, posDigital, ...
                {digitalStr}, 'FontSize', 12, ...
                'BoxColor', {'cyan'}, 'BoxOpacity', 0.4, ...
                'TextColor', 'white', 'AnchorPoint', 'LeftBottom');
        end
        
        % Analog
        insertAnalog = 0;
        analogStr = '';
        for ee = 1:nAnaChannels
            description = recording.getEventChannel('analog', ee)...
                .description;
            for ev = 1:nAnaEvents(ee)
                event = recording.getAnalogEvent(ee, ev);
                if event.onset <= t && ...
                    t <= event.onset + event.duration
                    if insertAnalog
                        analogStr = [analogStr, '; '];
                    end
                    insertAnalog = 1;
                   
                    analogStr = [analogStr description ' (' ...
                        event.type ')'];
                    break;
                end
            end            
        end
        if insertAnalog
            frame = insertText(frame, posAnalog, ...
                {analogStr}, 'FontSize', 12, ...
                'BoxColor', {'magenta'}, 'BoxOpacity', 0.4, ...
                'TextColor', 'white', 'AnchorPoint', 'LeftBottom');
        end
        
        % Freezing
        if ~p.ignoreFreezing
            isFreezing = any( ...
                frameInd >= candidate.candidateWindows(:, 1)  & ...
                frameInd <= candidate.candidateWindows(:, 2));
            if isFreezing
                frame = insertText(frame, posFreezing, ...
                    {'Freezing detected'}, 'FontSize', 12, 'BoxColor', ...
                    {'blue'}, 'BoxOpacity', 0.4, 'TextColor', ...
                    'white', 'AnchorPoint', 'RightBottom');
            end
        end
        
        % Centroids
        if ~p.ignoreCentroids
            frame = insertMarker(frame, ...
                fliplr(candidate.centroids(:, frameInd).'), 'x', ...
                'color', 'white', 'size', 10);
        end
        
        writeVideo(videoWriter, frame);
        
        frameInd = frameInd + 1;
    end

    close(videoWriter);
    delete(videoObj);
    
    disp(['Annotated video stored in ' resultVidPath]);
end

disp('Annotation successfully finished.');