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
@title           :bin2matOutput.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/03/2018
@version         :1.0
%}

function bin2matOutput(session)
%BIN2MATOUTPUT Translate the binary input file into a mat-file.
%   BIN2MATINPUT(session
	p = session.UserData.p;
    d = session.UserData.d;
    
    logger = log4m.getLogger();
    
    for i = 1:d.numRecs
        sourceFN = d.tempOutputFileNames{i};
        targetFN = fullfile(d.expDir{i}, 'output_data.mat');
        
        numOutputChannels = size(p.triggerChannel, 2) + ...
            size(p.shockChannel, 2) + size(p.soundChannel, 2) + ...
            size(p.soundEventChannel, 2) + size(p.digitalChannel, 2) + ...
            size(p.analogChannel, 2);

        try
            fid = fopen(sourceFN,'r');
            raw = fread(fid, [numOutputChannels, inf], 'double');
            fclose(fid);
        catch
            logger.error('bin2matOutput', ...
                ['Could not read binary file: ' sourceFN]);
            return;
        end
        
        offset = 1;
        triggerData = raw(offset:offset+size(p.triggerChannel, 2)-1,:);
        offset = offset + size(p.triggerChannel, 2);
        shockData = raw(offset:offset+size(p.shockChannel, 2)-1,:);
        offset = offset + size(p.shockChannel, 2);
        soundData = [];
        if ~p.useSoundCard
            soundData = raw(offset:offset+size(p.soundChannel, 2)-1,:);
            offset = offset + size(p.soundChannel, 2);
        end
        seventData = raw(offset:offset+size(p.soundEventChannel, 2)-1,:);
        offset = offset + size(p.soundEventChannel, 2);
        digitalData = raw(offset:offset+size(p.digitalChannel, 2)-1,:);
        offset = offset + size(p.digitalChannel, 2);
        analogData = raw(offset:offset+size(p.analogChannel, 2)-1,:);
        %offset = offset + size(p.analogChannel, 2);

        save(targetFN, 'triggerData', 'shockData', 'soundData', ...
            'seventData', 'digitalData', 'analogData', '-v7.3');
    
        logger.info('bin2matOutput', ['Output channel data of ' ...
            'recording ' num2str(i) ' is stored in ' targetFN '.']);
        
        delete(sourceFN);
    end
end
