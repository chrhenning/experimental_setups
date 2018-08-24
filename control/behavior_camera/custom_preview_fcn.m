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
@title           :custom_preview_fcn.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :06/05/2018
@version         :1.0
%}
function custom_preview_fcn(~, event, himage)
%CUSTOM_PREVIEW_FCN A custom callback for the preview function of the image
%acquisition toolbox.
    dataObj = getappdata(himage,'ParamDataObj');
    camIdx = getappdata(himage,'ParamCamIdx');
    
    p = dataObj.p;
    d = dataObj.d;

    img = event.Data;
    
    if p.useOnlineSideDetection && p.sideDetPreviewExcluded
       mask = repmat(d.refereceFrameMasks{camIdx}, 1, 1, size(img, 3)); 
       img(~mask) = 0;
    end
    
    % Rotate preview.
    img = rot90(img, p.bcPreviewRotation(camIdx));
    
    set(himage, 'cdata', img);
end

