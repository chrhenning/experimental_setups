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
@title           :measure_spl.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :11/28/2017
@version         :1.0

Measure the sound pressure level (in dB(A)) of the environment.
%}

function [ y ] = measure_spl(recording_time, mic_sensitivity, window_size)
%MEASURE_SPL Compute the sound pressure level of an audio recording.
%   y = MEASURE_SPL(recording_time, mic_sensitivity, window_size)
%
%   This function performs an audio recording for the given
%   'recording_time' (in seconds). Afterwards, in analyses the sound
%   pressure level (in dB SPL) of the recording by taking the microphone
%   specs into consideration. Specifically, the user neets to know the
%   sensitivity of the microphone in mV (otherwise the output is rubbish).
%   This sensitivity is set via the optional parameter 'mic_sensitivity'
%   (im mV). If one wants to see the temporal evolution of the sound
%   pressure level during the recording, he may provide an integration
%   window 'window_size' (in seconds).
%
%   Note, the output of this program depends on microphone settings (e.g.,
%   in Windows it depends on the microphone level and boost). Therefore,
%   better use a Sound Level Meter.
%
%   Examples:
%   y = measure_spl(1, 31.6);
%   y = measure_spl(1, 31.6, 0.25);

    addpath(genpath('../../lib/'));
    
    % As default microphone sensitivity, we use the sensitivity of the mic
    % BOYA BY-M1. The sensitivity of this mic is given with -30dB (relative
    % to one Pascal). This can be converted to 31.6mV. We used the
    % calculator on this website:
    % https://geoffthegreygeek.com/microphone-sensitivity/
    if (~exist('mic_sensitivity', 'var'))
        mic_sensitivity = 31.6;
    end
    
    % If no window size provided, we calculate the average of the whole
    % recording.
    if (~exist('window_size', 'var'))
        window_size = -1;
    end

    recObj = audiorecorder;
    sample_rate = recObj.SampleRate;
    
    disp('Starting recording ...');
    recordblocking(recObj, recording_time);
    disp('Recording ended.');
    
    audio_data = getaudiodata(recObj);
    if window_size == -1
        y = spl(audio_data / mic_sensitivity, 'air');
        
        disp(['Sound pressure of recording: ' num2str(y) ' dB SPL.']);        
    else
        y = spl(audio_data / mic_sensitivity, 'air', window_size, ...
                sample_rate);
    
        figure
        t = cumsum(ones(size(y))/sample_rate);
        plot(t, y)
        xlabel('time (s)')
        ylabel('SPL (dB)')
    end
end

