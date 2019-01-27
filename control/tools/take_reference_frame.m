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
@title           :take_reference_frame.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :05/06/2018
@version         :1.0

This script can be used to generate reference frames and select areas to
exclude as needed for the "Online Side Detection" algorithm, that can be
used in active avoidance experiments. The params.m file must already have
been initialized.

The stored reference frames and excluded areas can be identified by the
device ID of the camera. The results will be stored in the "misc" folder of
the experiment its root directory.

The prior selection should help to avoid selecting the same ROI for each
session, even though the camera position is fixed. The same accounts for
the reference frames.
%}
global roi_masks;

addpath(genpath('..'));
p = params();
% Ensure, that no assertion fails, because we haven't yet created the ROIs
% and reference frames.
useOnlineSideDetection = p.useOnlineSideDetection;
p.useOnlineSideDetection = 0;
p = preprocessParams(p);
p.useOnlineSideDetection = useOnlineSideDetection;

num_cams = numel(p.bcDeviceID);
num_recs = size(p.bcDeviceID, 1);
cams_per_rec = size(p.bcDeviceID, 2);

vid_objects = cell(num_recs, cams_per_rec);
src_objects = cell(num_recs, cams_per_rec);
ref_frames = cell(num_recs, cams_per_rec);
roi_masks = cell(num_recs, cams_per_rec);

%% Initialize cameras
for i = 1:num_cams
    [r, c] = ind2sub(size(p.bcDeviceID), i);

    vid_objects{i} = videoinput(p.bcAdapterName{i}, ...
        p.bcDeviceID(i), p.bcFormat{i});
    src_objects{i} = getselectedsource(vid_objects{i});

    % Configure camera
    vid_objects{i}.FramesPerTrigger = p.bcFramesPerTrigger(i);
    vid_objects{i}.TriggerRepeat = p.bcTriggerRepeat;
    if strcmp(p.bcCamType{i}, 'guppy')
        src_objects{i}.TriggerActivation = p.bcTriggerActivation{i};
        src_objects{i}.TriggerMode = 'Off';
    else
        src_objects{i}.Trigger = 'Disable';
    end
    triggerconfig(vid_objects{i}, 'immediate');

    if strcmp(p.bcCamType{i}, 'guppy')
        src_objects{i}.ExposureTime = p.bcExposureTime(i);
    else
        warning(['Property "ExposureTime" not implemented for camera '...
            'type "' p.bcCamType{i} '" yet.']);
    end        
    src_objects{i}.Gain = p.bcGain(i);

    vid_objects{i}.LoggingMode = 'memory';

    vid_objects{i}.ROIPosition = p.bcROIPosition(r, (c-1)*4+1:c*4);
end    

%% Take reference frames.
for r = 1:num_recs       
    for c = 1:cams_per_rec    
        i = sub2ind(size(p.bcDeviceID), r, c);

        start(vid_objects{i});
        % We need to make a couple of images, as the camera needs to
        % adapt to the illumination.
        pause(1); 
        ref_frames{i} = mean(peekdata(vid_objects{i}, 1), 3);
        stop(vid_objects{i});
        
        % Initialize ROI mask.
        roi_masks{i} = ones(size(ref_frames{i}));
    end
end

%% Plot reference frames and ask for ROIs.  
fig = figure('Name', 'Camera Reference Frames');

num_rows = floor(sqrt(num_cams));
num_cols = ceil(num_cams / num_rows);

% FIXME dirty solution to maximize the window.
try
    warning('off','all')
    pause(0.00001);
    frame_h = get(handle(gcf),'JavaFrame');
    set(frame_h,'Maximized',1); 
    warning('on','all')
catch
    warning('Could not maximize window.');
end

uicontrol('String', 'Save', 'Callback', ...
    @(src,event)saveClbck(fig, p, ref_frames));

suptitle('Reference Frames used for the Online Cage Side Detection');

for r = 1:num_recs       
    for c = 1:cams_per_rec    
        i = sub2ind(size(p.bcDeviceID), r, c);

        ref_frame = mat2gray(ref_frames{i});

        currAxes = subplot(num_rows, num_cols, ...
            (r-1) * cams_per_rec + c);
        imshow(rot90(ref_frame, p.bcPreviewRotation(i)));

        title(['Adaptor Name: ' p.bcAdapterName{i} ', Device ID: ' ...
            num2str(p.bcDeviceID(i))]);

        set(currAxes, 'Visible', 'off')
        set(get(currAxes, 'Title'), 'Visible', 'on')

        % Create a button for each subplot, that can be used to draw a
        % polygon of a region that should be ignored when computing the
        % mouse side position.
        subPos = get(currAxes, 'position');
        roiBtn = uicontrol('String', 'Exclude Area', 'Callback', ...
            @(src,event)roiClbck(currAxes, ref_frame, i, p));
        set(roiBtn, 'units', get(currAxes, 'units'));
        btnPos = get(roiBtn, 'position');
        xPos = (subPos(3) - btnPos(3)) / 2 + subPos(1);
        yPos = subPos(2) - .01;
        btnPos = [xPos yPos, btnPos(3:4)];
        set(roiBtn, 'position', btnPos);
    end
end

disp(['Please select areas to exclude from the "side detection" and ' ...
    'press "save".']);
waitfor(fig);

%% Clean up behavior cameras.
for i = 1:numel(p.bcDeviceID)
   delete(vid_objects{i}); 
end

function saveClbck(currFig, p, ref_frames)
%SAVECLBCK Save the reference frames and ROI's to a folder.
    global roi_masks;

    delete(currFig);
    
    [ids, inds] = unique(p.bcDeviceID);
    assert(numel(ids) == numel(inds));
    
    save_dir = fullfile(p.rootDir, 'misc', 'prior_ref_frames');
    if exist(save_dir, 'file') ~= 7
        disp(['Creating directory: ' save_dir]);
        mkdir(save_dir);
    end
    
    % Write README file.
    fid = fopen(fullfile(save_dir, 'README.txt'), 'w');
    fprintf(fid, ['File created: %s.\r\nReference frames and excluded ' ...
        'areas of the "Online Side Detection" algorithm.\r\nThis file ' ...
        'has been generated by the script "take_reference_frame".'], ...
        datestr(datetime('now')));
    fclose(fid);
    
    prior_device_ids = p.bcDeviceID;
    prior_reference_frames = ref_frames;
    prior_roi_masks = roi_masks;
    
    file_name = fullfile(save_dir, 'reference_frames.mat');
    save(file_name, 'prior_device_ids', 'prior_reference_frames', ...
        'prior_roi_masks', '-v7.3');
    
    disp(['Reference frames and excluded areas have been successfully ' ...
        'stored into ' file_name '.']);
end

function roiClbck(currAxes, refFrame, camInd, p)
%ROICLBCK Get an ROI mask for a subplot.
    global roi_masks;
    
    roi = impoly(currAxes);
    polyPos = getPosition(roi);
    x = polyPos(:,1); 
    y = polyPos(:,2);
    binaryMask = poly2mask(x, y, size(refFrame, 1), ...
        size(refFrame, 2));
    % We need to invert the preview rotation.
    binaryMask = rot90(binaryMask, ...
        mod(4 - p.bcPreviewRotation(camInd), 4));
    % We invert the mask, as we want to exclude the selected part.
    roi_masks{camInd} = ~binaryMask;        
end
