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
@title           :soundOnsetAccuracy.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/08/2018
@version         :1.0

Evaluate how accurate the operating system scheduled the sounds to the
sound card.
%}

function soundOnsetAccuracy(p, recordings)
%SOUNDONSETACCURACY Evaluate sound onset delays.
%   Sound onset delays are due to 

    if ~p.correctSoundsIfRecorded
        return;
    end
    
    logger = log4m.getLogger();
    logger.info('soundOnsetAccuracy', 'Evaluating sound onset accuracy.');
    
    delays = [];
    
    for i = 1:length(recordings.recs)
        if ~isfield(recordings.recs(i) , 'soundCorrection')
            return
        end
        
        actual_onsets = recordings.recs(i).soundCorrection.actualOnset;
        intended_onsets = recordings.recs(i).soundCorrection.intendedOnset;
        
        delays = [delays, actual_onsets - intended_onsets];
    end
    
    if isempty(delays)
        logger.info('soundOnsetAccuracy', ['No sounds were played via ' ...
            'the soundcard. Nothing to correct!']);
    end
    
    logger.info('soundOnsetAccuracy', ['Sound onset delays have a mean' ...
        ' of ' num2str(mean(delays)) ' sec and a median of ' ...
        num2str(median(delays)) ' sec.']);
    logger.info('soundOnsetAccuracy', ['Sound onset delays have a ' ...
        'skewness of ' num2str(skewness(delays)) ' and a kurtosis of ' ...
        num2str(kurtosis(delays)) '.']);

    boxplotPath = fullfile(p.resultDir, 'sound_onset_delays_boxplot');
    distPath = fullfile(p.resultDir, 'sound_onset_delays_distribution');
    
    fig = figure('Name', 'Boxplot of Sound Onset Delays', ...
        'visible', 'off');
    boxplot(delays)
    ylabel('Sound Onset Delay (in seconds)');
    %boxplot(delays, 'symbol', '') % Without outliers.
    saveas(fig, [boxplotPath '.png']);
    savefig(fig, [boxplotPath '.fig']);
    
    fig = figure('Name', 'Distribution of Sound Onset Delays', ...
        'visible', 'off');
    xData = randn(1, length(delays));
    scatter(xData, delays, [], delays);
    colormap(jet);
    hline = refline([0 mean(delays)]);
    hline.Color = 'k';
    set(gca,'xtick',[])
    ylabel('Sound Onset Delay (in seconds)');
    saveas(fig, [distPath '.png']);
    savefig(fig, [distPath '.fig']);
end

