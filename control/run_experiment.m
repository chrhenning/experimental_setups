% Copyright 2018 Christian Henning, Rik Ubaghs
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
@title           :run_experiment.m
@author          :ch, ru
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0

This script controls the Fear Conditioning setup.

The data acquisition of recordings is parametrized in the file params.m.
%}
clear 'data'

addpath(genpath('../lib'));
addpath(genpath('../misc'));
addpath(genpath(fileparts(mfilename('fullpath'))));

%% Setup recordings
% Get parameters.
p = params();
p = preprocessParams(p);

% A data container that comprises all infos need by subfunctions.
data = struct();
data.p = p;
data.d = struct();

% Make sure that rootDir exists.
if exist(p.rootDir, 'file') ~= 7
    disp(['Creating root directory: ' p.rootDir]);
    mkdir(p.rootDir);
end

% Make sure experiment dir does not exist yet.
data.d.numRecs = length(p.cohort);
numRecs = data.d.numRecs;

data.d.expDir = cell(1, numRecs);
prevExpDeleted = zeros(1, numRecs);
for i = 1:numRecs
    
    data.d.expDir{i} = fullfile(p.rootDir, ...
        DesignIterator.getRelFolder(p.cohort(i), p.group(i), ...
            p.session(i), p.subject(i)));
    expDir = data.d.expDir{i};
    
    % Remove previous results, if existing.
    if exist(expDir, 'file') == 7
        choice = questdlg(['The experiment folder already exists.' ...
                newline 'Do you want to delete the old experiment?' ...
                newline newline expDir], ...
            'Folder already exists', 'Yes', 'No', 'Cancel', 'Cancel');

        if strcmp(choice, 'Yes')
            rmdir(expDir, 's');
            prevExpDeleted(i) = 1;
        else
            error(['FATAL: Experiment cancelled. Cannot overwrite ' ...
                   'previous results.']);
        end
    end

    if ~isdir(expDir)
        mkdir(expDir);
    end
end

% Initialize logger.
% We create one log file in the first recording its folder. At the end, we
% copy them to all the other fodlers.
clear('log4m'); % We want a new logfile.
logfile = fullfile(data.d.expDir{1}, 'logfile.txt');
logger = log4m.getLogger(logfile);
logger.setCommandWindowLevel(logger.ALL); 
logger.setLogLevel(logger.ALL);

logger.info('run_experiment', ['There will be ' num2str(numRecs) ...
    ' recording(s) controlled in this run.']);

for i = 1:numRecs
    if prevExpDeleted(i)
        logger.warn('run_experiment', ['Previous experimental ', ...
            'results in folder ', data.d.expDir{i}, ' were deleted!']);
    end
    
    logger.info('run_experiment', ['Results of recording ' num2str(i) ...
        ' will be stored in folder ', data.d.expDir{i}, '.']);
end

%% Backup params file, to allow reproducibility.
for i = 1:numRecs
    save(fullfile(data.d.expDir{i}, 'params.mat'), 'p');
end

%% Load design file, if any.
if p.useDesignFile
    data = readDesign(data);
else
    logger.info('run_experiment', 'Auto-generating a design ...');
    data = createSimpleDesign(data);
end
data = checkDesignCompatibility(data);

%% Configure Cameras and Preview The Screens
data = init_bcams(data);
data = side_detection(data);
data = preview_bcams(data);

%% Open live view of behavior cameras
data = bcam_view(data);

logger.info('run_experiment', 'Starting behavior camera acquisition.');
for i = 1:numel(p.bcDeviceID)
   start(data.d.bcVidObjects{i}); 
end

%% Create and configure session.
daqSession = daq.createSession('ni');
daqSession.Rate = p.rateDAQ;
if daqSession.Rate ~= p.rateDAQ
    logger.warn('run_experiment', ['Hardware could not realize the ' ...
        'sound sampling rate. Instead, it uses the sampling rate: ' ...
        num2str(daqSession.Rate)]);
    % FIXME: Should we resample all events to match the new sampling rate?
    % This is commented because it hasn't been tested yet.
%     for i = 1:numRecs
%         data.d.subjects{i} = ...
%            data.d.subjects{i}.setCommonSmpRate(daqSession.Rate, false);
%     end
end

daqSession.UserData.d = data.d;
daqSession.UserData.p = data.p;
clear('data');

if p.useBulkMode
    daqSession.IsContinuous = false;
    logger.info('run_experiment', 'Running NIDAQ session in bulk mode.');
else
    daqSession.IsContinuous = true;
    % FIXME, maybe that should be another parameter.
    daqSession.NotifyWhenScansQueuedBelow = ...
        min(p.continuousWin, daqSession.UserData.d.duration) * ...
        daqSession.Rate;
    logger.info('run_experiment', ['Running NIDAQ session in ' ...
        'continuous mode with a queue size of ' ...
        num2str(p.continuousWin) ' seconds.']);
end

daqSession = setupChannels(daqSession);
daqSession.UserData.d.errorListener = ...
    addlistener(daqSession, 'ErrorOccurred', @errorCallback);

%% Setup Acquisition Trigger if activated.
daqSession = setupAcquisitionTrigger(daqSession);

%% Setup Input Recording
daqSession = setInputListener(daqSession);

%% Setup queueing the output data.
daqSession = setOutputListener(daqSession);
% Queue either whole bulk or first chunk.
queueOutputDesign(daqSession);

%% Plotting recording design for user.
% TODO: Plot (downsampled) data for whole recording.

%% Run NIDAQ Session
prepare(daqSession);

logger.info('run_experiment', 'Session is starting now ... ');
startBackground(daqSession);
% TODO, request actual time step from first input listener callback.
sessionStartTime = tic; 

if p.useExtTrigger
    logger.info('run_experiment', 'Waiting for external trigger ... ');
end

% Play sounds via soundcard.
if p.useSoundCard
    % FIXME sessionStartTime is incorrect when using external trigger.
    if p.useExtTrigger
        myError('run_experiment', ['"p.useSoundCard" not implemented ' ...
            'to work with "p.useExtTrigger".']);
    end
    
    playSounds(daqSession, sessionStartTime);
end

maxWaitDur = daqSession.UserData.d.duration + max(10, p.continuousWin);
if p.useExtTrigger
    maxWaitDur = maxWaitDur + p.extTriggerTimeout;
end
wait(daqSession, maxWaitDur);
logger.info('run_experiment', 'Session finished.');

%% Clean up
% Clean up DAQ session
delete(daqSession.UserData.d.inputListener);
delete(daqSession.UserData.d.errorListener);
if ~p.useBulkMode
    delete(daqSession.UserData.d.outputListener);
end
release(daqSession);

% Clean up Online Side Detection.
if p.useOnlineSideDetection
    stop(daqSession.UserData.d.sideDetectionTimer);
    delete(daqSession.UserData.d.sideDetectionTimer);
    fclose(daqSession.UserData.d.serialCommObj);
end

% Clean up behavior cameras.
for i = 1:numel(p.bcDeviceID)
   stop(daqSession.UserData.d.bcVidObjects{i}); 
end
stop(daqSession.UserData.d.bcFigureTimer);
delete(daqSession.UserData.d.bcFigureTimer);
close(daqSession.UserData.d.bcFigure);
for i = 1:numel(p.bcDeviceID)
   delete(daqSession.UserData.d.bcVidObjects{i}); 
end

%% Convert binary input/output data files to mat files.
% FIXME to convert the binary data into mat files we currently read it all
% at once in the memory.
logger.warn('run_experiment', ['Attempting to convert binary data ' ...
    'into mat file. Note, this might crash as it is very memory ' ...
    'exhaustive.']);
bin2matInput(daqSession);
% TODO user should be able to decide whether he wants to store all the data
% send to the NIDAQ.
bin2matOutput(daqSession);

logger.info('run_experiment', 'Recordings finished sucessfully.');

% Copy logfile to folder of remaining recordings.
clear('log4m');
for i = 2:numRecs
    status = copyfile(logfile, ...
        fullfile(daqSession.UserData.d.expDir{i}, 'logfile.txt'));
    if ~status
        warning(['Could not copy logfile to folder ' ...
            daqSession.UserData.d.expDir{i} '.']);
    end
end