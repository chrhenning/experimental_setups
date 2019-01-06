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
@title           :cleanupProgram.m
@author          :ch
@contact         :henningc@ethz.ch
@created         :08/27/2018
@version         :1.0

This function should be called after the daq session has stopped.
%}
function cleanupProgram(session)
%CLEANUPPROGRAM Cleanup the program after the daq session has stopped.
%
% This includes the stopping and deletion of timers, camera handles, ...
% Clean up DAQ session
    logger = log4m.getLogger();
    
    p = session.UserData.p;
    d = session.UserData.d;
    
    cleanupFailed = 0;

    try
        delete(d.inputListener);
        delete(d.errorListener);
        if ~p.useBulkMode
            delete(d.outputListener);
        end
        release(session);
    catch
        cleanupFailed = 1;
        logger.error('cleanupProgram', 'DAQ session cleanup failed.');
    end
  
    % Clean up Online Side Detection.
    try
        if p.useOnlineSideDetection
            stop(d.sideDetectionTimer);
            delete(d.sideDetectionTimer);
            fclose(d.serialCommObj);
        end
    catch
        cleanupFailed = 1;
        logger.error('cleanupProgram', ['Online side detection ' ...
            'cleanup failed.']);
    end
    
    % Clean up behavior cameras.
    try
        for i = 1:numel(p.bcDeviceID)
           stop(d.bcVidObjects{i}); 
        end
        stop(d.bcFigureTimer);
        delete(d.bcFigureTimer);
        d.recView.closeGUI()
        for i = 1:numel(p.bcDeviceID)
           delete(d.bcVidObjects{i}); 
        end
    catch
        cleanupFailed = 1;
        logger.error('cleanupProgram', ['GUI and behavior camera ' ...
            'cleanup failed.']);
    end
    
    if cleanupFailed
        msgbox(['The program could not free all allocated resources.' ...
            newline 'Please restart Matlab before running a new ' ...
            'recording.'], 'Cleanup Failed', 'error');
    end
end

