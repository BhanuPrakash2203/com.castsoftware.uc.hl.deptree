package Clojure::Config;

use strict;
use warnings;

# the first statistic threshold in the model is 3? But this is only a statistic consideration.
# Nevertheless, the rule on github https://github.com/bbatsov/clojure-style-guide#function-length
# say "Avoid functions longer than 10 LOC (lines of code). Ideally, most functions will be shorter than 5 LOC."
# so we fix the violation threshold to the ideal LOC given in the rule. 
use constant LONG_METHOD_THRESHOLD => 5;

# The rule : https://github.com/bbatsov/clojure-style-guide#function-positional-parameters-limit
# The theoretical threshold is 3 and the statistic threshold is 3 too. So all is alrigth ! 
use constant TOO_MANY_PARAMETERS_THRESHOLD => 3;

# The rule is based on the metric Nbr_VariableNameLengthAverage.
# The alert formula is 20-Nbr_VariableNameLengthAverage.
# the first statistic threshold, below whom a violation is detected is 18
use constant VARIABLE_LENGTH_THRESHOLD => 18;

# Statistic first threshold is 2. This is low, yes ... I'm agree ...
# so set threshold to the second threshold, whose value is 3.
use constant DEEP_ARTIFACT_THRESHOLD => 3;

1;
