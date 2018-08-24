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
@title           :plotConjoinedTraces.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :04/06/2018
@version         :1.0
%}


function plotConjoinedTraces(p, recordings, behaviorInterface, cmpGroups)
%PLOTCONJOINEDTRACES This function plots traces (events and freezing) per
%class/session.
%
% I.e., the traces are agregated over all subjects within a class/session.
% So they are not binary, but depict probabilities.

    if nargin < 4
        cmpGroups = false;
    end
    
    ident = 'cohorts';
    if cmpGroups
        ident = 'groups';
    end
    identU = [upper(ident(1)) ident(2:end)];

    logger = log4m.getLogger();
    logger.info('plotConjoinedTraces', ['Plotting conjoined ' ...
        'traces per subject and ' ident(1:end-1) '.']);

    recs = recordings.recs;
    props = recordings.props;
    
    numClasses = props.numCohorts;
    if cmpGroups
        numClasses = props.numGroups;
    end
    numSessions = props.numSessions;
    numETs = length(props.eventTypes);
    numRecs = length(recs);
    
    classInds = cell(1, numClasses);
    for i = 1:numClasses
        if cmpGroups
            classInds{1, i} = find([recs.group] == i);
        else
            classInds{1, i} = find([recs.cohort] == i);
        end
    end
    
    %% Compute conjoined traces.
    % We can't assume that all recordings within a subject/class have the
    % same duration.
    maxStepsPerCS = zeros(numClasses, numSessions);
    for r = 1:numRecs
        c = recs(r).(ident(1:end-1));
        s = recs(r).session;
        
        maxStepsPerCS(c,s) = max(maxStepsPerCS(c,s), ...
            length(recs(r).relativeTimestamps));
    end
    
    % Freezing + event traces per class and session.
    frezPerCS = cell(numClasses, numSessions);
    frezPerCSSup = cell(numClasses, numSessions);

    eventPerCS = cell(numETs, numClasses, numSessions);
    eventPerCSSup = cell(numETs, numClasses, numSessions);
    
    for r = 1:numRecs
        c = recs(r).(ident(1:end-1));
        s = recs(r).session;
        
        behavior = behaviorInterface{r};
        ftrace = behavior.getFreezing();
        
        % Compute event traces from scratch, as they are not stored.        
        tData = recs(r).relativeTimestamps;
        etraces = zeros(numETs, length(tData));

        for ee = 1:numETs
            et = props.eventTypes(ee);
            etInds = find(strcmp(recs(r).events.type, et));
            eventOnset = recs(r).events.onset(etInds);
            eventOffset = eventOnset + recs(r).events.duration(etInds);
            tDataTemp = repmat(tData.', 1, length(eventOnset));
            etraces(ee, any(tDataTemp > eventOnset & ...
                tDataTemp < eventOffset, 2)) = 1;
        end
        
        % Assign computed traces.
        if isempty(frezPerCS{c, s})
            frezPerCS{c, s} = zeros(1, maxStepsPerCS(c,s));
            frezPerCSSup{c, s} = zeros(1, maxStepsPerCS(c,s));
            for st = 1:numETs
                eventPerCS{st, c, s} = zeros(1, maxStepsPerCS(c,s));
                eventPerCSSup{st, c, s} = zeros(1, maxStepsPerCS(c,s));
            end
        end

        lf = length(ftrace);
        frezPerCS{c, s}(1:lf) = frezPerCS{c, s}(1:lf) + ftrace;
        frezPerCSSup{c, s}(1:lf) = frezPerCSSup{c, s}(1:lf) + 1;
        
        for st = 1:numETs
            lss = length(etraces(st, :));
            eventPerCS{st, c, s}(1:lss) = eventPerCS{st, c, s}(1:lss) + ...
                etraces(st, :);
            eventPerCSSup{st, c, s}(1:lss) = ...
                eventPerCSSup{st, c, s}(1:lss) + 1;
        end
    end
    
    %% Plot traces.
    nr = numClasses;
    nc = numSessions;
    cp = 1;
    
    cols = linspecer(1+numETs);
    
    fig = figure('Name', ['Avg Traces per ' identU(1:end-1) '/Session']);
    for c = 1:numClasses
        for s = 1:numSessions
            subplot(nr, nc, cp);
            cp = cp + 1;
            hold on;
            
            if isempty(frezPerCS{c, s})
                continue;
            end
            
            labels = cell(1, numETs);
            
            frezPerCS{c, s} = frezPerCS{c, s} ./ frezPerCSSup{c, s};
            labels{1} = 'Freezing'; % CR
            for st = 1:numETs
                eventPerCS{st, c, s} = eventPerCS{st, c, s} ./ ...
                    eventPerCSSup{st, c, s};
                labels{1+st} = props.eventTypes(st);
            end
            
            % Downsample data to decrease runtime (a scatter plot per
            % timepoint is very time consuming).
            duration = maxStepsPerCS(c,s) / p.evalRate;
            tDataOrig = linspace(0, duration, duration * p.evalRate);
            tData = linspace(0, duration, duration * p.conjoinedPlotsRate);
            
            frezPerCS{c, s} = interp1(tDataOrig, frezPerCS{c, s}, ...
                tData, 'linear', 'extrap');
            for st = 1:numETs
                eventPerCS{st,c,s} = interp1(tDataOrig, ...
                    eventPerCS{st,c,s}, tData, 'linear', 'extrap');
            end

            for i = 1:length(tData)
                t = tData(i);
                sp = scatter(t, 1, 20, cols(1, :), 'filled');
                sp.MarkerFaceAlpha = frezPerCS{c, s}(i);  
                sp.MarkerEdgeAlpha = frezPerCS{c, s}(i);  
                
                for st = 1:numETs
                    sp = scatter(t, 1+st, 20, cols(1 + st, :), 'filled');
                    sp.MarkerFaceAlpha = eventPerCS{st, c, s}(i);  
                    sp.MarkerEdgeAlpha = eventPerCS{st, c, s}(i);  
                end
            end
            
            xlabel('Time (in seconds)');
            xlim([0 tData(end)]);
            ylim([0 (1+numETs+1)]);
            yticks(gca, 1:1:(1+numETs));
            if s == 1
                yticklabels(gca, labels);
            else
                yticklabels(gca, {});
            end
            set(gca,'FontSize',16);

            title([identU(1:end-1) ': ' num2str(c) ', Session: ' ...
                num2str(s)]);
        end
    end
    fpPath = fullfile(p.resultDir, ['conjoinedTraces_' identU]);
    savefig(fig, [fpPath '.fig']);
end

