% Copyright 2018 Rik Ubaghs, Christian Henning
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
@title           :bin2matInput.m
@author          :ru, ch
@contact         :christian@ini.ethz.ch
@created         :11/30/2017
@version         :1.0
%}

function bin2matInput(session)
%BIN2MATINPUT Translate the binary input file into a mat-file.
%   BIN2MATINPUT(session
	p = session.UserData.p;
    d = session.UserData.d;
    
    logger = log4m.getLogger();
    
    for i = 1:d.numRecs
        sourceFN = d.tempInputRawFileNames{i};
        if p.useBulkMode
            targetFN = fullfile(d.expDir{i}, 'input_data.mat');
        else
            targetFN = fullfile(d.expDir{i}, 'input_data_raw.mat');
        end
        success = convertData(sourceFN, targetFN, ...
            session.UserData.triggerTime, p);

        if success
            logger.info('bin2matInput', ['Raw time stamps and raw ' ...
                'input channel recordings of recording ' num2str(i) ...
                ' are stored in ' targetFN '.']);
        end
        
        if p.correctRecordedInputs && ~p.useBulkMode
            sourceFN = d.tempInputFileNames{i};
            targetFN = fullfile(d.expDir{i}, 'input_data.mat');
            success = convertData(sourceFN, targetFN, ...
                session.UserData.triggerTime, p);

            if success
                logger.info('bin2matInput', ['Time stamps and input ' ...
                    'channel recordings of recording ' num2str(i) ...
                    ' are stored in ' targetFN '.']);
            end
        end
    end
end

function success = convertData(sourceFN, targetFN, sessionStart, p)
    success = 1;
    
    logger = log4m.getLogger();
    
    try
        fid = fopen(sourceFN, 'r');
        raw = fread(fid, [size(p.inputChannel, 2)+1, inf], 'double');
        fclose(fid);
    catch
        logger.error('bin2matInput', ...
            ['Could not read binary file: ' sourceFN]);
        success = 0;
        return;
    end

    timestamps = raw(1,:);
    inputData = raw(2:size(raw, 1),:);
    timestampOffset = sessionStart;

    save(targetFN, 'timestamps', 'inputData', 'timestampOffset', ...
        '-v7.3');

    delete(sourceFN);
end