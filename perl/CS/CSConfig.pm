package CS::CSConfig;

use strict;
use warnings;

use Erreurs;


# related to Nbr_AttributeNameLengthAverage => Alt_VariableNameLengthAverage
use constant MIN_ATTRIBUTE_NAME_LENGTH => 10;
# related to Nbr_ClassNameLengthAverage => Alt_ClassNameLengthAverage
use constant MIN_CLASS_NAME_LENGTH => 15;
# related to Nbr_MethodNameLengthAverage => Alt_FunctionNameLengthAverage
use constant MIN_METHOD_NAME_LENGTH => 10;

# related to Nbr_ConditionComplexityAverage => Alt_ComplexConditions
use constant MAX_CONDITION_COMPLEXITY => 2;

# related to Nbr_SwitchLengthAverage => Alt_LargeSwitchCase
use constant MAX_SWITCH_LENGTH => 5;

# related to Nbr_ParametersAverage => Alt_NumberOfParameters
use constant MAX_PARAMETERS => 2;

# related to Nbr_MethodsLengthAverage => Alt_LongArtifact
use constant MAX_METHOD_LENGTH => 13;

# related to Nbr_ArtifactDepthAverage => Alt_DepthCode
use constant MAX_DEPTH_THRESHOLD => 2;

1;
