% Copyright 2018 Christian Henning, Benjamin Ehret
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
@title           :side_detection.m
@author          :ch, be
@contact         :christian@ini.ethz.ch
@created         :06/01/2018
@version         :1.0

Implementation of an online mouse side detection.
%}

function dataObj = side_detection(dataObj)
%SIDE_DETECTION The online mouse side detection algorithms detects the
%chamber the mouse is in during the duration of the session and sends this
%position via a serial port to an arduino.
%
%   The method creates and plots the reference frames (used for the subject
%   detection) and asks the user to approve them.
%   Furthermore, the method sets up the arduino communication and will
%   create a timer object that periodically sends the current detected
%   position to the arduino. Additionally, a callback is initialized that
%   looks at recently acquired frames to detect the position of the mouse
%   (or more precisely, the camera which has the subject in its FOV).
    logger = log4m.getLogger();
    
    p = dataObj.p;
    
    if ~p.useOnlineSideDetection
        return;
    end
        
    d = dataObj.d;

    num_cams = numel(p.bcDeviceID);
    num_recs = d.numRecs;
    cams_per_rec = size(p.bcDeviceID, 2);
    
    % Should have been checked before.
    assert(cams_per_rec == 2);
    
    %% Load prior info.
    % I.e., reference frames and ROIs that are equal for all recordings.
    if p.sideDetUsePriorRefFrames || p.sideDetUsePriorExcluded
        file_name = fullfile(p.rootDir, 'misc', 'prior_ref_frames', ...
            'reference_frames.mat');
        load(file_name, 'prior_device_ids', 'prior_reference_frames', ...
            'prior_roi_masks');
        for i = 1:num_cams
            cam_id = p.bcDeviceID(i);
            ind = find(prior_device_ids(:) == cam_id, 1);
            if isempty(ind)
                logger.warn('side_detection', ['No reference frame ' ...
                    'given for camera with id: ' num2str(cam_id) '.']);
            end
            
            if p.sideDetUsePriorRefFrames
                d.refereceFrames{i} = prior_reference_frames{ind};
            end
            if p.sideDetUsePriorExcluded
                d.refereceFrameMasks{i} = prior_roi_masks{ind};
            end
        end
    end
    
    %% Take reference frames.
    % For the online detection, we need reference frames
    % with the mouse not being in the cage yet.
    for r = 1:num_recs       
        for c = 1:cams_per_rec    
            i = sub2ind(size(p.bcDeviceID), r, c);
            
            if ~isempty(d.refereceFrames{i}) % See "Load prior info".
                continue;
            end

            % Generate reference frames before we display the preview (such
            % that the user can use the preview to put the subject into the
            % cage. We need the 'immediate' camera trigger config to 
            % acquire images without an external trigger.
            if strcmp(p.bcCamType{i}, 'guppy')
                d.bcSrcObjects{i}.TriggerMode = 'Off';
            else
                d.bcSrcObjects{i}.Trigger = 'Disable';
            end
            triggerconfig(d.bcVidObjects{i}, 'immediate');

            % Warning, that disk logger cannot be used, but we know  that.
            warning('off', 'all'); 
            d.bcVidObjects{i}.LoggingMode = 'memory';
            start(d.bcVidObjects{i});
            % We need to make a couple of images, as the camera needs to
            % adapt to the illumination.
            pause(1); 
            warning('on', 'all');
            d.refereceFrames{i} = ...
                mean(peekdata(d.bcVidObjects{i}, 1), 3);
            stop(d.bcVidObjects{i})
            d.bcVidObjects{i}.LoggingMode = p.bcLoggingMode;
        end
    end
    
    % Undo the temporary changes in the camera configuration.
    for i = 1:num_cams 
        if strcmp(p.bcCamType{i}, 'guppy')
        	d.bcSrcObjects{i}.TriggerMode = p.bcTriggerMode;
            triggerconfig(d.bcVidObjects{i}, p.bcTriggerType, ...
                'DeviceSpecific', 'DeviceSpecific');
        else
            triggerconfig(d.bcVidObjects{i}, p.bcTriggerType, ...
                'hardware', 'hardware');
            d.bcSrcObjects{i}.Trigger = 'Enable';
        end
    end
    
    % Show reference frames to user and request approval.
    dataObj.d = d;
    dataObj = plot_ref_frames(dataObj);
    d = dataObj.d;

    %% Initialize serial communication with arduino.
    ardCom = serial(p.sideDetSerialPort, 'BaudRate', 9600);
    fopen(ardCom);
    % This pause is necessary, as the serial communication needs ti build
    % up before we can send data for the first time (data send directly
    % after fopen is dropped).
    pause(0.1);
    
    %% Setup online side detection.
    % A variable, that will contain the difference of each camera with the
    % reference images.
    global camRefDiff;
    camRefDiff = ones(num_recs, cams_per_rec) * -1;
    
    % Periodically, calculate the difference to the reference image.
    % We want to update this estimate at least every 500ms:
    updateCount = min(5, ceil(0.5 / (1.0 / p.bcFrameRate)));
    for i = 1:num_cams
        d.bcVidObjects{i}.FramesAcquiredFcn = {'calc_deviation', ...
            d.refereceFrames{i}, d.refereceFrameMasks{i}, i};     
        d.bcVidObjects{i}.FramesAcquiredFcnCount = updateCount;
    end
    
    % This timer will periodically check the 'camRefDiff' values and
    % communicate the result to the arduino.
    sideDetTimer = timer('BusyMode', 'drop', 'Period', .2, ...
          'ExecutionMode', 'fixedRate');
    sideDetTimer.TimerFcn = {@detect_subject_side, ardCom};
    start(sideDetTimer);

    d.serialCommObj = ardCom;
    d.sideDetectionTimer = sideDetTimer;
        
    dataObj.d = d;
end



function detect_subject_side(~, ~, ardCom)
% DETECT_SUBJECT_SIDE This method compares the values in 'camRefDiff' and
% communicates the current position to the arduino.
    global camRefDiff
    
    if any(camRefDiff == -1)
        return;
    end
    
    num_recs = size(camRefDiff, 1);
    % FIXME We should support communicating with multiple arduinos.
    assert(num_recs == 1);

    if camRefDiff(1) > camRefDiff(2)
        fprintf(ardCom, '%u', 0); % left
    else
        fprintf(ardCom, '%u', 1); % right
    end
end

function dataObj = plot_ref_frames(dataObj)
%PLOT_REF_FRAMES Plot the reference frames and allow the user to select an
%area that should be ignored (where the FOV of both cameras intersect). The
%user needs to approve those reference frames.
    % We cannot throw an error inside "cancelClbck", as this function is
    % executed within another thread. We need to throw the error in the
    % current thread.
    throwError = 0;

    function cancelClbck(currFig, dataObj)
        for vidInd = 1:length(dataObj.d.bcVidObjects)
            delete(dataObj.d.bcVidObjects{vidInd});
        end

        throwError = 1;
        delete(currFig);
    end

    function okClbck(currFig, ~)
        delete(currFig);
    end

    function closeReqClbck(dataObj)
    %CLOSEREQCLBCK The 'Ok' or 'Cancel' have their own callbacks. If 
    %another event is attempting to close the figure, then we treat it as 
    %pressing the 'Cancel' button.
        cancelClbck(gcf, dataObj);
    end

    function roiClbck(currAxes, ~, refFrame, camInd)
        %ROICLBCK Get an ROI mask for a subplot.
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
        roiMasks{camInd} = ~binaryMask;        
    end

    logger = log4m.getLogger();
    
    p = dataObj.p;
    d = dataObj.d;
    
    num_cams = numel(p.bcDeviceID);
    num_recs = d.numRecs;
    cams_per_rec = size(p.bcDeviceID, 2);
    
    roiMasks = d.refereceFrameMasks;
    
    num_rows = floor(sqrt(num_cams));
    num_cols = ceil(num_cams / num_rows);
    
    fig = figure('Name', 'Camera Reference Frames', ...
        'CloseRequestFcn', @(src,event)closeReqClbck(dataObj));
    
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
    
    uicontrol('String', 'Accept', 'Callback', ...
        @(src,event)okClbck(fig, dataObj));
    cncBtn = uicontrol('String', 'Cancel', 'Callback', ...
        @(src,event)cancelClbck(fig, dataObj));
    cncBtn.Position(1) = cncBtn.Position(1) + 100;
    
    suptitle('Reference Frames used for the Online Cage Side Detection');
    
    for r = 1:num_recs       
        for c = 1:cams_per_rec    
            i = sub2ind(size(p.bcDeviceID), r, c);
            
            ref_frame = mat2gray(d.refereceFrames{i});
            
            currAxes = subplot(num_rows, num_cols, ...
                (r-1) * cams_per_rec + c);
            
            if ~isempty(roiMasks{i})
                img = d.refereceFrames{i};
                img(~roiMasks{i}) = 0;
                img = mat2gray(img);
                
                imshow(rot90(img, p.bcPreviewRotation(i)));
            else
                imshow(rot90(ref_frame, p.bcPreviewRotation(i)));
            end
            
            title(['Adaptor Name: ' p.bcAdapterName{i} ', Device ID: ' ...
                num2str(p.bcDeviceID(i)) newline ...
                'Camera ' num2str(c) ' of recording ' num2str(c) '.']);

            set(currAxes, 'Visible', 'off')
            set(get(currAxes, 'Title'), 'Visible', 'on')
            
            % Create a button for each subplot, that can be used to draw a
            % polygon of a region that should be ignored when computing the
            % mouse side position.
            subPos = get(currAxes, 'position');
            roiBtn = uicontrol('String', 'Exclude Area', 'Callback', ...
                @(src,event)roiClbck(currAxes, dataObj, ref_frame, i));
            set(roiBtn, 'units', get(currAxes, 'units'));
            btnPos = get(roiBtn, 'position');
            xPos = (subPos(3) - btnPos(3)) / 2 + subPos(1);
            yPos = subPos(2) - .01;
            btnPos = [xPos yPos, btnPos(3:4)];
            set(roiBtn, 'position', btnPos);
            
            % Store reference image in result folder.
            file_name = fullfile(d.expDir{r}, ['reference_frame' ...
                num2str(c) '.png']);
            imwrite(ref_frame, file_name);
        end
    end
    
    logger.info('side_detection', ['Please confirm the reference ' ...
        'frames by clicking "accept".']);
    waitfor(fig);
    
    if throwError
        myError('side_detection', 'Reference frames where not accepted.');
    end
    
    % Store ROI masks, if existing.
    for r = 1:num_recs       
        for c = 1:cams_per_rec    
            i = sub2ind(size(p.bcDeviceID), r, c);
            
            if ~isempty(roiMasks{i})
                file_name = fullfile(d.expDir{r}, ...
                    ['reference_frame_mask' num2str(c) '.png']);
                imwrite(roiMasks{i}, file_name);
            else
                roiMasks{i} = ones(size(d.refereceFrames{i}));
            end
        end
    end
    
    dataObj.d.refereceFrameMasks = roiMasks;
end

