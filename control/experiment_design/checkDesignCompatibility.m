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
@title           :checkDesignCompatibility.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/01/2018
@version         :1.0

Make sure, the recordings can run in parallel.
%}

function dataObj = checkDesignCompatibility(dataObj)
%CHECKDESIGNCOMPATIBILITY Check if designs can run in parallel.
%
%   Additionally, this function checks for some parameters if they are in
%   agreement with the design. It will also make sure that all events are
%   sampled with the specified daq rate.

    p = dataObj.p;
    d = dataObj.d;
    
    % In principal, we could allow smaller daq rates (code-wise this is no
    % problem). But we better expect the user to directly sample the data
    % in the smaller daq rate, before he will be suprised be the heavily
    % distorted outcome of undersampled data.
    if ~p.useSoundCard && d.properties.sound_sampling_rate > p.rateDAQ
        errMsg = ['The DAQ rate is smaller than the sound sampling ' ...
            'rate (' num2str(d.properties.sound_sampling_rate) ').'];
        myError('checkDesignCompatibility', errMsg);    
    end
    if size(p.analogChannel, 2) && ...
            d.properties.analog_sampling_rate > p.rateDAQ
        errMsg = ['The DAQ rate is smaller than the analog sampling ' ...
            'rate (' num2str(d.properties.analog_sampling_rate) ').'];
        myError('checkDesignCompatibility', errMsg);    
    end   
    
    for i = 1:d.numRecs
        % Make sure, that shock channels defined in design are in agreement
        % with the chosen shocking mode.
        rec = d.subjects{i};
        numChannels = size(p.shockChannel, 2);
        switch p.shockMode
            case 'default'
                % No special requirements.
            case 'channel'
                % The defined channels must be a valid channel index.
                for s = 1:rec.numShocks()
                    usEvent = rec.getShock(s);
                    assert(usEvent.channel >= 1 && ...
                        usEvent.channel <= numChannels);
                end
             case 'lrdesign'
                 % The design must either specify, that the shock is
                 % supplied left (1) or right (2).
                for s = 1:rec.numShocks()
                    usEvent = rec.getShock(s);
                    assert(usEvent.channel == 1 || ...
                        usEvent.channel == 2);
                end
            case 'lrposition'
                % Shock delivery is independent of the design.
                myError('checkDesignCompatibility', ...
                    'Not yet implemented.');
            otherwise
                myError('checkDesignCompatibility', ...
                    'Unknown "p.shockMode".');
        end
        
        % Check whether number of analog and digital channels is in
        % agreement with design.
        assert(size(p.analogChannel, 2) == ...
            d.subjects{i}.numEvents('analog'));
        assert(size(p.digitalChannel, 2) == ...
            d.subjects{i}.numEvents('digital'));

        % Sample all the data in the design file to match the daq sampling
        % rate (this might incorporate resampling of analog (incl. sound)
        % events).
        d.subjects{i} = rec.setCommonSmpRate(p.rateDAQ, false);
    end
    
    for i = 1:d.numRecs
        for j = i+1:d.numRecs
            si = d.subjects{i};
            sj = d.subjects{j};
            
            % When only using 1 shock channel row, all designs need to have 
            % the same shock design.
            if size(p.shockChannel, 1) == 1
               assert(si.numShocks() == sj.numShocks())
               for s = 1:si.numShocks()
                   usEvI = si.getShock(s);
                   usEvJ = sj.getShock(s);
                   assert(usEvI.onset == usEvJ.onset);
                   assert(usEvI.duration == usEvJ.duration);
                   assert(usEvI.intensity == usEvJ.intensity);
                   assert(usEvI.channel == usEvJ.channel);
                   assert(usEvI.rising == usEvJ.rising);
                   assert(usEvI.falling == usEvJ.falling);
               end
            end
            
            if size(p.soundChannel, 1) == 1
                assert(si.numSounds() == sj.numSounds())
                for s = 1:si.numSounds()
                    soundI = si.getSounds(s);
                    soundJ = si.getSounds(s);
                    assert(soundI.onset == soundJ.onset);
                    % We only assert that they are the same duration for
                    % efficiency reasons, the rest is in the responsibility
                    % of the user.
                    assert(soundI.duration == soundJ.duration);
               end
            end
            
            % We need to make sure that we also have the same analog and
            % digital events in all designs, if channels are only specified
            % once.
            if size(p.analogChannel, 1) == 1
                [numChI, numEvI] = si.numEvents('analog');
                [numChJ, numEvJ] = sj.numEvents('analog');
                
                assert(numChI == numChJ)
                for evt = 1:numChI
                   assert(numEvI(evt) == numEvJ(evt));
                    
                   for ae = 1:numEvI(evt)
                        aeventi = si.getAnalogEvent(evt, ae);
                        aeventj = sj.getAnalogEvent(evt, ae);
                       
                        assert(aeventi.onset == aeventj.onset);
                        assert(aeventi.duration == aeventj.duration);
                   end
                end
            end
            
            if size(p.digitalChannel, 1) == 1
                [numChI, numEvI] = si.numEvents('digital');
                [numChJ, numEvJ] = sj.numEvents('digital');
                
                assert(numChI == numChJ)
                for evt = 1:numChI
                   assert(numEvI(evt) == numEvJ(evt));
                    
                   for ae = 1:numEvI(evt)
                        deventi = si.getDigitalEvent(evt, ae);
                        deventj = sj.getDigitalEvent(evt, ae);
                        
                        assert(deventi.onset == deventj.onset);
                        assert(deventi.duration == deventj.duration);
                   end
                end
            end
        end
    end
    
    dataObj.d = d;
end

