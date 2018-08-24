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
@title           :play_tone.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/30/2018
@version         :1.0

Simply play a tone for a given duration. This can be used to measure the
sound pressure level of speakers.
%}
function play_tone(duration, frequency, sampling_rate, bit_depth)
%PLAY_TONE Play a tone for a given duration.
%
%   Examples:
%   play_tone(0.5*60, 6000);
%   play_tone(0.5*60, 6000, 28000, 16);

    if (~exist('sampling_rate', 'var'))
        sampling_rate = 48000;
    end
    
    if (~exist('bit_depth', 'var'))
        bit_depth = 24;
    end

    tone = simple_tone(duration, frequency, 0.0, 0.02, 1, sampling_rate);
    sound(tone, sampling_rate, bit_depth);
end

