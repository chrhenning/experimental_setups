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
@title           :setupChannels.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/02/2018
@version         :1.0

Setup input and output channels of the NIDAQ board.
%}

function session = setupChannels(session)
%SETUPCHANNELS Summary of this function goes here
%   Detailed explanation goes here
    logger = log4m.getLogger();
    logger.info('setupChannels', 'Setting up channels.');

    p = session.UserData.p;
    d = session.UserData.d;
    
    %% Input channels
    if ~isempty(p.inputChannel)
        session.UserData.d = d;
        addChannels(session, p.inputChannel, p.inputDAQDeviceID, ...
            p.inputIsAnalog, 'input', 0);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.inputChannel) ' as input channels.']);
    else
        % FIXME: We should have a better solution in the future.
        myError('setupChannels', ['At least one input channel is ' ...
            'needed to acquire timestamps (assign unused channel if ' ...
            'needed).']);
    end
    
    %% Trigger Channels
    if ~isempty(p.triggerChannel)
        session.UserData.d = d;
        addChannels(session, p.triggerChannel, p.triggerDAQDeviceID, ...
            p.triggerIsAnalog, 'trigger', 1);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.triggerChannel) ' as trigger channels.']);
    end
    
    %% Shock Channels
    if ~isempty(p.shockChannel)
        session.UserData.d = d;
        addChannels(session, p.shockChannel, p.shockDAQDeviceID, ...
            p.shockIsAnalog, 'shock', 1);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.shockChannel) ' as shock channels.']);
    else
        for i = 1:d.numRecs
            if d.subjects{i}.numShocks() ~= 0
                myError('setupChannels', ['Shocks are delivered ' ...
                    'according to the design but no shock channel has ' ...
                    'been assigned.']);
            end
        end               
    end
    
    %% Sound Channels
    if ~p.useSoundCard
        session.UserData.d = d;
        addChannels(session, p.soundChannel, p.soundDAQDeviceID, ...
            ones(size(p.soundChannel)), 'sound', 1);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.soundChannel) ' as sound channels.']);
    else
        if ~isempty(p.soundChannel)
            % We could just warn the user that we ignore the channels, but
            % it is better to throw an error in case he mistakenly chose
            % the soundcard.
            myError('setupChannels', ['Sound channels have been ' ...
                    'defined even though option "p.useSoundCard" is ' ...
                    'true.']); 
        end
    end
    
    %% Sound Event Channels
    if ~isempty(p.soundEventChannel)
        session.UserData.d = d;
        addChannels(session, p.soundEventChannel, ...
            p.soundEventDAQDeviceID, p.soundEventIsAnalog, 'sevent', 1);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.soundEventChannel) ' as sound event channels.']);
    end
    
    %% Digital Channels from Design File
    if ~isempty(p.digitalChannel)
        session.UserData.d = d;
        addChannels(session, p.digitalChannel, p.digitalDAQDeviceID, ...
            zeros(size(p.digitalChannel)), 'digital', 1);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.digitalChannel) ' as digital event channels.']);
    end
       
    %% Analog Channels from Design File
    if ~isempty(p.analogChannel)
        session.UserData.d = d;
        addChannels(session, p.analogChannel, p.analogDAQDeviceID, ...
            zeros(size(p.analogChannel)), 'analog', 1);
        d = session.UserData.d;

        logger.debug('setupChannels', ['Assigned channels ' ...
            cell2str(p.analogChannel) ' as analog event channels.']);
    end
    
    numOutputChannels = length(session.Channels) - ...
        numel(p.inputChannel);
    % In case we have no output channels, we need to tell the NIDAQ how
    % long it should run.
    if numOutputChannels == 0
        session.DurationInSeconds = d.duration;
        logger.warn('setupChannels', 'No output channels defined');
    end
    
    session.UserData.d = d;
end

function session = addChannels(session, channels, deviceID, isAnalog, ...
    ident, isOutput)
%ADDCHANNELS Add input or output channels to the NIDAQ.
%
%   Later, we need to remember in which order we added channels. Therefore,
%   it is important to remember the actual channel indices. These are added
%   to the UserData of the session.
    p = session.UserData.p;
    d = session.UserData.d;
    
    % E.g., mapping from row and column coordinate in p.inputChannel to
    % actual channel index.
    d.channelInds.(ident) = zeros(size(channels));
    
    for i = 1:size(channels, 1)
        for j = 1:size(channels, 2)
            if isOutput
                if isAnalog(i, j)
                    [~, idx] = session.addAnalogOutputChannel( ...
                        deviceID{i, j}, channels{i, j}, 'Voltage');
                else
                    [~, idx] = session.addDigitalChannel( ...
                        deviceID{i, j}, channels{i, j}, 'OutputOnly');
                end
            else
                if isAnalog(i, j)
                    [~, idx] = session.addAnalogInputChannel( ...
                        deviceID{i, j}, channels{i, j}, 'Voltage');
                else
                    [~, idx] = session.addDigitalChannel( ...
                        deviceID{i, j}, channels{i, j}, 'InputOnly');
                end
            end
            d.channelInds.(ident)(i, j) = idx;
        end
    end
    
    session.UserData.d = d;
end

