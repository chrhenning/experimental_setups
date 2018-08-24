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
@title           :discriminabilityIndex.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/16/2018
@version         :1.0

Computing the sensitivity index between CS+ and CS- representations in
order to measure how good the learning has been.
%}


function discriminabilityIndex(p, recordings, behaviorInterface, cmpGroups)
%discriminabilityIndex Measure the sensitivity index per class (cohort or
%group) and session.
%
%   In this function, we compute the sensitivity index per class (cohort or
%   group (if cmpGroups is true) and session. They are subsequently
%   plotted.
%
%   More precise, the discriminability index is computed per subject, which
%   we can use to estimate standard deviations.
%
%   We use this definition: 
%   https://en.wikipedia.org/wiki/Sensitivity_index
%
%   All freezing traces within a class/session belonging either to 
%   p.reinforcedEventTypes or not to it, are treated equally, i.e., we
%   ignore subject specificity.
%
%   NOTE, at the moment, we compute the freezing probability only by
%   looking at the exact time window spanned by the event (no extra slack
%   as in other measures).


    if nargin < 4
        cmpGroups = false;
    end
    
    ident = 'cohorts';
    identNC = 'groups'; % NC = not considered
    if cmpGroups
        ident = 'groups';
        identNC = 'cohorts';
    end
    identU = [upper(ident(1)) ident(2:end)];
    
    logger = log4m.getLogger();
    logger.info('discriminabilityIndex', ['Computing discriminability ' ...
        'index at event presentations for ' ident '. The ' ...
        'following event types are considered as CS+: ' ...
        strjoin(p.reinforcedEventTypes)]);

    recs = recordings.recs;
    props = recordings.props;
    
    
    numClasses = props.numCohorts;
    numClassesNC = props.numGroups;
    if cmpGroups
        numClasses = props.numGroups;
        numClassesNC = props.numCohorts;
    end
    numSubjects = props.numSubjects;
    numSubjectsPerC =  numClassesNC * numSubjects;
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
    
    %% Compute sensitivity index per class/session.
    % We need to know, how many CS+ and CS- presentations we have per
    % class/session/subject. We don't distinguish between recordings of the 
    % same class/session/subject
    % First index: CS+ (1), CS- (2)
    numEventsPerCS = zeros(2, numClasses, numSessions, numSubjectsPerC);
    for r = 1:numRecs
        c = recs(r).(ident(1:end-1));
        cNC = recs(r).(identNC(1:end-1));
        s = recs(r).session;
        m = (cNC-1) * numSubjects + recs(r).subject;
        
        events = recs(r).events;

        for t=1:numETs
            st = props.eventTypes(t);
            stInds = find(strcmp(events.type, st));

            if any(ismember(p.reinforcedEventTypes, char(st)))
                numEventsPerCS(1,c,s,m) = numEventsPerCS(1,c,s,m) + ...
                    length(stInds);
            else
                numEventsPerCS(2,c,s,m) = numEventsPerCS(2,c,s,m) + ...
                    length(stInds);
            end
        end
    end
    
    maxEventsPerCS = max(numEventsPerCS(:));
    
    % Compute feezing probabilities for all events.
    frezProbs = zeros(2, numClasses, numSessions, numSubjectsPerC, ...
        maxEventsPerCS);
    frezProbsSup = zeros(2, numClasses, numSessions, numSubjectsPerC);
    
    for r = 1:numRecs
        c = recs(r).(ident(1:end-1));
        cNC = recs(r).(identNC(1:end-1));
        s = recs(r).session;
        m = (cNC-1) * numSubjects + recs(r).subject;
        
        events = recs(r).events;
        behavior = behaviorInterface{1, r};

        for t=1:numETs
            st = props.eventTypes(t);
            stInds = find(strcmp(events.type, st));
            
            cst = 2;
            if any(ismember(p.reinforcedEventTypes, char(st)))
                cst = 1;
            end
            
            for ss = stInds
            
                % Freezing trace of this event presentation.
                % We ignore the window before the event (since it
                % doesn't make sense to look at it). The window after
                % the event presentation, could in principle be
                % included.
                [~, ftrace, ~] = behavior.getEventFreezing(...
                    ss, p.eventPresentationWindow);
                %ftrace = [ftrace, postFTrace];

                % Freezing probability.
                fprob = sum(ftrace) / length(ftrace);
                
                frezProbsSup(cst,c,s,m) = frezProbsSup(cst,c,s,m) + 1;
                i = frezProbsSup(cst,c,s,m);
                frezProbs(cst, c, s, m, i) = fprob;
            end
        end
    end

    assert(all(frezProbsSup(:) == numEventsPerCS(:)));
    
    % Now we can compute mean and std, using the computed support values.
    frezProbMean = zeros(2, numClasses, numSessions, numSubjectsPerC);
    frezProbStd = zeros(2, numClasses, numSessions, numSubjectsPerC);
    
    for cst = 1:2
        for c = 1:numClasses
            for s = 1:numSessions
                for m = 1:numSubjectsPerC
                    support = frezProbsSup(cst,c,s,m);
                    frezProbMean(cst,c,s,m) = ...
                        mean(frezProbs(cst,c,s,m,1:support));
                    frezProbStd(cst,c,s,m) = ...
                        std(frezProbs(cst,c,s,m,1:support));
                end
            end
        end
    end

    % This information can directly be used to compute the sensitivity
    % index.
    sensitivityIndex = zeros(numClasses, numSessions, numSubjectsPerC);
    % Does subject exist in this class/session?
    sensitivityIndexSup = ones(numClasses, numSessions, numSubjectsPerC);
    for c = 1:numClasses
        for s = 1:numSessions
            for m = 1:numSubjectsPerC
                mu_p = frezProbMean(1,c,s,m);
                mu_m = frezProbMean(2,c,s,m);

                sig_p = frezProbStd(1,c,s,m);
                sig_m = frezProbStd(2,c,s,m);

                si = (mu_p - mu_m) / sqrt(0.5 * (sig_p^2 + sig_m^2));
                if isnan(si)
                    si = 0; % no freezing, no discrimination
                end
                sensitivityIndex(c,s,m) = si;
                
                if ~any(frezProbsSup(:,c,s,m) ~= 0)
                    % No support at this point. I.e., either no event or
                    % subject does not exist.
                    sensitivityIndexSup(c,s,m) = 0;
                end
            end
        end
    end
    
    % Mean and std discriminability index across subjects but within
    % classes/sessions.
    sensitivityIndexMean = zeros(numClasses, numSessions);
    sensitivityIndexStd = zeros(numClasses, numSessions);
    for c = 1:numClasses
        for s = 1:numSessions
            % Only consider subjects that exist.
            mInds = frezProbsSup(1,c,s,:) > 0 & frezProbsSup(2,c,s,:) > 0;
            sensitivityIndexMean(c,s) = mean(sensitivityIndex(c,s,mInds));
            sensitivityIndexStd(c,s) = std(sensitivityIndex(c,s,mInds));
            
        end
    end
    
    for c = 1:numClasses
        logger.info('discriminabilityIndex', [identU(1:end-1) ' ' ...
                num2str(c) ': The following mean discriminability ' ...
                'indices have been computed for the sessions: ' ...
                mat2str(squeeze(sensitivityIndexMean(c,:)))]);
    end
    
    % FIXME Use ANOVA for more than 2 classes.
    if numClasses == 2
        for s = 1:numSessions
            mInds1 = sensitivityIndexSup(1,s,:) == 1;
            mInds2 = sensitivityIndexSup(2,s,:) == 1;
            [~, pVal] = ttest2(squeeze(sensitivityIndex(1,s,mInds1)), ...
                squeeze(sensitivityIndex(2,s,mInds2)));
            logger.info('discriminabilityIndex', ['Session ' ...
                num2str(s) ': Two-sample t-test: p-value = ' ...
                num2str(pVal) '.']);
        end
           
        for s = 1:numSessions
            mInds1 = sensitivityIndexSup(1,s,:) == 1;
            mInds2 = sensitivityIndexSup(2,s,:) == 1;
            pVal = ranksum(squeeze(sensitivityIndex(1,s,mInds1)), ...
                squeeze(sensitivityIndex(2,s,mInds2)));
            logger.info('discriminabilityIndex', ['Session ' ...
                num2str(s) ': Wilcoxon rank sum test: p-value = ' ...
                num2str(pVal) '.']);                
        end
    end
    
    % If animals are shocked in the current session, then we
    % ignore the results of the whole session.    
    for c = 1:numClasses
        cInds = classInds{1, c};
        for s = 1:numSessions
            cshocks = [recs(cInds([recs(cInds).session] == s)).shocks];
            if ~isempty(cshocks) && ~isempty([cshocks.onset])
                sensitivityIndexMean(c,s) = NaN;
                sensitivityIndexStd(c,s) = NaN;
                
                logger.info('discriminabilityIndex', ['Freezing ' ...
                    'behavior of ' ident(1:end-1) ' ' num2str(c) ...
                    ' in session ' num2str(s) ' is ignored in the ' ...
                    'plot due to induced shocks.']);
            end
        end
    end
    
    fig = figure('Name', ['Discriminability indices for ' ident], ...
        'Position',[100 100 600 300]);

    cols = linspecer(numClasses);

    b = barwitherr(sensitivityIndexStd.', sensitivityIndexMean.');

    labels = cell(1, numClasses);
    for i = 1:numClasses
        labels{1, i} = [identU(1:end-1) ' ' num2str(i)];
        b(i).FaceColor = cols(i,:);       
    end

    xlabel('Days')
    ylabel('Discriminability Index')
    set(gca, 'FontSize', 16)

    %ylim([0,1])
    xlim([0 numSessions+1])

    legend(labels, 'Location','northwest');
    
    fpPath = fullfile(p.resultDir, ['discrIndex_' identU]);
    saveas(fig, [fpPath '.png']);
    savefig(fig, [fpPath '.fig']);
    
    %% Plot discriminalbility index per subject.
    fig = figure('Name', ['Discriminability indices per sbject for ' ...
        ident], 'Position',[100 100 600 300]);
    xlim([0, (numClasses+1) * numSessions]);
    
    cols = linspecer(numClasses * numSubjectsPerC);
    colsRec = linspecer(numClasses);
    
    minSI = min(sensitivityIndex(:));
    maxSI = max(sensitivityIndex(:));
    diffSI = maxSI - minSI;
    minSI = minSI - 0.05 * diffSI;
    maxSI = maxSI + 0.05 * diffSI;
    
    hold on;
    for s = 1:numSessions
        for c = 1:numClasses
            xpos = (s-1) * (numClasses+1) + c;
            
            mInds = find(sensitivityIndexSup(c,s,:) == 1)';
            for m = mInds
                ypos = sensitivityIndex(c, s, m);
                %col = cols((c-1)*numSubjectsPerC + m, :);
                col = cols(c + (m-1)*numClasses, :);
                scatter(xpos, ypos, 'MarkerFaceColor', col, ...
                    'MarkerEdgeColor', 'none');
            end
            
            rectangle('Position', [xpos-0.4,minSI,0.8,maxSI-minSI], ...
                'EdgeColor', colsRec(c, :), 'LineWidth', 2, ...
                'LineStyle', ':');
        end
    end
    
    legendItems(1, 1:numClasses) = fig;
    legendTexts = cell(1, numClasses);
    for c = 1:numClasses
        legendItems(c) = line(NaN, NaN, 'LineWidth', 2, ...
            'Color', colsRec(c, :));
        legendTexts{c} = [identU(1:end-1) ' ' num2str(c)];
    end

    legend(legendItems, legendTexts);
    
    xticks((numClasses-1)/2+1:numClasses+1:numSessions*(numClasses+1));
    xticklabels(1:1:numSessions)
    
    xlabel('Days')
    ylabel('Discriminability Index')
    set(gca, 'FontSize', 16)
    
    fpPath = fullfile(p.resultDir, ['discrIndex_perSubject_' identU]);
    saveas(fig, [fpPath '.png']);
    savefig(fig, [fpPath '.fig']);    
end

