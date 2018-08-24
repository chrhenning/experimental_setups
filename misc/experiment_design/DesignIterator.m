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
@title           :DesignIterator.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/15/2018
@version         :1.0

An interface that allows easy iteration through a design file.
%}
classdef DesignIterator
    %DESIGNITERATOR This class provides an interface to easily interact 
    %with design files.
    %   The class opens a design file (expecting the file to be in the
    %   correct format). It provides getters that allow easy access to
    %   single recordings.
    
    properties (Access = private)
        % The properties field in the experiment struct.
        Properties
        % A cell array, translating identifier (cohort, group, session,
        % subject) to a recording design.
        Recordings
        % Total number of recordings.
        NumRecs
        NumCohorts
        % The tree doesn't have to be symmetric, so we need a special
        % mapping from linear indices to actual inds in Recordings (which
        % may contain empty cells).
        LinearInds
    end
    
    methods (Access = public)
        function obj = DesignIterator(designDir)
            %DESIGNITERATOR Construct an instance of this class.
            %   obj = DESIGNITERATOR(designDir) The parameter designDir is
            %   expected to be the path to the design folder.
            
            designFile = fullfile(designDir, 'experiment.mat');
            
            if exist(designDir, 'file') ~= 7 || ...
                    exist(designFile, 'file') ~= 2
                errMsg = ['Design file ', designFile, ' does not exist.'];
                error(errMsg);
            end
            
            load(designFile, 'experiment');
            obj.Properties = experiment.properties;
            cohorts = experiment.design.cohorts;
            
            obj = obj.readRecordings(cohorts);
        end
        
        function numRecs = numberOfRecordings(obj)
            %NUMBEROFRECORDINGS Returns the number of recordings contained
            %in the design.
            numRecs = obj.NumRecs;
        end       
        
        function [recording, ident, identNames] = get(obj, ind)
            %GET Returns the recording with index ind.
            %
            %   [recording, ident, identNames] = GET(obj, ind) Returns the
            %   'recording' as a struct, an unique identifier ident (an 1x4
            %   array determining cohort, group, session, subject) and the
            %   name identifiers (names of cohort, group, session,
            %   subject).
            i = obj.LinearInds(ind);
            [c, g, s, m] = ind2sub(size(obj.Recordings), i);
            
            recording = obj.Recordings{c,g,s,m}{1};
            ident = [c, g, s, m];
            identNames = obj.Recordings{c,g,s,m}{2};
        end
        
        function properties = getProperties(obj)
            %GETPROPERTIES Returns the properties struct from the design
            %file.
            properties = obj.Properties; 
        end
        
        function ind = toLinearIndex(obj, cohort, group, session, subject)
            %TOLINEARINDEX Translate an recording identifier to its linear
            %index, such that one can acquire it via the get method.
            i = sub2ind(size(obj.Recordings), cohort, group, session, ...
                subject);
            ind = find(obj.LinearInds == i, 1);
        end
        
        function recordings = getRecordings(obj, cohort, group, ...
                session, subject)
            %GETRECORDINGS A getter method for one or multiple recordings.
            %
            %   This method can return recordings identified by cohort,
            %   group, session, subject, which may be single indices or
            %   arrays of indices. If one of these identifiers is -1, then
            %   all possible indices for this specific identifier are
            %   assumed.
            %
            %   Returns:
            %   Returns a structured array. Each element has the three
            %   fields: 'recording', 'ident' and 'identNames'. Please refer
            %   to the documentation of the get method to get a description
            %   of these fields.
            %
            %   Examples:
            %   recordings = obj.getRecordings(2, 1, 3, 5);
            %   recordings = obj.getRecordings(2, 1, 3, -1);
            %   recordings = obj.getRecordings(-1, 1, 3, [1, 2]);
            C = cohort; 
            G = group; 
            S = session; 
            M = subject;

            if C == -1
                C = 1:1:size(obj.Recordings, 1);
            end
            if G == -1
                G = 1:1:size(obj.Recordings, 2);
            end
            if S == -1
                S = 1:1:size(obj.Recordings, 3);
            end
            if M == -1
                M = 1:1:size(obj.Recordings, 4);
            end
            
            recordings = struct([]);
            ind = 1;
            for c = C
                for g = G
                    for s = S
                        for m = M
                            if isempty(obj.Recordings{c, g, s, m})
                                continue
                            end
                            
                            recordings(ind).recording = ...
                                obj.Recordings{c,g,s,m}{1};
                            recordings(ind).ident = [c, g, s, m];
                            recordings(ind).identNames = ...
                                obj.Recordings{c,g,s,m}{2};
                            
                            ind = ind + 1;
                        end
                    end
                end
            end
        end
        
        function [ncohorts, ngroups, nsessions, nsubjects] = ...
                maxDesignDims(obj)
            %MAXDESIGNDIMS Maximum size per class.
            %
            %   For example, ncohorts is simply the number of cohorts in
            %   the design. ngroups is the number of groups in the cohort
            %   where this number is maximized (note, that the design tree
            %   does not have to be symmetric).
            [ncohorts, ngroups, nsessions, nsubjects] = ...
                size(obj.Recordings);
        end
        
        function ncohorts = getNumCohorts(obj)
            %GETNUMCOHORTS Returns the number of cohorts.
            ncohorts = obj.NumCohorts;
        end
        
        function ngroups = getNumGroups(obj, cohort)
            %GETNUMGROUPS Returns the number of groups in a cohort.
            ngroups = 0;
            
            for i = 1:size(obj.Recordings, 2)
                r = obj.Recordings{cohort, i, :, :};
                for j = 1:numel(r)
                    if ~isempty(r(j))
                        ngroups = ngroups + 1;
                        break;
                    end
                end
            end
        end
        
        function nsessions = getNumSessions(obj, cohort, group)
            %GETNUMGROUPS Returns the number of sessions in a cohort and
            %group.
            nsessions = 0;
            
            for i = 1:size(obj.Recordings, 3)
                r = obj.Recordings{cohort, group, i, :};
                for j = 1:numel(r)
                    if ~isempty(r(j))
                        nsessions = nsessions + 1;
                        break;
                    end
                end
            end
        end
        
        function nsubjects = getNumSubjects(obj, cohort, group, session)
            %GETNUMGROUPS Returns the number of subjects in a cohort,
            %group and session.
            nsubjects = 0;
            
            for i = 1:size(obj.Recordings, 4)
                if ~isempty(obj.Recordings{cohort, group, session, i})
                    nsubjects = nsubjects + 1;
                end
            end
        end
    end
    
    methods (Access = private)
        function obj = readRecordings(obj, cohorts)
            %readRecordings This method will mainly fill the Recordings 
            % property.
            %
            %   It will also set the properties NumRecs, NumCohorts and
            %   LinearInds.
            
            % @Developers: The original designfile allows multinodes to
            % ensure memory efficiency (e.g., if large arrays are stored
            % directly in the design file). Here, every element og
            % obj.Recordings has its own copy of the design (as matlab does
            % not allow references). This is very memory inefficient. On
            % the other hand, users should always store large arrays in
            % external files.
            
            obj.NumCohorts = numNodesInLevel(cohorts);
            
            % Find out the maximum number of elements per level.
            maxNumPerLevel = zeros(1, 4);
            
            currLevel = {cohorts};
            
            idents = {'groups', 'sessions', 'subjects'};
                
            for i = 1:4
                nextLevel = {};

                for j = 1:length(currLevel)
                    node = currLevel{j};
                    
                    num = numNodesInLevel(node);

                    if num > maxNumPerLevel(i)
                        maxNumPerLevel(i) = num;
                    end
                        
                    if i == 4
                        continue
                    end

                    for k = 1:length(node)
                        children = node(k).(idents{i});
                        nextLevel{1+numel(nextLevel)} = children;
                    end
                end
                
                currLevel = nextLevel;     
            end
            assert(maxNumPerLevel(1) == obj.NumCohorts);
            
            % Now we can initialize the cell array that maps to our
            % recordings.
            obj.Recordings = cell(maxNumPerLevel);
            
            % Traverse through the whole tree once to fill Recordings.
            numRecs = 0;
            for c = 1:obj.NumCohorts
                [cohort, cname] = getChild(cohorts, c);
                groups = cohort.groups;
                nGroups = numNodesInLevel(groups);
                
                for g = 1:nGroups
                    [group, gname] = getChild(groups, g);
                    sessions = group.sessions;
                    nSessions = numNodesInLevel(sessions);
                    
                    for s = 1:nSessions
                        [session, sname] = getChild(sessions, s);
                        subjects = session.subjects;
                        nSubjects = numNodesInLevel(subjects);
                        
                        for m = 1:nSubjects
                            [subject, mname] = getChild(subjects, m);
                            identNames = {cname, gname, sname, mname};
                            
                            obj.Recordings{c,g,s,m} = {subject, ...
                                identNames};
                            
                            numRecs = numRecs + 1;
                        end
                    end
                end
            end
                        
            obj.NumRecs = numRecs;
            
            % Recordings may have empty cells (tree doesn't have to be
            % symmetric). Map numbers from 1 to numRecs to indices of
            % non-empty cells from 1:prod(size(obj.Recordings))
            obj.LinearInds = zeros(1, numRecs);
            ind = 1;
            for i = 1:numRecs
                while isempty(obj.Recordings{ind})
                    ind = ind + 1;
                end
                
                obj.LinearInds(i) = ind;
                
                ind = ind + 1;
            end
        end
    end
    
    methods (Static)
        function dirName = getRelFolder(cohort, group, session, subject)
            %GETRELFOLDER Return the relative folder name of the associated
            %identifier.            
            dirName = fullfile(['cohort' num2str(cohort)], ...
                ['group' num2str(group)], ...
                ['session' num2str(session)], ...
                ['subject' num2str(subject)]); 
        end
    end
end

function numChildren = numNodesInLevel(multinode)
    %NUMNODESINLEVEL The number of children to a given tree node.
    %
    %   This method simply counts the number of names per struct.
    numChildren = 0;
    for j = 1:length(multinode)
        numChildren = numChildren + numel(multinode(j).names);
    end
end

function [child, name] = getChild(multinode, index)
    %GETCHILD The design file is structured as a special tree, where each
    %node can represent several nodes (by having multiple names).
    %
    %   E.g., if the first node has 3 element and the second has 2, then 
    %   the indices [1,2,3] are associated with the first node and the 
    %   indices [4,5] are associated with the second one.
    %
    %   The design file tree has this nodes in several stages (cohorts, 
    %   groups, sessions, subjects). In the above example, if the user 
    %   queries the 5th "node", then we want to return the second node with 
    %   the second name associated with that node.
    found = 0;

    currI = index;
    for j = 1:length(multinode)
        if currI <= length(multinode(j).names)
            child = multinode(j);
            name = child.names{currI};
            found = 1;
            break
        else
            currI = currI - length(multinode(j).names);
        end
    end
    
    % TODO better error message (what is wrong: cohort, subject, ...?)
    if ~found
        error('Design file element does not exist.');
    end
end

