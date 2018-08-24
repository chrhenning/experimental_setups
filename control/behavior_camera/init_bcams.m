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
@title           :init_bcams.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/01/2018
@version         :1.0

Initialize the behavior cameras.
%}

function dataObj = init_bcams(dataObj)
%INIT_BCAMS Initializing the cameras as specified in the params.
    logger = log4m.getLogger();

    p = dataObj.p;
    d = dataObj.d;

    num_cams = numel(p.bcDeviceID);
    num_recs = d.numRecs;
    cams_per_rec = size(p.bcDeviceID, 2);
    
    vid_objects = cell(num_recs, cams_per_rec);
    src_objects = cell(num_recs, cams_per_rec);
    
    for i = 1:num_cams
        [r, c] = ind2sub(size(p.bcDeviceID),i);
        
        vid_objects{i} = videoinput(p.bcAdapterName{i}, ...
            p.bcDeviceID(i), p.bcFormat{i});
        src_objects{i} = getselectedsource(vid_objects{i});
        
        logger.info('init_bcams', ['Initializing behavior camera (' ...
            'adapter name: ' p.bcAdapterName{i} ', device ID: ' ...
            num2str(p.bcDeviceID(i)) ') for recording ' num2str(r) '.']);
        
        % Configure camera
        vid_objects{i}.FramesPerTrigger = p.bcFramesPerTrigger(i);
        vid_objects{i}.TriggerRepeat = p.bcTriggerRepeat;
        assert(strcmp(p.bcTriggerType, 'hardware'));
        if strcmp(p.bcCamType{i}, 'guppy')
            src_objects{i}.TriggerActivation = p.bcTriggerActivation{i};
            src_objects{i}.TriggerMode = p.bcTriggerMode;
            triggerconfig(vid_objects{i}, p.bcTriggerType, ...
                'DeviceSpecific', 'DeviceSpecific');
        else
            triggerconfig(vid_objects{i}, p.bcTriggerType, ...
                'hardware', 'hardware');
            src_objects{i}.Trigger = 'Enable';
        end
        
        if strcmp(p.bcCamType{i}, 'guppy')
            src_objects{i}.ExposureTime = p.bcExposureTime(i);
        else
            logger.warn('init_bcams', ['Property "ExposureTime" not ' ...
                'implemented for camera type "' p.bcCamType{i} ...
                '" yet.']);
        end        
        src_objects{i}.Gain = p.bcGain(i);
        
        vid_objects{i}.LoggingMode = p.bcLoggingMode;
        if cams_per_rec == 1
            vidFile = fullfile(d.expDir{r}, 'behavior.avi');
        else
            vidFile = fullfile(d.expDir{r}, ['behavior' num2str(c) ...
                '.avi']);
        end
        diskLogger = VideoWriter(vidFile, p.bcVideoFormat);
        diskLogger.FrameRate = p.bcFrameRate;
        diskLogger.Quality = p.bcQuality;
        vid_objects{i}.DiskLogger = diskLogger;

        vid_objects{i}.ROIPosition = p.bcROIPosition(r, (c-1)*4+1:c*4);
    end    

    d.bcVidObjects = vid_objects;
    d.bcSrcObjects = src_objects;
    d.refereceFrames = cell(num_recs, cams_per_rec);
    d.refereceFrameMasks = cell(num_recs, cams_per_rec);
    
    dataObj.d = d;
end

