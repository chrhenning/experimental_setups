% Copyright 2017 Christian Henning
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
@title           :cam_previews.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :12/20/2017
@version         :1.0

Open a preview window for several connected  cameras.
%}

function cam_previews( adaptor_names, device_ids )
%CAM_PREVIEWS Display a camera preview for multiple cameras.
%   CAM_PREVIEWS( adaptor_names, device_ids )
%
%   Function has only be tested with Allied Vision Guppy PRO F125B.
%
%   Examples:
%   cam_previews({'gentl', 'gentl'}, [1, 2])

    assert(~isempty(adaptor_names) && ...
        length(adaptor_names) == length(device_ids));
    
    
    num_cams = length(adaptor_names);
    vid_objects = cell(num_cams, 1);
    
    for i = 1:num_cams
        vid_objects{i} = videoinput(adaptor_names{i}, device_ids(i), ...
            'Mono8');
    end
    
    figure('Name', 'Camera Previews');
    try
        pause(0.00001);
        frame_h = get(handle(gcf),'JavaFrame');
        set(frame_h,'Maximized',1); 
    catch
        warning('Could not maximize window.');
    end

    uicontrol('String', 'Close', 'Callback', ...
        @(src,event)closeClbck(vid_objects));
    axis('square');    
    num_rows = floor(sqrt(num_cams));
    num_cols = ceil(num_cams / num_rows);
    
    %disp(['#Rows ' num2str(num_rows) ', #Columns: ' num2str(num_cols)]);
    
    hImages = cell(num_cams, 1);
    
    for i = 1:num_cams
        %r = floor((i-1) / num_cols) + 1;
        %c = mod(i, num_cols + 1);
        %disp(['Row ' num2str(r) ', Column: ' num2str(c)]);
        
        vidRes = vid_objects{i}.VideoResolution; 
        nBands = vid_objects{i}.NumberOfBands; 
        
        subplot(num_rows, num_cols, i);
        
        hImages{i} = image( zeros(vidRes(2), vidRes(1), nBands) );
        preview(vid_objects{i}, hImages{i});   
        
        title(['Adaptor Name: ' adaptor_names{i} ', Device ID: ' ...
            num2str(device_ids(i))]);
        set(gca,'Visible','off')
        set(get(gca,'Title'),'Visible','on')
    end
    
    % Make sure that previews keep their size.
    axesHandles = findobj(get(gcf,'Children'), 'flat', 'Type', 'axes');
    axis(axesHandles, 'equal')
end

function closeClbck(vid_objects)
    for i = 1:length(vid_objects)
        delete(vid_objects{i});
    end
    close(gcf);
end
