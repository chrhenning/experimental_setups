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
@title           :preview_bcams.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/01/2018
@version         :1.0

Preview all behavior cameras, such that the user can make sure that the
cages are correctly positioned.
%}

function dataObj = preview_bcams(dataObj)
%PREVIEW_BCAMS All behavior cameras are previewed in a figure window. The
%program is stoppped until the user presses the 'ok' button. The user can
%use this to make sure that all cameras are positioned correctly before the
%start of the recording.
    global PREVIEW_WAS_CANCELLED;
    PREVIEW_WAS_CANCELLED = 0;
    
    logger = log4m.getLogger();

    p = dataObj.p;
    d = dataObj.d;

    num_cams = numel(p.bcDeviceID);
    num_recs = d.numRecs;
    cams_per_rec = size(p.bcDeviceID, 2);
    
    fig = figure('Name', 'Behavior Camera Previews', ...
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
    
    uicontrol('String', 'Ok', 'Callback', ...
        @(src,event)okClbck(dataObj));
    cncBtn = uicontrol('String', 'Cancel', 'Callback', ...
        @(src,event)cancelClbck(dataObj));
    cncBtn.Position(1) = cncBtn.Position(1) + 100;
    
    suptitle('Please check and confirm the behavior camera preview.');
    axis('square');   
    hImages = cell(num_cams, 1);
    
    num_rows = floor(sqrt(num_cams));
    num_cols = ceil(num_cams / num_rows);
    
    for r = 1:num_recs       
        for c = 1:cams_per_rec    
            i = sub2ind(size(p.bcDeviceID), r, c);
            
            vidRes = d.bcVidObjects{i}.VideoResolution; 
            nBands = d.bcVidObjects{i}.NumberOfBands; 

            subplot(num_rows, num_cols, (r-1) * cams_per_rec + c);

            hImages{i} = image( zeros(vidRes(2), vidRes(1), nBands) );

            % Some configs needs to be changed for the preview.
            if strcmp(p.bcCamType{i}, 'guppy')
                d.bcSrcObjects{i}.TriggerMode = 'Off';
            else
                d.bcSrcObjects{i}.Trigger = 'Disable';
            end
            triggerconfig(d.bcVidObjects{i}, 'immediate');
            
            setappdata(hImages{i}, 'UpdatePreviewWindowFcn', ...
                @custom_preview_fcn); 
            % Trick to pass parameters to preview function:
            setappdata(hImages{i}, 'ParamDataObj', dataObj);
            setappdata(hImages{i}, 'ParamCamIdx', i);
            
            preview(d.bcVidObjects{i}, hImages{i});   

            title(['Adaptor Name: ' p.bcAdapterName{i} ', Device ID: ' ...
                num2str(p.bcDeviceID(i)) newline ...
                'Cohort ' num2str(p.cohort(r)) ', ' ...
                'Group ' num2str(p.group(r)) ', ' ...
                'Session ' num2str(p.session(r)) ', ' ...
                'Subject ' num2str(p.subject(r)) newline ...
                'Camera ' num2str(c) ' of recording.']);

            set(gca,'Visible','off')
            set(get(gca,'Title'),'Visible','on')
        end
    end

    % Make sure that previews keep their size.
    axesHandles = findobj(get(gcf,'Children'), 'flat', 'Type', 'axes');
    axis(axesHandles, 'equal')
    
    logger.info('preview_bcams', ['Please confirm the camera settings ' ...
        'as shown in the preview window by clicking "ok".']);
    waitfor(fig);
    if PREVIEW_WAS_CANCELLED
        myError('preview_bcams', 'Video preview was cancelled.');
    end
    clear 'PREVIEW_WAS_CANCELLED';
    
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
    
    dataObj.d = d;
end

function closeReqClbck(dataObj)
%CLOSEREQCLBCK The 'Ok' or 'Cancel' have their own callbacks. If another
%event is attempting to close the figure, then we treat it as pressing the
%'Cancel' button.
    cancelClbck(dataObj);
end

function cancelClbck(dataObj)
    global PREVIEW_WAS_CANCELLED;

    for i = 1:length(dataObj.d.bcVidObjects)
        stoppreview(dataObj.d.bcVidObjects{i});
        delete(dataObj.d.bcVidObjects{i});
    end
    
    % Clean up Online Side Detection.
    if dataObj.p.useOnlineSideDetection
        stop(dataObj.d.sideDetectionTimer);
        delete(dataObj.d.sideDetectionTimer);
        fclose(dataObj.d.serialCommObj);
    end
    
    PREVIEW_WAS_CANCELLED = 1;
    delete(gcf);
end

function okClbck(~)
    delete(gcf);
end

