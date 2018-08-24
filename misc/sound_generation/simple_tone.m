% Copyright 2017 Christian Henning
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
@title           :simple_tone.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :12/05/2017
@version         :1.0

Generate and return a (single-frequency) tone.
%}

function tone = simple_tone(duration, frequency, jitter_level, ...
    gain_window, amplitude, sampling_rate)
%SIMPLE_TONE Generate a mono tone consisting of only one frequency.
%   tone = SIMPLE_TONE(duration, frequency, jitter_level, gain_window, ...
%                      amplitude, sampling_rate)
%
%   This function returns a tone (it doesn't play it!) that is a sine wave
%   with a single frequency.
%
%   Arguments:
%   - duration: Tone duration in seconds.
%   - frequency: The frequency of the tone.
%   - jitter_level: (default: 0) The variance of the gaussian noise that is
%     added to the sine wave.
%   - gain_window: (default: duration / 20) The length of the gain window
%     that is applied at the onset and offset of the tone (linear gain
%     control is used).
%   - amplitude: (default: 1) Amplitude of sine wave.
%   - sampling_rate: (default: 48000) Sampling rate.
%
%   Examples:
%   tone = simple_tone(1, 1000);
%   sound(tone, 48000, 16);
    
    if (~exist('jitter_level', 'var'))
        jitter_level = 0;
    end
    
    if (~exist('gain_window', 'var'))
        gain_window = duration / 20;
    end
    
    if (~exist('amplitude', 'var'))
        amplitude = 1;
    end
    
    if (~exist('sampling_rate', 'var'))
        sampling_rate = 48000;
    end
    
    time_values = 0:1/sampling_rate:duration-1/sampling_rate;
    
    % Gain modulation. To ensure that the tone is smoothely played by the 
    % speakers, we need ad onset and offset gain modulation. We just choose
    % a linear gain modulation.
    if duration <= 2 * gain_window
         error('Tone duration too short for given gain window!');
    end
    
    amplitudes = ones(size(time_values));
    gain_length = floor(gain_window * sampling_rate);
    amplitudes(1:gain_length) = linspace(0, 1, gain_length);
    amplitudes(end-(gain_length-1):end) = linspace(1, 0, gain_length);
    
    amplitudes = amplitudes * amplitude;
    
    if jitter_level >= 0
        tone = (amplitudes + jitter_level ...
            * randn(1, length(time_values))) ...
            .* sin(2 * pi * frequency * time_values);
    else
        tone = amplitudes .* sin(2 * pi * frequency * time_values);
    end
end

