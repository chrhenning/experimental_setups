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
@title           :distribute_events.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :12/06/2017
@version         :1.0

Distribute events randomly (not overlapping, user-defined constraints) over
an interval.
%}

function onset_times = distribute_events(total_duration, num_events, ...
    event_duration, min_inter_event_duration, onset_pause, offset_pause)
%DISTRIBUTE_EVENTS Distribute events randomly over the duration of an
%experiment.
%   onset_times = DISTRIBUTE_EVENTS(total_duration, num_events, ...
%      event_duration, min_inter_event_duration, onset_pause, offset_pause)
%
%   This method can be used to get the onset times of events that are
%   randomly distributed over the course of an experiment by considering
%   some constraints (such as minimum event distance, or on-/offset times).
%   Therefore, the eligible time span is divided into 'num_events' blocks
%   within events can be randomly placed (except that there must be a gap
%   of 'min_inter_event_duration' to the end of the block.
%
%   Arguments:
%   - total_duration: The duration of the experiment in seconds.
%   - num_events: Number of events that should be placed in the experiment.
%   - event_duration: Length of an event (in seconds).
%   - min_inter_event_duration: (default: 20 sec) Minimum distance between
%     two events.
%   - onset_pause: (default: 0 sec) Time at start of experiment within no
%     events may be placed.
%   - offset_pause: (default: 0 sec) Time at end of experiment within no
%     events may be placed.
%
%   Returns:
%   An 1 x num_events array containing the onset times of the placed events
%   (in seconds).
%
%   Examples:
%   onset_times = distribute_events(20*60, 16, 25, 20, 0, 0)

    if (~exist('min_inter_event_duration', 'var'))
        min_inter_event_duration = 20;
    end
    
    if (~exist('onset_pause', 'var'))
        onset_pause = 0;
    end
    
    if (~exist('offset_pause', 'var'))
        offset_pause = 0;
    end
    
    duration = total_duration - onset_pause - offset_pause;
    
    event_block_duration = event_duration + min_inter_event_duration;
    
    if duration < num_events * event_block_duration
        error('ERROR: Too many events to fit into given interval.');
    end
    
    block_size = duration / num_events;
    % How much free space (no event) is within each block.
    block_hole_size = block_size - event_duration;
    
    % Note, even if the second event is at the end of its block, the 
    % 'min_inter_event_duration' is still between this event and the end of
    % the second block.
    max_inter_event_duration = 2 * block_hole_size - ...
        min_inter_event_duration;
    
    disp(['Minimum time between two events: ', ...
        num2str(min_inter_event_duration), ' seconds.']);
    disp(['Maximum time between two events: ', ...
        num2str(max_inter_event_duration), ' seconds.']);
    
    onset_times = zeros(1, num_events);
    
    window_offset = onset_pause;
    
    for i = 1:num_events
        r = rand();
        
        onset_times(i) = window_offset + r * ...
            (block_size - event_block_duration);
        
        window_offset = window_offset + block_size;
    end
    
%     % Plot Results
%     sampling_rate = 1000;
%     xData = 0:1/sampling_rate:total_duration;
%     yData = zeros(1, length(xData));
%     for i = 1:num_events
%         s = floor(onset_times(i) * sampling_rate) + 1;
%         e = s + floor(event_duration * sampling_rate) + 1;
%         
%         yData(1, s:e) = 1;
%     end
%     figure;
%     plot(xData, yData);
%     xlabel('Time (s)');
%     ylabel('Event (yes/no)');
end

