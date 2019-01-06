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
@title           :readDesign.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/01/2018
@version         :1.0

Read the properties and subjects (needed for this recording) from the
user-specified design file.
%}

function dataObj = readDesign(dataObj)
%READDESIGN Read the design file.
    logger = log4m.getLogger();

    p = dataObj.p;
    d = dataObj.d;

    try
        designIter = DesignIterator(p.designDir);
    catch
        errMsg = ['Could not read design file from directory ', ...
            p.designDir];
        myError('readDesign', errMsg);
    end

    d.properties = designIter.getProperties();
    d.subjects = cell(1, d.numRecs);
    d.duration = -1;
    
    for i = 1:d.numRecs
        c = p.cohort(i);
        g = p.group(i);
        s = p.session(i);
        m = p.subject(i);
        
        try
            recording = designIter.getRecordings(c, g, s, m);
            assert(length(recording) == 1);
        catch
            errMsg = ['Recording ' num2str(i) ' does not exist in ' ...
                'design (Cohort: ' num2str(c) ', Group: ' num2str(g) ...
                ', Session: ' num2str(s) ', Subject: ' num2str(m) ').'];
            myError('readDesign', errMsg);
        end

        cName = recording.identNames{1};
        gName = recording.identNames{2};
        sName = recording.identNames{3};
        mName = recording.identNames{4};
        
        logger.info('readDesign', ['Recording ' num2str(i) ' will be ' ...
            ' from cohort ' num2str(c) ' (name: ' cName '), group ' ...
            num2str(g) ' (name: ' gName '), session ' num2str(s) ...
            ' (name: ' sName '), subject ' num2str(m) ' (name: ' mName ...
            ').']);
        
        subject = RecordingDesign(recording.recording, d.properties, ...
                recording.ident, p.designDir);
        
        if i == 1
            d.duration = subject.getDuration();
        elseif d.duration ~= subject.getDuration()
            myError('readDesign', 'Durations of recordings differ.');
        end
                   
        d.subjects{i} = subject;
    end

    dataObj.d = d;
end