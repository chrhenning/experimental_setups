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
@title           :freezingPercentage.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/12/2018
@version         :1.0

Looking at buckets of presentations of a event type during a session and
computing the freezing percentage.
%}

function freezingPercentage(p, recordings, behaviorInterface, cmpGroups)
%FREEZINGPERCENTAGE A function that plots the freezing probability of
%grouped event presentations per session in a bar chart.
%
%   The parameter cmpGroups is optionally. The default is false, where we
%   compare cohorts not groups.
%
%   The function is quite complex. And may fail (with an error message) if
%   it cannot resolve some issues.
%
%   The function looks at event presentations and tries to put them into a
%   bucket, such that event presentations from the same event type are
%   within the same bucket.
%
%   Example:
%   Assume, a recording has a event trace like this: 1 2 1 2 1 2.
%   As we have two event types, we need at least two buckets. Standard
%   bucket sizes are 4, 3 or 2. In this case, a bucket size of 3 would be
%   chosen. Since all presentations of a event type fit into 1 bucket, it
%   will only need two buckets (each having three elements).
%
%   I.e., the following bucket list would be created: 1 2 with sizes 3 3.
%   The bucket number represents the event type. The first appearance of a
%   event type determines the order of the buckets.
%
%   In the first bucket, we place the 3 first event freezing probabilities
%   belonging to event type 1 for all recordings belonging to the current
%   class (cohort or group) and session.
%
%   FIXME: As we have plotting issues, the program will resort the bucket
%   lists to make them look alike for all sessions.
%
%   NOTE, at the moment, we compute the freezing probability only by
%   looking at the exact time window spanned by the event (no extra slack
%   as in other measures).

    if nargin < 4
        cmpGroups = false;
    end
    
    ident = 'cohorts';
    if cmpGroups
        ident = 'groups';
    end
    identU = [upper(ident(1)) ident(2:end)];
    
    logger = log4m.getLogger();
    logger.info('freezingPercentage', ['Evaluating freezing ' ...
        'development at event presentations for ' ident '.']);

    recs = recordings.recs;
    props = recordings.props;
    
    numClasses = props.numCohorts;
    if cmpGroups
        numClasses = props.numGroups;
    end
    numSessions = props.numSessions;
    numETs = length(props.eventTypes);
    
    classInds = cell(1, numClasses);
    for i = 1:numClasses
        if cmpGroups
            classInds{1, i} = find([recs.group] == i);
        else
            classInds{1, i} = find([recs.cohort] == i);
        end
    end
    
    %% Decide on bucket size per session.
    % Within a session, we need all animals (belonging either to the same
    % cohort or group) to have the same number of events per recording
    % belonging to a certain event type.
    numEvents = -1 * ones(numClasses, numSessions, numETs);
    
    maxNumRecsPerCS = 0;
    
    for c = 1:numClasses
        cInds = classInds{1, c};
        for s = 1:numSessions
            sInds = cInds([recs(cInds).session] == s);
            maxNumRecsPerCS = max(maxNumRecsPerCS, length(sInds));
            for r = sInds
                assert(recs(r).(ident(1:end-1)) == c && ...
                    recs(r).session == s);
                
                events = recs(r).events;
                numPerET = zeros(1, numETs);
                for t = 1:numETs
                    st = props.eventTypes(t);
                    numPerET(t) = length(find(strcmp(events.type, st)));
                end
                
                if numEvents(c, s, 1) == -1
                    numEvents(c, s, :) = numPerET;
                elseif any(numEvents(c, s, :) ~= numPerET)
                    logger.error('freezingPercentage', ['Function ' ...
                        'cannot handle experiments with different ' ...
                        'event designs within a session.']);
                    return;
                end
            end
        end
    end
    % Missing data.
    numEvents(numEvents == -1) = 0;
    
    % Now, we can decide on bucket sizes.
    bucketSizes = zeros(numClasses, numSessions, numETs);

    % Maximum number of buckets (bars in the chart) per session).
    maxNumBuckets = 0;
    
    for c = 1:numClasses
        for s = 1:numSessions
            numBuckets = 0;
            
            for t = 1:numETs
                nums = numEvents(c, s, t);
                if nums == 0
                    bs = 0;
                elseif mod(nums, 4) == 0
                    bs = 4;
                elseif mod(nums, 3) == 0
                    bs = 3;
                elseif mod(nums, 2) == 0
                    bs = 2;
                else
                    bs = nums;
                end
                bucketSizes(c,s,t) = bs;
                
                if nums > 0
                    numBuckets = numBuckets + nums / bs;
                end
            end
            
            maxNumBuckets = max(maxNumBuckets, numBuckets);
        end
    end
    
    % Print the chosen bucket sizes, as they may heavily influence the
    % results and are a programmer choice.
    if all(bucketSizes == bucketSizes(1))
        logger.info('freezingPercentage', ['A bucket size of ' ...
            num2str(bucketSizes(1)) ' has been chosen.']);
    else
        for c = 1:numClasses
            if all(bucketSizes(c, :) == bucketSizes(c, 1))
                logger.info('freezingPercentage', [identU(1:end-1) ...
                    ' ' num2str(c) ': A bucket size of ' ...
                    num2str(bucketSizes(c, 1)) ' has been chosen.']);
            else
                for s = 1:numSessions
                    % That should usually be always the case. Otherwise we
                    % display all bucket sizes and a warning.
                    if all(bucketSizes(c,s,:) == bucketSizes(c,s,1))
                        logger.info('freezingPercentage', ...
                            [identU(1:end-1) ' ' num2str(c) ', session '...
                            num2str(s) ': A bucket size of ' ...
                            num2str(bucketSizes(c, 1)) ...
                            ' has been chosen.']);
                    else
                        % Why the warning? Might not be an optimal measure,
                        % if bucket sizes differ heavily.
                        logger.warn('freezingPercentage', ...
                            'Bucket sizes differ within sessions.');
                        for t = 1:numETs
                            logger.info('freezingPercentage', ...
                                [identU(1:end-1) ' ' num2str(c) ...
                                ', session ' num2str(s) ', event type ' ...
                                num2str(t) ': A bucket size of ' ...
                                num2str(bs) ' has been chosen.']);
                        end
                    end
                end
            end
        end
    end
    
    maxBucketSize = max(bucketSizes(:));
    
    buckets = zeros(numClasses, numSessions, maxNumBuckets, ...
        maxBucketSize * maxNumRecsPerCS);
    % Support of individual elements.
    bucketsSup = zeros(numClasses, numSessions, maxNumBuckets);
    % Event type of the buckets.
    bucketST = -1 * ones(numClasses, numSessions, maxNumBuckets);
             
    for c = 1:numClasses
        cInds = classInds{1, c};
        for s = 1:numSessions
            sInds = cInds([recs(cInds).session] == s);
            
            % The first recording determines the bucket ordering.
            setBucketOrdering = true;
            
            dispWarn = false;
            
            for r = sInds
                assert(recs(r).(ident(1:end-1)) == c && ...
                    recs(r).session == s);
                
                behavior = behaviorInterface{1, r};
                
                % Index of current bucket (one per event type).
                bcInds = zeros(1, numETs);
                % How many elements are already in the bucket.
                bcFill = zeros(1, numETs);
                
                % Note, an additional complexity here is, that we only
                % expect that all recordings per class/session have the
                % same number of events/event types per recording. However,
                % they may have different orderings, in which case we want
                % to produce a warning and order the events as for the
                % first recording of this class/session.
                bcIndsTmp = zeros(1, numETs);
                bucketListTmp = -1 * ones(1, maxNumBuckets);
                
                events = recs(r).events;
                for ss = 1:length(events.onset)
                    t = find(ismember(props.eventTypes, ...
                        events.type(ss)), 1);
                    
                    bcI = bcInds(t);
                                        
                    if setBucketOrdering
                        % Current bucket full or no bucket yet.
                        if bcFill(t) == 0
                            bcInds(t) = max(bcInds(:)) + 1;
                            bcI = bcInds(t);

                            bucketST(c,s,bcI) = t;
                            bucketListTmp(bcI) = t;
                        end
                    else                         
                        % Current bucket full or no bucket yet.
                        if bcFill(t) == 0
                            % Take the index of the next bocket from the
                            % already set bucket list.
                            tInds = find(bucketST(c,s,:) == t);
                            tInd = find(tInds > bcInds(t), 1);
                            bcInds(t) = tInds(tInd);
                            bcI = bcInds(t);
                            assert(bucketST(c,s,bcI) == t);

                            % How would the bucket list look like, if we
                            % would calculate it as for the first
                            % recording?
                            bcIndsTmp(t) = max(bcIndsTmp(:)) + 1;
                            bcITmp = bcIndsTmp(t);
                            bucketListTmp(bcITmp) = t;
                        end
                    end
                    
                    bcSize = bucketSizes(c,s,t);
                    bcFill(t) = mod(bcFill(t) + 1, bcSize);
                    
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

                    bucketsSup(c, s, bcI) = bucketsSup(c, s, bcI) + 1;
                    i = bucketsSup(c, s, bcI);
                    
                    buckets(c, s, bcI, i) = fprob;
                end
                % All used buckets should have been completely filled.
                assert(all(bcFill == 0));
                
                setBucketOrdering = false;
                
                
                if ~dispWarn && ...
                        any(bucketListTmp ~= squeeze(bucketST(c,s,:)).')
                    logger.warn('freezingPercentage', ...
                        [identU(1:end-1) ' ' num2str(c) ', session '...
                        num2str(s) ': Recordings have different event ' ...
                        'designs.']);
                    dispWarn = true;
                end
            end
        end
    end
    
    % Now we can compute bucket means and stds by incorporating the actual
    % support. Note, that we don't distinguish between freezing
    % probabilities coming from the same animals and those coming from
    % other recording in the same class/session.
    bucketMean = zeros(numClasses, numSessions, maxNumBuckets);
    bucketStd = zeros(numClasses, numSessions, maxNumBuckets);
    
    for c = 1:numClasses
        cInds = classInds{1, c};
        for s = 1:numSessions
            % If animals are shocked in the current session, then we
            % ignore the results of the whole session.    
            cshocks = [recs(cInds([recs(cInds).session] == s)).shocks];
            if ~isempty(cshocks) && ~isempty([cshocks.onset])
                bucketMean(c,s,:) = NaN;
                bucketStd(c,s,:) = NaN;
                bucketST(c,s,:) = -1;
                
                logger.info('freezingPercentage', ['Freezing ' ...
                    'behavior of ' ident(1:end-1) ' ' num2str(c) ...
                    ' in session ' num2str(s) ' is ignored due to ' ...
                    'induced shocks.']);
                
                continue;
            end
            
            for b = 1:maxNumBuckets
                support = bucketsSup(c, s, b);
                
                bucketMean(c,s,b) = mean(buckets(c, s, b, 1:support));
                bucketStd(c,s,b) = std(buckets(c, s, b, 1:support));
            end
        end
    end
    
    % FIXME we cannot assign individual colors to bars in a bar plot (at
    % least if they are clustered). So instead, we need to make sure that
    % all sessions have the same order of buckets (according to their event
    % type.
    
    % Find the session with the fewest number of -1 (most buckets).
    % This one will be used as default permutation of buckets.
    numInvalid = sum((bucketST(:,:,:) == -1),3);
    [~, sind] = min(numInvalid(:));
    [cPer,sPer] = ind2sub(size(numInvalid), sind);
    
    permutation = squeeze(bucketST(cPer, sPer, :));
    % At least one bucket list must be filled completely.
    assert(~any(permutation == -1)); 
    
    % This arrays would be invalid after this, loop.
    buckets = -1;
    bucketsSup = -1;
    
    for c = 1:numClasses
        for s = 1:numSessions
            curPer = bucketST(c, s, :);
            
            for t = 1:numETs
                if sum(curPer == t) > sum(permutation == t)
                    % This error means, that we could not sort all
                    % sessions, such that the buckets match permutation.
                    logger.error('freezingPercentage', ...
                        ['Could not resolve ordering of buckets. ' ...
                        'Aborting function.']);
                    return;                    
                end
            end
            
            % Now we know, that we can in principle order the buckets.
            newBucketST = -1 * ones(1, maxNumBuckets);
            newBucketMean = zeros(1, maxNumBuckets);
            newBucketStd = zeros(1, maxNumBuckets);
            
            for i = 1:maxNumBuckets
                currST = permutation(i);
                
                if currST == -1
                    % Actually, a -1 here is not possible.
                    % So, this test can be deleted.
                    assert(false);
                    break;
                end
                
                hasPlaced = false;
                for j=1:maxNumBuckets
                    if curPer(j) == currST
                        % We don't wanna consider that again.
                        curPer(j) = -1; 
                        hasPlaced = true;
                        
                        newBucketST(i) = currST;
                        newBucketMean(i) = bucketMean(c,s,j);
                        newBucketStd(i) = bucketStd(c,s,j);
                        
                        break;
                    end
                end
                
                if ~hasPlaced
                    newBucketST(i) = -1;
                end
            end
            
            if any(newBucketST ~= squeeze(bucketST(c, s, :)).')
                logger.error('freezingPercentage', ...
                    ['Permutation of  ' ident(1:end-1) ' ' num2str(c) ...
                    ' in session ' num2str(s) ' had to be changed ' ...
                    'in order to plot the results.']);
            end
            
            newBucketMean(newBucketST == -1) = NaN;
            newBucketStd(newBucketST == -1) = NaN;
            
            bucketST(c,s,:) = newBucketST;
            bucketMean(c,s,:) = newBucketMean;
            bucketStd(c,s,:) = newBucketStd;
        end
    end
    
    % Correction to plot actual percentage values.
    bucketMean = bucketMean * 100;
    bucketStd = bucketStd * 100;
    
    % Now we can plot the final results with a fixed coloring per session.
    nr = ceil(numClasses / 2);
    nc = 2;
    cp = 1;
    
    fig = figure('Name', ['Freezing Percentages of ' ident], ...
        'Position',[100 100 1200 300]);
        
    for c = 1:numClasses
        subplot(nr, nc, cp);
        cp = cp + 1;
        
        mean_data = squeeze(bucketMean(c, :, :));
        std_data = squeeze(bucketStd(c, :, :));

        cols = linspecer(numETs);

        b = barwitherr(std_data, mean_data);

        for i = 1:maxNumBuckets
            st = permutation(i);
            b(i).FaceColor = cols(st,:);       
        end

        xlabel('Days')
        ylabel('% Freezing')
        set(gca,'FontSize',16)
        
        ylim([0,100])
        xlim([0 numSessions+1])
        
        [occuringSTs, stInds, ~] = unique(permutation);
        legendB = b(stInds);
        legendN = props.eventTypes(occuringSTs);
        
        legend(legendB, legendN, 'Location','northwest');
        title([identU(1:end-1) ': ' num2str(c)]);
        
        logger.info('freezingPercentage', [identU(1:end-1) ' ' ...
            num2str(c) ': The following mean values for freezing ' ...
            'percentages of sessions have been computed: ' ...
            mat2str(mean_data)]);
        logger.info('freezingPercentage', [identU(1:end-1) ' ' ...
            num2str(c) ': The following std values for freezing ' ...
            'percentages of sessions have been computed: ' ...
            mat2str(std_data)]);
    end  
    
    fpPath = fullfile(p.resultDir, ['frzPerc_' identU]);
    saveas(fig, [fpPath '.png']);
    savefig(fig, [fpPath '.fig']);
end

