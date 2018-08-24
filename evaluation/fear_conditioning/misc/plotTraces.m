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
@title           :plotTraces.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :01/12/2018
@version         :1.0

Plot the traces for individual recordings.
%}

function plotTraces(p, recordings, recInd, tData, freezingTrace, ...
    shockTrace, eventTraces)
%PLOTTRACES Plot the traces in a single figure for the given recording.
%   
%   Figures will be stored in individual folders, one for each recording.

    rec = recordings.recs(recInd);
    props = recordings.props;
    
    numETs = length(props.eventTypes);
    shockOnsets = rec.shocks.onset;

    % To plot the binary traces, we need to change their y-values and
    % remove the zeros (which should not be plotted).
    pevents = eventTraces(:, :);
    pshocks = shockTrace(:, :);
    pfrezs = freezingTrace(:, :);
    
    yOffset = 1;
    pfrezs(freezingTrace == 1) = yOffset;
    yOffset = yOffset + 1;
    for ss = 1:numETs
        pevents(ss, eventTraces(ss, :) == 1) = yOffset;
        yOffset = yOffset + 1;
    end
    if ~isempty(shockOnsets)
        pshocks(shockTrace == 1) = yOffset;
        yOffset = yOffset + 1;
    end
    
    pevents(eventTraces == 0) = NaN;
    pshocks(shockTrace == 0) = NaN;
    pfrezs(freezingTrace == 0) = NaN;

    % Create folder for figure.
    traceFigDir = fullfile(p.resultDir, rec.relativeDataFolder);
    if ~isdir(traceFigDir)
        mkdir(traceFigDir);
    end
    traceFigPath = fullfile(traceFigDir, 'traces');

    fig = figure('Name', 'Event / Shocking / Freezing traces', ...
        'visible', 'off');
    
    ticklabels = cell(1, yOffset-1);
    
    cols = linspecer(yOffset-1);
    
    tlo = 1;
    ticklabels{tlo} = 'Freezing';
    plot(tData, pfrezs, 'DisplayName', 'Freezing', 'LineWidth', 5, ...
        'color', cols(tlo, :));
    hold on;

    for ss = 1:numETs
        tlo = tlo + 1;
        et = recordings.props.eventTypes(ss);
        ticklabels{tlo} = char(et);
        plot(tData, pevents(ss, :), 'DisplayName', ...
            ['Event ' char(et)], 'LineWidth', 5, 'color', cols(tlo, :));
    end
    
    if ~isempty(shockOnsets)
        tlo = tlo + 1;
        ticklabels{tlo} = 'Shocks';
        plot(tData, pshocks, 'DisplayName', 'Shocks', 'LineWidth', 5, ...
            'color', cols(tlo, :));
    end
    
    xlabel('Time (in seconds)');
    ylim([0 yOffset]);
    yticks(gca, 1:1:yOffset-1)
    yticklabels(gca, ticklabels)
    
    legend('show');
    
    saveas(fig, [traceFigPath '.png']);
    savefig(fig, [traceFigPath '.fig']);
end

