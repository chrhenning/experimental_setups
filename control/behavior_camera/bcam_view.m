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
@title           :bcam_view.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/01/2018
@version         :1.0

A figure that shows the live image of all cameras during the recording.
%}

function dataObj = bcam_view(dataObj)
%BCAM_VIEW Show live image of behavior cameras.
%
%   Note, this function will not start the acquisition yet.
    logger = log4m.getLogger();
    logger.info('bcam_view', 'Starting behavior camera live view.');

    p = dataObj.p;
    d = dataObj.d;

    num_cams = numel(p.bcDeviceID);
    num_recs = d.numRecs;
    cams_per_rec = size(p.bcDeviceID, 2);
    
    % NOTE, we add the subplots to an uipanel, as we can't add suplots to
    % an axes that is within the GUIDE figure. However, for some reasone,
    % we cannot set the current figure (using figPanel.Parent) nor the
    % current axes (I tried various methods to set gca and gcf). The reason
    % is not quite clear. Hence, one always has to set which figure and
    % axes has to be used in the following code.
    figPanel = d.recView.getBCamPanel();
    
    % FIXME dirty solution to maximize the window.
    try
        warning('off', 'all')
        pause(0.1);
        frame_h = get(handle(figPanel.Parent), 'JavaFrame');
        set(frame_h, 'Maximized', 1); 
        pause(0.1);
        warning('on', 'all')
    catch
        warning('Could not maximize window.');
    end
    
    subplots = cell(1, num_cams); 
    hImages = cell(num_cams, 1);
    
    num_rows = floor(sqrt(num_cams));
    num_cols = ceil(num_cams / num_rows);
    
    for r = 1:num_recs       
        for c = 1:cams_per_rec    
            i = sub2ind(size(p.bcDeviceID), r, c);
            
            vidRes = d.bcVidObjects{i}.VideoResolution; 
            nBands = d.bcVidObjects{i}.NumberOfBands; 

            subplots{i} = subplot(num_rows, num_cols, ...
                (r-1) * cams_per_rec + c, 'Parent', figPanel);

            hImages{i} = image(subplots{i}, zeros(vidRes(2), vidRes(1), ...
                nBands));

            setappdata(hImages{i}, 'UpdatePreviewWindowFcn', ...
                @custom_preview_fcn); 
            % Trick to pass parameters to preview function:
            setappdata(hImages{i}, 'ParamDataObj', dataObj);
            setappdata(hImages{i}, 'ParamCamIdx', i);
            
            preview(d.bcVidObjects{i}, hImages{i});   

            title(subplots{i}, ['Cohort ' num2str(p.cohort(r)) ', ' ...
                'Group ' num2str(p.group(r)) ', ' ...
                'Session ' num2str(p.session(r)) ', ' ...
                'Subject ' num2str(p.subject(r)) newline ...
                'Camera ' num2str(c) ' of recording.' newline ...
                'Frames acquired: ' ...
                num2str(d.bcVidObjects{i}.FramesAcquired)]);

            set(subplots{i}, 'Visible', 'off')
            set(get(subplots{i}, 'Title'), 'Visible', 'on')
            
            %axis(subplots{i}, 'equal')
            axis(subplots{i}, 'image')
        end
    end    
    
    % Timer, that updates the frames acquired yet.
    t = timer('BusyMode', 'drop', 'Period', 0.5, ...
          'ExecutionMode', 'fixedRate');
    t.TimerFcn = {@updateView, dataObj, subplots};
    d.bcFigureTimer = t;
    
    start(t);  
    
    dataObj.d = d;
end

function updateView(~, ~, dataObj, subplots)
    global camRefDiff;
    
    p = dataObj.p;
    d = dataObj.d;

    num_cams = numel(p.bcDeviceID);
    
    if p.useOnlineSideDetection
        [~, mouseOnCam] = max(camRefDiff, [], 2);
    end
    
    for i = 1:num_cams                
        [r, c] = ind2sub(size(p.bcDeviceID), i);
        
        mouseDetectionString = '';
        if p.useOnlineSideDetection && mouseOnCam(r) == c
            mouseDetectionString = [newline, ...
                'Subject detected on this camera.'];
        end
        
        title(subplots{i}, ['Cohort ' num2str(p.cohort(r)) ', ' ...
            'Group ' num2str(p.group(r)) ', ' ...
            'Session ' num2str(p.session(r)) ', ' ...
            'Subject ' num2str(p.subject(r)) newline ...
            'Camera ' num2str(c) ' of recording.' newline ...
            'Frames acquired: ' ...
            num2str(d.bcVidObjects{i}.FramesAcquired), ...
            mouseDetectionString]);
    end
end
