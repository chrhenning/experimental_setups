# Contributing to the Control Software of our Experimental Setups

First of all (and **most importantly**), we only want to have code contributions that follow basic coding guidelines. There is no specific guideline for this repository chosen yet, the current ones should become pretty obvious when browsing the existing code.

* Lines should be no longer than **80 characters**
* All names (even local variables) must reflect the meaning of its entity
* All methods/functions need a docstring describing its purpose, arguments and return values
* If possible, program object-oriented. Example classes (to compare coding guidelines) are [DesignIterator](misc/experiment_design/DesignIterator.m) and [RecordingDesign](misc/experiment_design/RecordingDesign.m)
* All changes should be well documented

## What can be pushed to the *master* branch?

Only code, that is general for all kinds of supported experimental setups may be pushed to the [control](control) folder. Supported experimental setups are only restricted by the capabilities of a NIDAQ board.

Whenever you have to develope code, that is specific to a certain experiment, you are obligated to **create a new branch**. Otherwise, you would render the software potentially unusable for future experiments.

If you intend to push code specific to a certain experiment type (such as an evaluation pipeline for *active-avoidance* experiments), then you have to make sure, that the code is as general as possible with respect to all possibilities covered by this experimental type (if not possible, documented these cases well). If you cannot go through this effort, you have to develope your program in a separate branch.
