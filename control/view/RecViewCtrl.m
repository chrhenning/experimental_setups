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
@title           :RecViewCtrl.m
@author          :ch
@contact         :henningc@ethz.ch
@created         :08/24/2018
@version         :1.0

A controller for the view presented during a recording. This should be the
interface to the view for the remaining program.
%}
classdef RecViewCtrl < handle
%RecViewCtrl The controller for the view "rec_view".
%
% Note, though no pattern implemented, this class should be considered
% Singleton, i.e., only one instance should exist at a time.
%
% Note, the actual controller is still the "rec_view.m" file. This  class 
% can be seen as an interface between model and controller.
    
    properties
        % The GUI handle, that should contain the BCam views.
        bCamPanel
        % The handles object of the actual GUI controller. Needed to call
        % GUI callbacks.
        guiHandles
        % The actual start time of the recording.
        recStartTime
        updateTimeThread % Timer thread that updates the time.
        updateTimeListener % The eventlistener, that listens to 
                           % UpdateTimeEv.
        pauseListener % The eventlistener, that listens to PauseEv.
        guiClbkTime % A function handle, that can be used to update the
                    % time displayed on the GUI.
        guiClbkEnableBtns % Enable stop and pause buttons, as soon as the
                          % recording has started.
        guiClbkAddEv % Add an event string to the event logger in the GUI.
        guiClbkClose % The close callback for the GUI figure.
        guiClbkPauseText % Set the text of the pause button.
        guiClbkStatus % Set the status text.
        recDuration % Duration of the recording. Used to stop the timer
                    % update.
        params % The params object.
        daqSession % The daq session, that controls the recording.
        recStopHandle % A progress bar handle, if the recording was 
                      % stopped.
    end
    events
       UpdateTimeEv % Event, that signals, that the GUI should update the
                    % timer (that shows the current Recording time).
       PauseEv % Event, that is fired if the session has paused resp. 
               % continued.
    end
    
    methods (Access = public)
        function obj = RecViewCtrl()
        % RecViewCtrl 
            % Initialize attributes.
            obj.recStartTime = -1;
            obj.guiClbkTime = -1;
            obj.guiClbkEnableBtns = -1;
            obj.daqSession = -1;
            obj.recStopHandle = -1;
        end
        
        function dataObj = openGUI(obj, dataObj)
        % OPENGUI Construct and open the Recording View.
            obj.params = dataObj.p;
        
            obj.recDuration = dataObj.d.duration;
            durMin = floor(obj.recDuration / 60);
            durSec = round(mod(obj.recDuration, 60));
            durStr = sprintf('/ %02d:%02d', durMin, durSec);
        
            % Note the view expects this controller as first vararg.
            rec_view(obj, durStr);
            
            %% Add listener, that updates the time on incoming events.
            % Asynchronous events from the timer can be synchronized with
            % the GUI in this way.
            % Note, listener and thread are closed in the closeRequest
            % function of the GUI.
            obj.updateTimeListener = addlistener(obj, 'UpdateTimeEv', ...
                @updateTime);
            
            % Setup timer thread.
            timerData.ctrl = obj;
            obj.updateTimeThread = timer('TimerFcn', @timerFcn,...
                        'ExecutionMode', 'fixedRate', ...
                        'Period', 0.5, ...
                        'BusyMode', 'drop', ...
                        'UserData', timerData);
            start(obj.updateTimeThread);
            
            %% Add listener, that gets notified on handled pause requests.
            % If the session received our pause (resp. continue) request,
            % we get notified via this event.
            obj.pauseListener = addlistener(obj, 'PauseEv', @pauseUpdate);
        end
        
        function setBCamPanel(obj, panel)
        % SETBCAMPANEL Set the uipanel handle, in which the camera previews
        % should be rendered.
        %
        % Args:
        % - panel: An uipanel handle.
            
            obj.bCamPanel = panel;
        end
        
        function panel = getBCamPanel(obj)
        % GETBCAMPANEL Return the uipanel handle, in which the camera 
        % previews should be rendered.
        %
        % Returns:
        % The property "bCamPanel".
            
            panel = obj.bCamPanel;
        end
        
        function setGUIHandles(obj, handles)
        % SETGUIHANDLES Set the guiHandles attribute. 
        %
        % Args:
        % - handles: The handles object from the controller.
            obj.guiHandles = handles;
        end
        
        function setUpdateFcns(obj, timerFcn, enableBtnFcn, ...
                addEventFunc, closeFcn, pauseTextFcn, modifyStatus)
        % SETUPDATEFCNS Set the update functions, that can be used interact
        % with the GUI.
        %
        % Args:
        % - timerFcn: The function, that can be used to update the timer.
        % - enableBtnFcn: The function called when the recording starts, to
        %                 enable the gui buttons.
        % - addEventFunc: Function, that can be called to add an event to
        %                 the event logger.
        % - closeFcn: The close callback for the GUI.
        % - pauseTextFcn: A function that allows to set the label of the
        %                 pause button.
        % - modifyStatus: A function, that can be used to modify the status
        %                 text field  of the GUI.
            obj.guiClbkTime = timerFcn;
            obj.guiClbkEnableBtns = enableBtnFcn;
            obj.guiClbkAddEv = addEventFunc;
            obj.guiClbkClose = closeFcn;
            obj.guiClbkPauseText = pauseTextFcn;
            obj.guiClbkStatus = modifyStatus;
        end
        
        function setRecStartTime(obj, startTime, daqSession)
        % SETRECSTARTTIME Set the start time of the recordings, such that
        % the GUI can display the timer.
        %
        % Note, this function is also used to enable GUI features, that
        % should not be present, as long as the recording hasn't started
        % yet.
        %
        % Args:
        % - startTime: The recording start time.
        % - daqSession: The daq session, that controls the recording.
            oldRecStartTime = obj.recStartTime;
            obj.recStartTime = startTime;
            obj.daqSession = daqSession;
            
            if oldRecStartTime ~= -1
                return;
            end

            logger = log4m.getLogger();
            % FIXME: Can we be sure, that this function handle is already
            % set?
            if ~isa(obj.guiClbkEnableBtns, 'function_handle')
                logger.warn('RecViewCtrl', ...
                    'Could not enable GUI buttons.');
                return
            end
            
            try
                if obj.params.useBulkMode
                    logger.info('RecViewCtrl', ['Pause option is not ' ...
                       'available in this recording due to bulk mode.']);
                    obj.guiClbkEnableBtns(obj.guiHandles, 0);
                else
                    obj.guiClbkEnableBtns(obj.guiHandles, 1);
                end
            catch
                logger = log4m.getLogger();
                logger.error('RecViewCtrl', ...
                    'Could not enable GUI buttons.');
            end
        end
        
        function updateTime(obj, ~)
        % UPDATETIME This method listens to the 'UpdateTimeEv' and updates
        % the timer displayed in the view.
            if ~isa(obj.guiClbkTime, 'function_handle')
                return
            end
            
            logger = log4m.getLogger();
            
            if obj.recStartTime == -1
                timeStr = '--:--';
            else          
                elapsedSeconds =  round((now - obj.recStartTime) * ...
                    24 * 60 * 60);
                
                % Clear paused windows from timer.
                if isobject(obj.daqSession)
                    wins = obj.daqSession.UserData.d.outputDataWindows;
                    numSteps = floor(elapsedSeconds * obj.daqSession.Rate);
                    numStepsTotal = numSteps;
                    
                    % Search for the latest window, that spans the elapsed
                    % time and is not paused.
                    startSteps = [0; wins(1:end-1, 4)];
                    latestWinInd = find(numSteps >= startSteps & ...
                        wins(:, 6) == 0, 1, 'last');
                    
                    if numSteps > wins(latestWinInd, 4)
                        % The session is currently paused and we have to
                        % display an earlier timepoint.
                        numSteps = wins(latestWinInd, 5);
                    else
                        % Subtract possibly paused windows, that already
                        % happened.
                        % Subtract all paused windows.
                        numSteps = numSteps - (wins(latestWinInd, 4) - ...
                            wins(latestWinInd, 5));
                    end

                    elapsedSeconds = numSteps / obj.daqSession.Rate; 
                    
                    % Compute status of session (i.e., paused or not
                    % paused.
                    obj.displayStatus(numStepsTotal, elapsedSeconds);
                end
                
                % We don't wanna further update the timer:
                if elapsedSeconds > obj.recDuration
                    elapsedSeconds = obj.recDuration;
                end
                durMin = floor(elapsedSeconds / 60);
                durSec = mod(elapsedSeconds, 60);
                timeStr = sprintf('%02d:%02d', durMin, durSec);
            end
            
            try
                obj.guiClbkTime(obj.guiHandles, timeStr);
            catch
                logger.error('RecViewCtrl', 'Could not update GUI time.');
            end
        end
        
        function logEvent(obj, eventStr)
        % LOGEVENT This method, will add the given event to the event
        % logger in the GUI.
        %
        % Args:
        % - eventStr: The string, that should be appended.
            try
                obj.guiClbkAddEv(obj.guiHandles, eventStr);
            catch
                logger = log4m.getLogger();
                logger.error('RecViewCtrl', 'Could not log GUI event.');
            end
        end
        
        function closeGUI(obj)
        % CLOSEGUI This function should be called to close the GUI figure,
        % instead of calling close(guiFig).
            % If recording has been stopped by user.
            if obj.hasRecStopped()
                waitbar(1, obj.recStopHandle, 'Recording stopped.');
                pause(0.01);
                close(obj.recStopHandle) 
            end
        
            try
                obj.guiClbkClose(obj.guiHandles);
            catch
                logger = log4m.getLogger();
                logger.error('RecViewCtrl', 'Could not close the GUI.');
            end
        end
        
        function stopRecording(obj)
            % This function is called by the GUI, if the user requested a
            % stop of the recording. This function will stop the daq
            % session.
            logger = log4m.getLogger();
            logger.warn('RecViewCtrl', ...
                'Recording stop has been requested.');
            
            if obj.params.useSoundCard
                logger.warn('RecViewCtrl', ['Note, data already ' ...
                    'flushed to the sound card cannot be stopped.']);
            end
            
            waitbar_handle = waitbar(0, 'Recording will be stopped ...');
            pause(0.01);
            waitbar(.33, waitbar_handle, 'Stopping DAQ Session ...');
            
            logger.info('RecViewCtrl', 'Interrupting DAQ session.');
            obj.daqSession.stop();
            
            waitbar(.66, waitbar_handle, 'Cleaning up workspace ...');
            obj.recStopHandle = waitbar_handle;
        end
        
        function isStopped = hasRecStopped(obj)
            % HASRECSTOPPED Has the recording been stopped by the user?
            %
            % Returns:
            % Whether the recording has been stopped.
            isStopped = ishandle(obj.recStopHandle);
        end
        
        function pauseRequested(obj, btnLabel)
            % PAUSEREQUESTED This method handles the case when the user
            % requests a pause or continue of the session.
            %
            % Args:
            % - btnLabel: The current button label, either 'Pause' or
            %             'Continue'.
            global requestingPauseRespCont;
            requestingPauseRespCont = 1;
            
            logger = log4m.getLogger();
            if strcmp(btnLabel, 'Pause')
                logger.error('RecViewCtrl', 'User requested pause.');
            else
                logger.error('RecViewCtrl', 'User requested continue.');
            end            
        end
        
        function pauseUpdate(obj, eventData)
            % PAUSEUPDATE This function gets called when the PauseEv event
            % is fired. Hence, it is called when a pause/continue request
            % was processed, such that we can enable the button again.
            logger = log4m.getLogger();
            
            if eventData.IsPausing
                try
                    obj.guiClbkPauseText(obj.guiHandles, 'Continue');
                catch
                    logger.error('RecViewCtrl', ...
                        'Could not set pause button text.');
                end
            else
                try
                    obj.guiClbkPauseText(obj.guiHandles, 'Pause');
                catch
                    logger.error('RecViewCtrl', ...
                        'Could not set pause button text.');
                end
            end
        end
    end
    
    methods (Access = private)
        function displayStatus(obj, numSteps, elapsedRecSecs)
            % DISPLAYSTATUS Compute the status of the session and display
            % it to the user.
            %
            % Args:
            % - numSteps: The number of steps processed so far in this
            %             recording (the total number, including paused
            %             steps).
            % - elapsedRecSecs: The number of seconds elapsed in this
            %                   recording (excluding pauses) so far.
            try
                wins = obj.daqSession.UserData.d.outputDataWindows;
                    
                % Search for the latest window, that spans the elapsed
                % time and is not paused.
                startSteps = [0; wins(1:end-1, 4)];
                
                if obj.hasRecStopped()
                    obj.guiClbkStatus(obj.guiHandles, ...
                        'Session Interrupted', [0.85 0.33 0.1]);
                    return;
                end
                    
                if ~obj.daqSession.IsRunning
                    obj.guiClbkStatus(obj.guiHandles, [], [], false);
                else
                    if elapsedRecSecs >= obj.recDuration
                        obj.guiClbkStatus(obj.guiHandles, ...
                            'Ending Session', [0.5 0.5 0.5]);
                        return;
                    end
                    
                    % In which window are we currently in?
                    winInd = find(numSteps >= startSteps & ...
                        numSteps < wins(:, 4), 1, 'last');
                    
                    if wins(winInd, 6) == 1
                        obj.guiClbkStatus(obj.guiHandles, ...
                            'Session Paused', [1 0 0]);
                    else
                        obj.guiClbkStatus(obj.guiHandles, ...
                            'Session Running', [0 1 0]);
                    end
                end
            catch
                logger.error('RecViewCtrl', ...
                    'Could not set session status in GUI.');
            end
        end
    end
end

function timerFcn(timerObj, ~)
    % Send an event to the model, that it should update the timer.
    data = get(timerObj, 'UserData');
    notify(data.ctrl, 'UpdateTimeEv');
end