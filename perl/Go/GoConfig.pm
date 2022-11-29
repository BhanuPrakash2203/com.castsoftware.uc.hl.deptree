package Go::GoConfig;

use strict;
use warnings;

# constant values for respecting a naming convention
# WARNING : This value should be update each time the model is tunned. 

# Obtained with the average for all reference applications of the average per file of counter Nbr_VariableNameLengthAverage
use constant MIN_VAR_NAME_LENTGH => 5;

# Obtained with the average for all reference applications of the average per file of counter Nbr_FunctionNameLengthAverage
use constant MIN_FUNCTION_NAME_LENTGH => 11;

# Obtained with the average for all reference applications of the average per file of counter Nbr_ParameterNameLengthAverage
use constant MIN_PARAMETERS_NAME_LENTGH => 4;

# Obtained with the average for all reference applications of the average per file of counter Nbr_SwitchLengthAverage
# Nbr_SwitchLengthAverage give the average number of cases over three inside a switch.
# average(Nbr_SwitchLengthAverage) is 4, so average lentgh of switches too long is 7 (4+3) and this is the threshold for violations.
use constant LARGE_SWITCH_LENTGH_THRESHOLD => 7;

1;
