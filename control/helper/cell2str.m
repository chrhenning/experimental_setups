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
@title           :cell2str.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :03/16/2018
@version         :1.0
%}

function cellString = cell2str(cellArray)
%CELL2STR This method expects a 2D cell array that either has numeric or
%string values. It converts the cell array into a string, such that it can
%be displayed.

    assert(ismatrix(cellArray));
    
    cellString = '{';
    
    for i = 1:size(cellArray, 1)
        for j = 1:size(cellArray, 2)
            if isnumeric(cellArray{i, j})
                cellString = [cellString, num2str(cellArray{i, j})];
            else
                cellString = [cellString, '''', cellArray{i, j}, ''''];
            end
            
            if j < size(cellArray, 2)
                cellString = [cellString, ','];
            end            
        end
        
        if i < size(cellArray, 1)
            cellString = [cellString, ';'];
        end  
    end
    
    cellString = [cellString, '}'];
end

