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
@title           :evalControl.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/11/2018
@version         :1.0

We run through all recording in this function to compute all major
evaluation metrics.

We don't wanna store the traces (e.g., freezing trace) for all videos
concurently in memory. Therefore, all evaluation measures are split into
two functions. A 'single' function takes the traces of individual
recordings and extracts the information it needs to compare with others.

After we looped through all recordings (computed the traces once), we run
the 'complete' function of each evaluation measure, which will evaluate all
recordings without the need to comput the full traces again.

Note, that we store traces event-based in the recordings struct.
%}

function evalControl(p, recordings)
%EVALCONTROL Summary of this function goes here
%   Detailed explanation goes here

    logger = log4m.getLogger();
    logger.info('evalControl', ['Starting concurrent extraction of '...
        'information from all recordings.']);
    
    recs = recordings.recs;
    props = recordings.props;
    
    numETs = length(props.eventTypes);
    numRecs = length(recs);
    
    % BehaviorWrapper objects for all recordings.
    behavior = cell(1, numRecs);
        
    for i = 1:length(recs)
        %c = recs(i).cohort;
        %g = recs(i).group;
        %s = recs(i).session;
        
        logger.info('evalControl', ['Plotting traces and extracting '...
           'information for recording: ' recs(i).relativeDataFolder '.']);

        %% Create traces for freezing, events and shocks.
        tData = recs(i).relativeTimestamps;
        events = zeros(numETs, length(tData));
        shocks = zeros(1, length(tData));
        frezs = zeros(1, length(tData));
        
        shockOnset = recs(i).shocks.onset;
        shockOffset = shockOnset + recs(i).shocks.duration;
        if ~isempty(shockOnset)
            tDataTemp = repmat(tData.', 1, length(shockOnset));
            shocks(any(tDataTemp > shockOnset & ...
                tDataTemp < shockOffset, 2)) = 1;
        end
        
        frezOnset = recs(i).freezing.onset;
        frezOffset = frezOnset + recs(i).freezing.duration;
        tDataTemp = repmat(tData.', 1, length(frezOnset));
        frezs(any(tDataTemp > frezOnset & tDataTemp < frezOffset, 2)) = 1;
        
        for ee = 1:numETs
            et = recordings.props.eventTypes(ee);
            etInds = find(strcmp(recs(i).events.type, et));
            eventOnset = recs(i).events.onset(etInds);
            eventOffset = eventOnset + recs(i).events.duration(etInds);
            tDataTemp = repmat(tData.', 1, length(eventOnset));
            events(ee, any(tDataTemp > eventOnset & ...
                tDataTemp < eventOffset, 2)) = 1;
        end
        
        %% Plot traces of current recording.
        % Note, this is very time consuming.
        plotTraces(p, recordings, i, tData, frezs, shocks, events);
        
        %% Instantiate behavior interface.
        % This information will later be used to compute evaluation
        % metrics.
        behavior{i} = BehaviorWrapper(recs(i), i, frezs, p);
    end

    freezingProbability(p, recordings, behavior);
    freezingProbability(p, recordings, behavior, true);
    freezingPercentage(p, recordings, behavior);
    freezingPercentage(p, recordings, behavior, true);
    discriminabilityIndex(p, recordings, behavior);
    discriminabilityIndex(p, recordings, behavior, true);

    plotConjoinedTraces(p, recordings, behavior);
    plotConjoinedTraces(p, recordings, behavior, true);
end
