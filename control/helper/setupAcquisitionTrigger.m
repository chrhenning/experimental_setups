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
@title           :setupAcquisitionTrigger.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :03/16/2018
@version         :1.0
%}

function session = setupAcquisitionTrigger(session)
%SETUPACQUISITIONTRIGGER If activated in the params, then this function
%will add an external trigger connection, that will cause the data
%acquisition to wait for a digital high channel on the dedicated PFI
%channel.
    logger = log4m.getLogger();

    p = session.UserData.p;
    %d = session.UserData.d;
    
    % If true, then the session is not starting before an external trigger is
    % received.
    if p.useExtTrigger
        session.addTriggerConnection('external', p.extTriggerChannel, ...
            'StartTrigger');
        % How long should we wait for a trigger before raising an error.
        session.ExternalTriggerTimeout = p.extTriggerTimeout;
        
        logger.info('setupAcquisitionTrigger', ['Acquisition will be ' ...
            'configured to wait for an external trigger.']);
    end

    %session.UserData.d = d;
end

