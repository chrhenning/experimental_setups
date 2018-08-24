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
@title           :playSounds.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/03/2018
@version         :1.0

Play sounds from design file via soundcard. Note, precise timing cannot be
ensured!
%}
function playSounds(session, sessionStartTime)
%PLAYSOUNDS Plays the sounds of the design for the first specified
%recording in this session.
%
%   The function plays only the sound events of the first recording in the
%   same order as given by the design file (no sorting is done).
%
%   FIXME: The function expects sound events to be ordered.
%   FIXME: Primitive function, does not play partial sounds if time already
%   progressed passed the sound onset.
    logger = log4m.getLogger();
    logger.warn('playSounds', ['Sounds are played via sound card. ' ...
        'Precise timing cannot be ensured!']);

    %p = session.UserData.p;
    d = session.UserData.d;
    
    if d.numRecs > 1
        logger.warn('playSounds', ['Only sounds from recording 1 are ' ...
            'played. The other recordings are ignored.']);
    end 
    
    sampling_rate = d.properties.sound_sampling_rate;
    bit_depth = d.properties.sound_bit_depth;
    
    eps = 0.01;

    for i = 1:d.subjects{1}.numSounds()
        sndEvent = d.subjects{1}.getSound(i);
        
        onsetTime = sndEvent.onset;
        
        pause((onsetTime - eps) - toc(sessionStartTime));
        
        while toc(sessionStartTime) < onsetTime
            % busy wait
        end
        
        sound(sndEvent.data, sampling_rate, bit_depth);
        
        logger.info('playSounds', ['Playing sound '  num2str(i) ...
            ', which has the sound type ' sndEvent.type '.']);
    end
end

