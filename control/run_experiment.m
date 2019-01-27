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

% A data container that comprises all infos needed by subfunctions.
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

%% Global Variables used in this Program
% This flag is set to true, if the function myError is called.
global errorOccurredDuringSession;
errorOccurredDuringSession = 0;
% This flag is set, when the user requests to pause resp. continue (if
% already pausing) the session.
global requestingPauseRespCont;
requestingPauseRespCont = 0;
% The data written in the input callback is corrected such that pauses are
% not written to the file. This is an exploratory feature for now and might
% thus fail. We need to notify the user if this is the case.
global inputDataCorrectionFailed;
inputDataCorrectionFailed = 0;

%% Configure Cameras and Preview The Screens
data = init_bcams(data);
data = side_detection(data);
data = preview_bcams(data);

%% Open live view of behavior cameras
recView = RecViewCtrl();
data.d.recView = recView;
data = recView.openGUI(data);

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
% This is later updated from the actual start time given to the input
% listener.
sessionStartTime = now(); 

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

if daqSession.UserData.d.recView.hasRecStopped()
    logger.warn('run_experiment', 'Session has been stopped by user.');
else
    logger.info('run_experiment', 'Session finished.');
end

% Save from cleanup.
sessionInterrupted = daqSession.UserData.d.recView.hasRecStopped();

%% Clean up
cleanupProgram(daqSession);
release(daqSession);

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

% Save the output windows to a file for debugging purposes and if the input
% data correction failed, such that the user could repair it.
if ~p.useBulkMode
    output_windows = daqSession.UserData.d.outputDataWindows;
    nidaq_rate = daqSession.Rate;
    for i = 1:numRecs
        filename = fullfile(daqSession.UserData.d.expDir{i}, ...
            'output_windows_debug.mat');
        save(filename, 'output_windows', 'nidaq_rate');
    end
end

if inputDataCorrectionFailed
    msgbox(['The program tries to ensure the correctness of timestamps' ...
        ' and input recordings in an online fashion, such that pauses ' ...
        'are transparent to the user.' newline ...
        'This correction failed!' newline 'Therefore, use the file ' ...
        '"input_data_raw.mat" instead of "input_data.mat".' newline ...
        'Note, that this file contains the raw recordings.'], ...
        'Input Data Correction Failed', 'warn');
end

if sessionInterrupted
    % We don't know the output values, of the interrupted output channels.
    % Therefore, we set them all to LOW.
    logger.info('run_experiment', 'Resetting all channels to LOW.');
    resetAllChannels(p);
    
    logger.warn('run_experiment', 'Recording could not finish.');
    % We did not check the output data for consistency, that has to be done
    % in a postprocessing step.
    % Note, that the output data is always written in chunks (or completely
    % if using bulk mode). The input data depends on the callback
    % thresholds. The video data depends on the actual time when the user
    % has stopped the session,
    msgbox(['The data written in the output folder might have ' ...
        'inconsistent lengths due to the stopped recording.'], ...
        'Recording Interrupted', 'warn');
elseif errorOccurredDuringSession
    logger.info('run_experiment', ...
        'An error occurred during the recording.');
    msgbox(['An error occurred during the session. Please study the ' ...
        'logfile and output data carefully for unwanted ' ...
        'consequences.'], 'Error during Session', 'warn');
else
    logger.info('run_experiment', 'Recordings finished successfully.');
end

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
