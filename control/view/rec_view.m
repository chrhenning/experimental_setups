function varargout = rec_view(varargin)
% REC_VIEW MATLAB code for rec_view.fig
%      REC_VIEW, by itself, creates a new REC_VIEW or raises the existing
%      singleton*.
%
%      H = REC_VIEW returns the handle to a new REC_VIEW or the handle to
%      the existing singleton*.
%
%      REC_VIEW('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in REC_VIEW.M with the given input arguments.
%
%      REC_VIEW('Property','Value',...) creates a new REC_VIEW or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before rec_view_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to rec_view_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

    % Edit the above text to modify the response to help rec_view

    % Last Modified by GUIDE v2.5 27-Aug-2018 10:47:19

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @rec_view_OpeningFcn, ...
                       'gui_OutputFcn',  @rec_view_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
end

% --- Executes just before rec_view is made visible.
function rec_view_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to rec_view (see VARARGIN)

    assert(nargin == 5)
    handles.ctrl = varargin{1};

    % Choose default command line output for rec_view
    handles.output = hObject;

    % Update handles structure
    guidata(hObject, handles);

    % UIWAIT makes rec_view wait for user response (see UIRESUME)
    % uiwait(handles.figureMain);
    
    set(handles.textDuration, 'String', varargin{2});
    
    % TODO figure not yet created, but we want to maximize it. Look at
    % FileExchange for solutions.
    
    % Important, within GUIDE, I can only place axes. But I can't put
    % subplots into an axes. That is why we use an uipanel instead.
    bCamHandle = uipanel('Parent', hObject, 'Title', ...
        'Behavior Camera Live View', 'FontSize', 12, 'Position', ...
        [0.02, 0.125, 0.75, 0.75]);
    handles.bcamViewHandle = bCamHandle;
    handles.ctrl.setBCamPanel(bCamHandle);
    handles.ctrl.setGUIHandles(handles);
    handles.ctrl.setUpdateFcns(@update_rec_timer, @enable_buttons, ...
        @add_event_line, @my_close_fcn, @set_pause_btn_lbl, @set_status);
end

% --- Outputs from this function are returned to the command line.
function varargout = rec_view_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
    varargout{1} = handles.output;
end

% --- Executes on button press in btnPause.
function btnPause_Callback(hObject, eventdata, handles)
% hObject    handle to btnPause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    
    btnText = get(handles.btnPause, 'String');
    if strcmp(btnText, 'Pause')
        set(handles.btnPause, 'String', 'Pausing ...');
        set(handles.btnPause, 'Enable','off') 
    elseif strcmp(btnText, 'Continue')
        set(handles.btnPause, 'String', 'Continuing ...');
        set(handles.btnPause, 'Enable','off') 
    else
        % This point cannot be reached, as the button is disabled.
        return;
    end
    
    handles.ctrl.pauseRequested(btnText);
end


% --- Executes on button press in btnStop.
function btnStop_Callback(hObject, eventdata, handles)
% hObject    handle to btnStop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    msg = ['When stopping the recording, it cannot be resumed!' newline ...
        'Do you want to continue?'];
    btnString = buttondlg(msg, 'Warning', 'Yes', 'No', ...
        struct('Default','No','IconString','warn'));
    
    if strcmp(btnString, 'No')
        return;
    end
    
    handles.ctrl.stopRecording();    
    set(handles.btnStop, 'Enable','off') 
end


function editEventLogger_Callback(hObject, eventdata, handles)
% hObject    handle to editEventLogger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editEventLogger as text
%        str2double(get(hObject,'String')) returns contents of editEventLogger as a double

end

% --- Executes during object creation, after setting all properties.
function editEventLogger_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editEventLogger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


% --- Executes when user attempts to close figureMain.
function figureMain_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figureMain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    msg = ['The GUI should not be closed while the recording is ' ...
        'running.' newline 'Do you want to close it anyway?'];
    btnString = buttondlg(msg, 'Warning', 'Yes', 'No', ...
        struct('Default','No','IconString','warn'));
    if strcmp(btnString, 'No')
        return;
    end
    
    % Close GUI.
    my_close_fcn(handles);

    
end

function update_rec_timer(handles, timeStr)
% Update the timer string on the GUI.
%
% Args:
% - handles: Structure with handles and user data (see GUIDATA).
% - timeStr: The String, that should be displayed (containing the time).
    set(handles.textTime, 'String', timeStr);
end

function enable_buttons(handles, enablePause)
% The user should not press any buttons, as long as the recording hasn't
% started yet (as the program state might be undefined in this moment). So
% we let the controller enable these buttons, as soon the recording
% started.
%
% Args:
% - handles: Structure with handles and user data (see GUIDATA).
% - enablePause: Whether the pause button should be enabled.
    if enablePause
        set(handles.btnPause, 'Enable', 'on');
    else
        set(handles.btnPause, 'Enable', 'off');
    end
    set(handles.btnStop, 'Enable', 'on');
end

function add_event_line(handles, eventLine)
% Add a line of text to the event logger view.
%
% Args:
% - handles: Structure with handles and user data (see GUIDATA).
% - eventLine: The line that should be appended to the logger.
    currEvText = get(handles.editEventLogger, 'String');
    currEvText{end+1} = eventLine;
    set(handles.editEventLogger, 'String', currEvText);
    
    % Quick fix taken from here:
    % undocumentedmatlab.com/blog/setting-line-position-in-edit-box-uicontrol/
    % This fix should help us, to ensure, that the scrollbar is always set
    % to the end of the edit field.
    javaHandle = findjobj(handles.editEventLogger);
    jEdit = javaHandle.getComponent(0).getComponent(0);
    jEdit.setCaretPosition(jEdit.getDocument.getLength);
end

function my_close_fcn(handles)
% We need to distinguish the cases when the user wants to close the figure
% (by pressing the close button) or when we want to close the GUI at the
% end of the recording. That's why this extra function exists in addition
% to "figureMain_CloseRequestFcn".
%
% Args:
% - handles: Structure with handles and user data (see GUIDATA).
    hObject = handles.figureMain;

    if strcmp(get(handles.ctrl.updateTimeThread, 'Running'), 'on')
        stop(handles.ctrl.updateTimeThread);
    end

    % Make sure, notifications from the timer are no longer executed.
    delete(handles.ctrl.updateTimeListener);
    
    delete(handles.ctrl.pauseListener);

    % Hint: delete(hObject) closes the figure
    % Here we use a heuristic, to avoid errors on close. The GUI might be 
    % stuck in the update function, while this close event arives 
    % asynchronely.
    % Therefore, we allow after the execution of this function, the update
    % function to finish before we finally delete the GUI.
    deleteTimer = timer('StartDelay', 0.3, 'TimerFcn', ...
        @(src,evt)delete(hObject));
    start(deleteTimer);
    %delete(hObject);
end

function set_pause_btn_lbl(handles, label)
% Set a new label to the pause button. This function will enable the
% button.
%
% Args:
% - handles: Structure with handles and user data (see GUIDATA).
% - label: The text on the button.
    set(handles.btnPause, 'String', label);
    set(handles.btnPause, 'Enable', 'on') 
end

function set_status(handles, label, color, visible)
% Modify the status label.
%
% Args:
% - handles: Structure with handles and user data (see GUIDATA).
% - label: The text to display.
% - color: The color of the text to display.
% - visible: Whether the text should be visible or not.
    if (~exist('visible', 'var'))
        visible = true;
    end
    
    if visible
        set(handles.textStatus, 'String', label)
        set(handles.textStatus, 'ForegroundColor', color)
        set(handles.textStatus, 'Visible', 'on') 
    else
        set(handles.textStatus, 'Visible', 'off')
    end
end
