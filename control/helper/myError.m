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
@title           :myError.m
@author          :ch
@contact         :christian@ini.ethz.ch
@created         :02/01/2018
@version         :1.0

An error function wrapper.
%}
function myError(errSrc, errMsg)
%MYERROR An wrapper of the error function that logs the message before
%throwing the error.
    global errorOccurredDuringSession;
    errorOccurredDuringSession = 1;

    logger = log4m.getLogger();

    logger.fatal(errSrc, errMsg);
    error(errMsg);
end

