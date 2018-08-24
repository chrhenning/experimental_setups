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
@title           :evaluation.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/08/2018
@version         :1.0

This script controls the evaluation of a fear conditioning experiment. The
process is configured by the file params.m residing in this folder.

Please run this script to start the evaluation.
%}
% Just to clarify the naming conventions. Each experiment consists of
% groups which are tested in sessions. In each session, test all mice
% belonging to the group:
%    experiment -> groups -> sessions -> mice
% Each unique item, identified by its experiment, group, session and mouse
% is called a "recording".

%% Setup evaluation.
addpath(genpath('../../lib'));
addpath(genpath('../../misc/experiment_design'));
addpath(genpath(fileparts(mfilename('fullpath'))));

p = params();

deletedPrevResults = false;
% Remove previous results, if existing and allowed.
if p.deletePrevResults && exist(p.resultDir, 'file') == 7
    deletedPrevResults = true;
    rmdir(p.resultDir, 's');
% If we are not allow, we don't overwrite results.
elseif ~p.deletePrevResults && exist(p.resultDir, 'file') == 7
    error(['Aborted program. Directory ' p.resultDir ' already exists.']);
end

mkdir(p.resultDir);

% Initialize logger.
clear('log4m'); % We want a new logfile.
logger = log4m.getLogger(fullfile(p.resultDir, 'logfile.txt'));
logger.setCommandWindowLevel(logger.INFO); 
logger.setLogLevel(logger.ALL);

if deletedPrevResults
    logger.warn('evaluation', ...
        ['Deleted previous results in directory: ' p.resultDir '.']);
end

% Backup params.
paramsPath = fullfile(p.resultDir, 'params.mat');
save(paramsPath, 'p');

%% Read and structure data for all recordings.
recordings = organizeRecordings(p);
logger.info('evaluation', ['Found ' num2str(length(recordings.recs)) ...
    ' recordings to evaluate.']);
assert(~isempty(recordings.recs));

%% Check sound onset accuracy.
soundOnsetAccuracy(p, recordings);

%% Plot or display all major evaluation measures.
evalControl(p, recordings);

logger.info('evaluation', 'Evaluation finished successfully.');
