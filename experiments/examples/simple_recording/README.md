# A Recording with no Stimuli defined in the Design File

Even though the software is specifically designed for fear conditioning and active avoidance setups, it can be used for a whole range of experiments.

A simple experiment would be an experiment, that doesn't need any stimuli and just passively records the behavior of the subject (e.g., the social behavior). The recording itself is not managed by the design file, but by the `params.m` file of the *control* software (such as camera configs and triggers). Hence, the design file only specifies the structure of the experiment (number of cohorts, number of subjects per session, ...), but does not define any stimuli that are presented during a recording.

Starting from this script, you can add arbitrary analog and digital events to enrich your design and customize the behavior of the control software to work with your setup.
