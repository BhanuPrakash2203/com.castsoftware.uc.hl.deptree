package framework::dataType;
use strict;
use warnings;



################# FIELDS NAMES FOR detections DESCRIPTION ###################
our $NAME = 'name';
our $MIN_VERSION = 'min';
our $MAX_VERSION = 'max';
our $TYPE = 'type';
our $DESCRIPTION = 'description';
our $EDITOR = 'editor';
our $VENDOR = 'vendor';
our $LICENSE = 'license';
our $LICENSE_INFO = 'license info';
our $SELECTORS = 'selectors';
our $RELATED = 'related';
our $TARGET ='target';
our $VIEW = 'view';
our $ENVIRONMENT = 'environment';
our $PATTERNS = "patterns";
our $OPTIONS = "options";
our $MATCHED_PATTERN = 'pattern';
our $ITEM = 'item';
our $EXPORTABLE = 'exportable';
our $STATUS = 'analyzer_status';
our $ARTIFACT = "artifact";

our $MODULE = "module";
our $VERSION_MODULE = "module_version";


################ DATA TO BE OUTPUTED IN RESULTS #####################
our @RESULTS_FIELDS = ($MIN_VERSION, $MAX_VERSION, $MODULE, $VERSION_MODULE, $TYPE, $ENVIRONMENT, $MATCHED_PATTERN, $DESCRIPTION, $EDITOR, $LICENSE, $STATUS, $ARTIFACT);

# By default, patterns are to be searched into the source code !
our $DEFAULT_ENVIRONMENT = 'code';
our $STATUS_TBC = 'TBC';
our $STATUS_DISCOVERED = 'discovered';

#***********************************************************************
#******************* PATTERNS DATABASE  ********************************
#***********************************************************************

################## ITEM'S DATA IN PATTERN DB #####################

# INDEX FOR ITEM'S DATA IN PATTERN DB.
our $IDX_NAME = 0;
our $IDX_SELECTORS = 1;
our $IDX_PATTERNS = 2;
our $IDX_MIN = 3;
our $IDX_MAX = 4;
our $IDX_OPTIONS = 5;
our $IDX_ITEM = 6;
our $IDX_EXPORTABLE = 7;

# DATA ORDER IN ITEM'S DATA IN PATTERN DB (should be coherent with $IDX_xxxxx variables above).
our @ITEM_FIELDS = ($NAME, $SELECTORS, $PATTERNS, $MIN_VERSION, $MAX_VERSION, $OPTIONS, $ITEM, $EXPORTABLE);

# TYPE OF ITEM'S DATA IN PATTERN DB. (default is scalar !!)
our %ITEM_FIELD_TYPE = (
	$SELECTORS => ['ARRAY', ','],
	# seprator for PATTERNS is § because the char won't be used (unless bad luck) in language pattern nor regular expr ... 
	$PATTERNS => ['ARRAY', '§'],
);

#***********************************************************************
#******************* DESCRIPTIONS DATABASE *****************************
#***********************************************************************

# INDEX FOR ITEM'S DATA IN DESCRIPTION DB.
our $IDX_DESCR_EDITOR = 0;
our $IDX_DESCR_VENDOR = 1;
our $IDX_DESCR_LICENSE = 2;
our $IDX_DESCR_LICENSE_INFO = 3;
our $IDX_DESCR_DESCRIPTION = 4;
our $IDX_DESCR_TYPE = 5;

our %DESCRIPTION_FIELD_INDEX = (
	$EDITOR => $IDX_DESCR_EDITOR,
	$VENDOR => $IDX_DESCR_VENDOR,
	$LICENSE => $IDX_DESCR_LICENSE,
	$LICENSE_INFO => $IDX_DESCR_LICENSE_INFO,
	$DESCRIPTION => $IDX_DESCR_DESCRIPTION,
	$TYPE => $IDX_DESCR_TYPE,
);

# DATA ORDER IN ITEM'S DATA IN DESCRIPTION DB (should be coherent with $IDX_DESCR_xxxxx variables above).
our @ITEM_DESCR_FIELDS = ($EDITOR, $VENDOR, $LICENSE, $LICENSE_INFO, $DESCRIPTION, $TYPE);

1;
