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
@title           :freezingProbability.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/12/2018
@version         :1.0

Evaluate the freezing probability around tone presentations for each cohort
or group seperately.

Note, the current implementation does not take into account individual
subjects. I.e., compute mean and std freezing traces only by splitting
events into classes/sessions/event-types, throwing away the subject
information.
%}

function  freezingProbability(p, recordings, behaviorInterface, cmpGroups)
%freezingProbability In this function, we look at the freezing
%probability of recordings clustered by classes, sessions and event types.
%   
%   This function will generate a plot for each event type. The rows of the
%   plots will show the development of each class (cohort or group) during 
%   the experiment (i.e., columns are sessions).

    if nargin < 4
        cmpGroups = false;
    end
    
    ident = 'cohorts';
    if cmpGroups
        ident = 'groups';
    end
    identU = [upper(ident(1)) ident(2:end)];

    logger = log4m.getLogger();
    logger.info('freezingProbability', ['Evaluating freezing ' ...
        'probabilities around tone presentations for ' ident '.']);

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
    
    rate = p.evalRate;

    % Maximum length of a presentation.
    extraWin = ceil(p.eventPresentationWindow * rate);
    maxEventDur = max(props.maxEventLengths);
    maxEventLen = ceil(maxEventDur * rate);
    eventWin = 2 * extraWin + maxEventLen;
    
    %preInd = 1;
    onInd = extraWin + 1; % first index belonging to tone presentation
    offInd = onInd + maxEventLen; % fist index belonging to after tone win
    %postInd = eventWin;
    
    %% Compare Freezing Probabilities between classes.
    % We compute the average freezing probability of recordings in a class
    % for each session separately. So, we only distinguish between classes,
    % sessions and event types.
    
    % We need to store all individual prob traces in an array to compute
    % the std. Therefore, we need to know how many traces are there
    % maximally per class, session and event type
    numEventsPerCST = zeros(numClasses, numSessions, numETs);
    for c = 1:numClasses
        cInds = classInds{1, c};
        for s = 1:numSessions
            sInds = cInds([recs(cInds).session] == s);
            
            % For all recordings belonging to class c and session s.
            for r = sInds          
                assert(recs(r).(ident(1:end-1)) == c && ...
                    recs(r).session == s);
                
                events = recs(r).events;
                for t=1:numETs
                    et = props.eventTypes(t);
                    etInds = find(strcmp(events.type, et));
                    
                    numEventsPerCST(c, s, t) = ...
                        numEventsPerCST(c, s, t) + length(etInds);
                end
            end
        end
    end
    
    % Maximum number of event presentations per class, session, event type.
    maxNumEventsInCST = max(numEventsPerCST(:));
    frezProbsCST = zeros(numClasses, numSessions, numETs, ...
        maxNumEventsInCST, eventWin);
    % When we are filling frezProbsCST, we need to know in which column to
    % write. Also, we need to know the support of each CST afterwards.
    frezProbsCSTInds = ones(numClasses, numSessions, numETs, 'uint8');
    % Also, we need a binary map that states whether or not a value for the
    % considered array element exists to compute the support for each time
    % frame. So, when we later compute the average and std, we ignore
    % positions that have still the original zero values in this array.
    frezProbsCSTSup = zeros(numClasses, numSessions, numETs, ...
        maxNumEventsInCST, eventWin, 'logical');
    
    % When we later plot the probabilities, we want to adjust the event
    % presentation window size according to the actual data. As we compare
    % classes, we want that the plots for an individual class have the same
    % time axis. Hence, we need the maximum event length per session/event
    % type.
    maxEventLenPerST = zeros(numSessions, numETs);
    
    for r = 1:numRecs
        if cmpGroups
            c = recs(r).group;
        else
            c = recs(r).cohort;
        end
        s = recs(r).session;
        
        events = recs(r).events;
        
        behavior = behaviorInterface{r};
        
        for t=1:numETs
            et = props.eventTypes(t);
            etInds = find(strcmp(events.type, et));            

            for ss=etInds
                i = frezProbsCSTInds(c, s, t);
                frezProbsCSTInds(c, s, t) = frezProbsCSTInds(c, s, t) + 1;
                
                [ftrace, fsupport] = ...
                    behavior.getEventFreezingStandardSingle(ss, ...
                        maxEventDur, p.eventPresentationWindow);
                % We compute them the same way.
                assert(eventWin == size(ftrace, 2));
                    
                frezProbsCST(c, s, t, i, :) = ftrace;
                frezProbsCSTSup(c, s, t, i, :) = fsupport;
                
                eventDuration = recs(r).events.duration(ss);
                eventDuration = ceil(eventDuration * rate);
                maxEventLenPerST(s,t) = max(maxEventLenPerST(s,t), ...
                    eventDuration);
            end
        end
    end
    
    % Now, we have the data ready to compute average and std values of the
    % freezing probabilities.
    frezProbsCSTMean = zeros(numClasses, numSessions, numETs, eventWin);
    frezProbsCSTStd = zeros(numClasses, numSessions, numETs, eventWin);
    
    for c = 1:numClasses
        for s = 1:numSessions
            for t = 1:numETs
                % Find out, if there are timeframes in event presentations,
                % where we have no data from.
                fp = squeeze(frezProbsCST(c, s, t, :, :));
                fpsup = squeeze(frezProbsCSTSup(c, s, t, :, :));
                assert(ismatrix(fpsup));
                % If this is the case, then we have varying length event
                % presentations (or windows around the presentations that
                % are cropped on the boundaries of the recorded traces).
                % Hence, the comparison over the interval of the longest
                % tone presentation is tricky.
                sameLength = all(~any(fpsup, 2) | all(fpsup, 2));
                if ~sameLength
                    logger.warn('freezingProbability', ['Is ' ...
                        'session ' num2str(s) ' of ' ident(1:end-1) ... 
                        ' ' num2str(c) ' (event type ' num2str(t) ...
                        ') there are tone presentations with a length ' ...
                        'deviating from the longest presentation in ' ...
                        'all recordings.']);
                end
                
                if isempty(find(fpsup, 1))
                    logger.warn('freezingProbability', ['No ' ...
                        'data in session ' num2str(s) ' of ' ...
                        ident(1:end-1) ' ' num2str(c) ' (event type ' ...
                        num2str(t) ').']);
                end
                
                if sameLength
                    % FIXME, I am not sure whether the mean and std 
                    % functions still work as expected if 
                    % maxNumEventsInCST == 1. They might collapse the 
                    % eventWin dimension (a single value is the output). 
                    assert(maxNumEventsInCST > 1);
                    
                    frezProbsCSTMean(c,s,t,:) = mean(fp);
                    frezProbsCSTStd(c,s,t,:) = std(fp);
                else
                    % This is very time consuming, but in order to be
                    % correct, we should do it that way.
                    for tt = 1:size(fp, 2)
                        valInds = find(fpsup(:,tt));
                        
                        % Note, if no support, i.e, isempty(valInds) == 1,
                        % then we assign NaN.
                        frezProbsCSTMean(c,s,t,tt) = mean(fp(valInds, tt));
                        frezProbsCSTStd(c,s,t,tt) = std(fp(valInds, tt));
                    end
                end
            end
        end
    end
    
    tData = 0:1/rate:(eventWin-1)/rate;
    tData = tData.';
    
    % Avoid plotting trouble for time points that have no support
    % (resulting due to varying event lengths). Should have no plotting
    % effect, if within a class/session all events have the same length (or
    % at least the maximum length in all classes per session are equal).
    frezProbsCSTMean(isnan(frezProbsCSTMean)) = 0;
    frezProbsCSTStd(isnan(frezProbsCSTStd)) = 0;
    
    % Value correction, such that we plot percentage values.
    frezProbsCSTMean = frezProbsCSTMean * 100;
    frezProbsCSTStd = frezProbsCSTStd * 100;
    
    frezProbMeanPlusStd = frezProbsCSTMean + frezProbsCSTStd;
    frezProbMeanMinusStd = frezProbsCSTMean - frezProbsCSTStd;
    % Uniform Y axes for all subplots.;
    minYVal = min(frezProbMeanMinusStd(:)) - .1;
    maxYVal = max(frezProbMeanPlusStd(:)) + .1;
    
    % Now, we can finally plot the results. One plot for each event type.
    for t = 1:numETs   
        et = props.eventTypes(t);
        fig = figure('Name', ['Freezing Probability of event type ' ...
            char(et)]); %'visible', 'off');
        
        nr = numClasses;
        nc = numSessions;
        cp = 1;
        
        for c = 1:numClasses
            for s = 1:numSessions
                subplot(nr, nc, cp);
                cp = cp + 1;
                title([identU(1:end-1) ': ' num2str(c) ', Session: ' ...
                    num2str(s)]);
                                
                meanFrzProb = squeeze(frezProbsCSTMean(c,s,t,:));
                
                meanPlusStd = squeeze(frezProbMeanPlusStd(c,s,t,:));
                meanMinusStd = squeeze(frezProbMeanMinusStd(c,s,t,:));
                
                % Cut out relevant part.
                % FIXME: Don't know why -1 is necessary.
                endTone = extraWin + maxEventLenPerST(s,t)-1;
                startAfter = offInd;
                meanFrzProb = [meanFrzProb(1:endTone); ...
                    meanFrzProb(startAfter:end)];
                meanPlusStd = [meanPlusStd(1:endTone); ...
                    meanPlusStd(startAfter:end)];
                meanMinusStd = [meanMinusStd(1:endTone); ...
                    meanMinusStd(startAfter:end)];
                tDataCS = tData(1:length(meanFrzProb));

                hold on
                plot(tDataCS, meanFrzProb, 'k', 'LineWidth', 2)
                %minVal = min(meanMinusStd) - .1;
                %maxVal = max(meanPlusStd) + .1;
                startSWin = p.eventPresentationWindow;
                endSWin = tData(endTone);
                area([startSWin endSWin], [maxYVal maxYVal], ...
                    'basevalue', minYVal, 'FaceAlpha', .2, 'FaceColor', ...
                    'r', 'LineStyle', 'none')
                
                % As there might be too many data points for the fill
                % method to work, we need to downsample the data.
                factor = floor(length(tDataCS) / 50);
                tDataDS = downsample(tDataCS, factor).';
                meanPlusStd = downsample(meanPlusStd, factor).';
                meanMinusStd = downsample(meanMinusStd, factor).';
               
                fh = fill([tDataDS fliplr(tDataDS)], ...
                    [meanPlusStd fliplr(meanMinusStd)], 'k');
                alpha(0.25);
                set(fh,'EdgeColor','none');

%                 plot(tDataDS, meanPlusStd, 'Color', 'k', ...
%                     'LineStyle', '--', 'LineWidth', 1);
%                 plot(tDataDS, meanMinusStd, 'Color', 'k', ...
%                     'LineStyle', '--', 'LineWidth', 1);
                
                xlim([0 eventWin / rate])
                ylim([minYVal maxYVal])
                xlabel('Time(s)')
                ylabel('Mean Freezing Probability')
            end
        end
        
        fpPath = fullfile(p.resultDir, ['frzProb' identU '_EventType_' ...
            char(et)]);
        saveas(fig, [fpPath '.png']);
        savefig(fig, [fpPath '.fig']);
    end 
