# TODOs

## General
* Script to measure chamber illumination (such that we can configure all chambers to have approximately the same illumination).
* It is a bit weird that all arrays are typically size 1 x n except for sounds (n x 1 or n x 2).

## Setup Control
* Add plots, that show output design of all channels.
* Allow cancelling the recording while it is running (delete cameras, reset nidaq, write 0 to all used NIDAQ channels).
* Replace assertions by meaningful error messages.
* Add more visualizations (feedback) during a recording (e.g., state if an event is pushed to the NIDQAQ). TODO, what to do, during bulkmode? -> Solution, decouple output from data pushed to the NIDAQ (just use the NIDQQ start time timestamp to align events from the design file with the OS time) 
* Add a few example `params.m` files.

## Evaluation
* For memory efficiency, traces are currently stored as event lists. However, to extract information from them we convert them to binary traces over time. Instead, we should add function that allows to condition and compare event-lists.
* The timing correction for recorded sounds doesn't work robustly if the sampling rates for sound and NIDAQ are very different.
* If someone wants to have a more general evaluation structure, then he should allow user to specify other US sources (e.g., digital or analog events). In such a case, we should distinguish between csEvents and usEvents. Or we have events in general, and "US" is just an event type.
* Provide an interface that translates durations (in seconds) to num steps.


## Design file
* One could redo it from scratch, where the design itself is decomposed into objects (shocks (inherited from digital events), sounds (inherited from analog events), analog and digital itself inherited from events ...), that can be serialized and written to a file.
* Write a GUI that visualizes an experimental design (plot single subject designs, play tones, ...).
* Maybe we write some classes that give an interface to read and manipulate designs, this could be used to create designs, control them and to evaluate an experiment.
* Enrich the method `getRelFolder` of class `DesignIterator`, such that singletons are not part of the path (e.g., an experiment that only contains a single cohort, doesn't need *Cohort1* in its path). How to ensure downwards compatibility? We could check whether the `p.rootDir` already exists and what path is used there? Note, that an auto-generated design would still require the full path.

## Postprocessing
* There should be a common postprocessing for all recordings independent of the experiment type. Possible tasks are listed below. The goal is, that the user doesn't have to care about recording issues when evaluating the data
* Correct sound onset timing if sound card has been used
* Handle dropped camera frames
* If miniscope recording has been triggered via NIDAQ, then align all timestamps
