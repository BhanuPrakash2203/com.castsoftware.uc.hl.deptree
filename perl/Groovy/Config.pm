package Groovy::Config;

use strict;
use warnings;

# set the level from wich a copound condition with at least && and || operator is complex. Used to compute the number of violations.
# WARNING : This value should be update each time the model is tunned. It correspond to the first threshold of the counter Nbr_ConditionComplexityAverage
use constant MAX_CONDITION_COMPLEXITY => 0;

# set the level over which number of lines a case become a violation
# WARNING : this value is to determine the number of case too long and should be tunned according to the stats of the counter Nbr_caseLenghtAverage
use constant CASE_LENGTH_THRESHOLD => 2;

# set the level over which an artifact is too deep.
# This value is independent from the model tunning.
use constant DEPTH_THRESHOLD => 3;

1;
