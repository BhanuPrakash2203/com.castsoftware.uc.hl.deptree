package framework::importExternal;

use strict;
use warnings;

use framework::Logs;
use framework::version;
use framework::dataType;

# ****************** load DB ****************************

my %ITEM_ID = ();

sub getItemID($) {
	my $framework = shift;
	
	if (! exists $ITEM_ID{$framework}) {
		$ITEM_ID{$framework} = 0;
		return 0;
	}
	$ITEM_ID{$framework}++;
	return $ITEM_ID{$framework};
}

my $QUALITY_MAIN = "*";
my $QUALITY_SECOND = "-";
my $ITEM = 'item';
my $ADDITIONAL_PATTERN = "";

my $CODE_OK = 0;
my $CODE_VERSION_INCONSISTENCY = 1;
my $CODE_FILE_IO = 2;
my $CODE_REGEX_ERROR = 3;

sub convertItemFromHashToTab($) {
	my $hash = shift;
	my @tab = ();
	
	for my $field (@framework::dataType::ITEM_FIELDS) {
		
		if (defined $hash->{$field}) {
			push @tab, $hash->{$field};
		}
		else {
			push @tab, undef;
		}
	}

	return \@tab;
}

sub checkPatternSyntax($) {
	my $pattern = shift;
	if (! defined $pattern) {return undef;}
	eval { 1 =~ /$pattern/;};
	if ($@) {
		return $@;
	}
	return undef;
}

sub checkItemDefinition($$) {
	my $item = shift;
	my $line = shift;
	
	# If the environment is 'code', the selector column should indicate the name of the view to be used.
	# By default, the 'code' view will be used.
	if ( ($item->{$framework::dataType::ENVIRONMENT} eq 'code') && (! defined $item->{$framework::dataType::SELECTORS}) ) {
		framework::Logs::Warning("missing selectors (name of the code's view) for item '$item->{$framework::dataType::NAME}' at line $line\n");
		return 0;
	}
	
	return 1;
}

sub store($$$$$) {
	my $H_item = shift;
	my $column = shift;
	my $value = shift;
	my $storingMode = shift;
	my $linecount = shift;
	my $type = ${framework::dataType::ITEM_FIELD_TYPE}{$column}[0];
	my $typeParam = ${framework::dataType::ITEM_FIELD_TYPE}{$column}[1];
	
	# if type of the data is an ARRAY, then add the value, whatever the storung mode is.
	if (( defined $type ) && ( $type eq "ARRAY")) {
		if (! defined $value) {
			# ignore undefined values ...
			return;
		}
		
		# init destination if needed ...
		if (! defined $H_item->{$column}) {
			$H_item->{$column} = [];
		}
		
		my @new_values = split /\s*${typeParam}\s*/, $value;
		push @{$H_item->{$column}}, @new_values;
	}

	# if type of the data is NOT an ARRAY, then assign the value, only if storing mode is "=" !!!
	else {
		if ($storingMode eq "=") {
			$H_item->{$column} = $value;
		}
		elsif ((defined $value) && ($value ne "''")) {
			framework::Logs::Warning("value $value can not be added for column '$column' at line $linecount\n");
		}
	}
	
}

my $STATE_FIELD = 0;
my $STATE_FIELD_STRING = 1;
my $STATE_WAIT_FIELD = 2;
my $STATE_WAIT_SEPARATOR = 3;

sub splitCsvField($;$) {
	my $line = shift;
	my $lineno = shift || '<unknow>';
	
	my @data = split /(;|""|")/, $line;
	
	my @fields = ();
	my $field = "";
	my $state = $STATE_WAIT_FIELD;
	
	for my $item (@data) {
		
		# expecting first non blank character of field
		if ($state == $STATE_WAIT_FIELD) {
			if ($item !~ /\S/) {
				$field = $item;
			}
			elsif ($item eq ';') {
				push @fields, $field;
				$field = "";
			}
			elsif ($item eq '""') {
				push @fields, "";
				$field = "";
				$state = $STATE_WAIT_SEPARATOR;
			}
			elsif ($item eq '"') {
				$field = "";
				$state = $STATE_FIELD_STRING;
			}
			else {
				$field .= $item;
				$state = $STATE_FIELD;
			}
		}
		
		# A quoted field has ended; so expect field separator.
		elsif ($state == $STATE_WAIT_SEPARATOR) {
			if ($item !~ /\S/) {
				next;
			}
			elsif ($item eq ';') {
				push @fields, $field;
				$field = "";
				$state = $STATE_WAIT_FIELD;
			}
			else {
				print "ERROR : encountered $item while expecting \";\" at line $lineno\n";
			}
		}
		
		# inside a normal field.
		elsif ($state == $STATE_FIELD) {
			if ($item eq ';') {
				push @fields, $field;
				$field = "";
				$state = $STATE_WAIT_FIELD;
			}
			else {
				$field .= $item;
			}
		}
		
		# inside a quoted field.
		elsif ($state == $STATE_FIELD_STRING) {
			if ($item eq '"') {
				push @fields, $field;
				$field = "";
				$state = $STATE_WAIT_SEPARATOR;
			}
			elsif ($item eq '""') {
				$field .= '"';
			}
			else {
				$field .= $item;
			}
		}
	}
	
	# check final state ...
	if ($state == $STATE_FIELD) {
		push @fields, $field;
	}
	elsif ($state == $STATE_FIELD_STRING) {
		push @fields, $field;
		print "WARNING : missing ending \" at end of line $lineno\n";
	}
	
	return @fields;
}

sub loadExternalfromCsv($) {
	my $DBFile = shift;
	framework::Logs::printOut "Loading framework DB from $DBFile\n";
	
	my $ret = open DB, "<$DBFile";
	
	if (! defined $ret) {
		framework::Logs::Warning("unable to read $DBFile ($!)\n");
		return (undef, $CODE_FILE_IO);
	}
	
	$/ = undef;
	
	my $buf = <DB>;
	my %H_DB = ();
	
	my $errorcode = $CODE_OK;
	my $techno = undef;
	my @columnNames = ();
	my $H_item = {};
	my $item = undef;
	my $quality = undef;
	my $linecount = 0;
	while ($buf =~ /^(.*)$/mg) {
		my $line = $1;
		$linecount++;
		
		# skip empty lines
		if ($line =~ /^;*$/m) {
			next;
		}
		
		# skip commented lines
		if ($line =~ /^\s*#/m) {
			next;
		}
		
		#my @data = split ';', $line;
		my  @data = splitCsvField($line, $linecount);
		
		#--------------- WORDING LINE --------------
		if (($data[0] eq "techno")) {
			# column name specification
			@columnNames = ();
			shift @data; # first column is the techno (do not memorize this mandatory field) !!
			shift @data; # first column is the quality (do not memorize this mandatory field) !!
			shift @data; # second column is the name of the framework (do not memorize this mandatory field) !!
			
			for my $name (@data) {
				push @columnNames, $name;
			}
		}
		#--------------- DATA LINE -----------------
		else {
			
			# --------------- CHECK TECHNO COLUMN ------------
			$techno = shift @data;
			if ((! defined $techno) || ($techno eq '')) {
				framework::Logs::Warning("missing techno field at line $linecount !!\n");
				last;
			}
			
			# --------------- CHECK QUALITY COLUMN ------------
			# Read the first column.
			# get the quality (main item or not)
			$quality = shift @data;
			if ($quality =~ /^\s*$/) {
				framework::Logs::Warning("item ignored at line $linecount !!\n");
				#$quality = $QUALITY_SECOND;
				next;
			}
			
			# --------------- CHECK NAME COLUMN ------------
			# Read the name column.
			my $name = shift @data;
			
			# --------------- GET OTHERS COLUMNS ... ------------
			my %H_locItem = ();
			for my $column (@columnNames) {
				my $value = shift @data;
					
				if (defined $value) {
					if ($value eq '') {
						$value = undef;
					}
					#else {
					#	$value = "'".$value."'";
					#}
				}
				$H_locItem{$column} = $value;
				
				if ($column eq $framework::dataType::PATTERNS) {
					my $error = checkPatternSyntax($value);
					if ( defined $error ) {
						print "Aborting due to syntax error in pattern regular expression: $value at line $linecount\n";
						print "$error";
						exit $CODE_REGEX_ERROR;
					};
				}
			}
			
			# Check for remaining data ...
			while (scalar @data > 0) {
				if ($data[0] =~ /\S/) {
					# value without column name will be ignored.
					print "[framework] WARNING : data outside column when importing external patterns at line $linecount ($data[0])!!\n";
				}
				shift @data;
			}
			# Get environment
			my $env = $H_locItem{$framework::dataType::ENVIRONMENT};
			if (! defined $env) {
				$env = $framework::dataType::DEFAULT_ENVIRONMENT;
			}
			
			# init the item data.
			$H_item = {};
			
			for my $column (@columnNames) {
				store($H_item, $column, $H_locItem{$column}, "=", $linecount);
			}
			
			store($H_item, $framework::dataType::NAME, $name, "=", $linecount);
		
			# check version
			my $min = framework::version::makeComparable($H_item->{$framework::dataType::MIN_VERSION});
			my $max = framework::version::makeComparable($H_item->{$framework::dataType::MAX_VERSION});
		
			if ((defined $H_item->{$framework::dataType::MIN_VERSION}) && (defined $H_item->{$framework::dataType::MAX_VERSION})) {
				my ($compare, $finest) = framework::version::compareVersion($min, $max);
				if ($compare == -1) {
					print "[framework] ERROR : max can not be less than min at line $linecount\n";
					$errorcode = $CODE_VERSION_INCONSISTENCY;
					$H_item->{$framework::dataType::MIN_VERSION} = undef;
					$H_item->{$framework::dataType::MAX_VERSION} = undef;
				}
			}
		
			# extract "exportable" and "item" value ...
			$quality =~ /^(\*)?(\w+)?/;
			# the item is exportable if $quality begins with "*"
			$H_item->{$framework::dataType::EXPORTABLE} = (defined $1 ? 1:0) ;
			
			my $item = $2;
			if (! defined $item) {
				# generate an automatic item value ...
				my $ID = getItemID($name);
				$item = "$name#$ID" ;
			}
			
			#if (checkItemDefinition($H_item, $linecount)) {
            # record even if check has failed (consider checking issues only warnings )
			checkItemDefinition($H_item, $linecount);
				# record data related to the item ...
				#$H_DB{$techno}->{$env}->{'PATTERNS'}->{$quality}->{$item} = $H_item;
				$H_DB{$techno}->{$env}->{'PATTERNS'}->{$item} = $H_item;
			
			
			
				# FIXME : should be removed.
				# if item is a "MAIN ITEM", then add it to the list ...
				if ($quality eq $QUALITY_MAIN) {
					push @{$H_DB{$techno}->{$env}->{'MAIN_ITEMS'}}, $item;
				}
			#}
		}
	}

	close DB;
	return (\%H_DB, $errorcode);
}

# Merge external patterns for a given technologie.
sub mergeExternal($$) {
	my $DB = shift;
	my $DB_ext = shift;

	framework::Logs::Debug("merging from external ...\n");
	
	for my $env (keys %$DB_ext) {
		
		if (! exists $DB->{$env}) {
			# create this pattern search environment.
			$DB->{$env} = { 'MAIN_ITEMS' => [], 'PATTERNS' => {}};
		}
		
#		my $MAIN_ITEMS     = $DB    ->{$env}->{'MAIN_ITEMS'};
#		my $MAIN_ITEMS_ext = $DB_ext->{$env}->{'MAIN_ITEMS'};
		
		my $PATTERNS     = $DB    ->{$env}->{'PATTERNS'};
		my $PATTERNS_ext = $DB_ext->{$env}->{'PATTERNS'};
		
#		for my $item (@$MAIN_ITEMS_ext) {
#			framework::Logs::Debug("merging $item from external\n");
#			# if an external "main item" do not exist in the data base, then record it as a new "main item".
#			if (!exists $PATTERNS->{$item}) {
#				push @{$MAIN_ITEMS}, $item;
#			}
#		}

		for my $item (keys %{$PATTERNS_ext}) {
			# if an external "item" do not exist in the data base, then record it as a new "item", with its associated patterns.
			if (!exists $PATTERNS->{$item}) {
				my $item_def = $PATTERNS_ext->{$item};
				
				if (ref $item_def eq 'HASH') {
					$item_def = convertItemFromHashToTab($item_def);
				}
				$item_def->[$framework::dataType::IDX_ITEM] = $item;
				$PATTERNS->{$item} = $item_def;
			}
			else {
				framework::Logs::Warning("When merging, item '$item' is ignored because already existing\n");
			}
		}
	}
}

# Old version of parseOptions()
# --> replaced because was not able to take into account regexp specified by user.
sub parseOptions1($) {
	my $options = shift;

	if (!defined $options) {
		return {};
	}

	my @opts = split /\s*,\s*/, $options;
	my %H_opt = ();
	
	for my $optdef (@opts) {
		my ($opt, $value) = $optdef =~ /(\w+)(?:\s*:\s*([^,]+))?/;
		$H_opt{$opt} = $value;
	}
	return \%H_opt;
}

sub parseOptions($) {
	my $options = shift;
	
	if (!defined $options) {
		return {};
	}

	my %H_opt = ();
	my $insideREG = 0;
	my $name = undef;
	my $value = undef;
	
	my %REGS = (
		'name' 			=> qr/\G\s*(\w+)\s*:?|\G([^\w]+)/,
		'startValue'	=> qr/\G\s*(\/)|\G([^\/,]+)/,
		'value'			=> qr/\G([^,]+)|(,)/,
		'regexp'		=> qr/\G(?:(\\\/)|([^\\\/]*)|(\/\s*,?))/,
	);
	my $state = 'name';
	my $reg;
	while ($reg = $REGS{$state}, $options =~ /$reg/g) {
		if ($state eq 'name') {
			if (defined $1) {
				$name = $1;
				$state = "startValue";
			}
			else {
				print "ERROR when parsing options : $2 can not begong to a name option !\n";
				return \%H_opt;
			}
		}
		elsif ($state eq 'startValue') {
			if (defined $1) {         # "/" encountered at value beginning
				$state = 'regexp';
				$value = ''
			}
			else {
				$state = 'value';
				$value .= (defined $value ? $value.$2 : $2);;
			}
		}
		elsif ($state eq 'value') {
			if (defined $1) {
				$value = (defined $value ? $value.$1 : $1);
			}
			else {
				# ',' detected means means another option is following

				# remove leading blanks if any
				$value =~ s/^\s*//m if $value;
				
				$H_opt{$name} = $value;
				$name = undef;
				$value = undef;
				$state = 'name';
			}
		}
		elsif ($state eq 'regexp') {
			if (defined $1) { # "\\\/" encountered inside regexp
				$value .= $1;
			}
			elsif (defined $2) { # "anything except a /"
				$value .= $2;
			}
			else {  # "/" encountered, means end of regexp (eventually followed by a coma ...
				
				# remove leading blanks if any
				$value =~ s/^\s*//m if $value;
				
				$H_opt{$name} = qr/$value/;
				$name =undef;
				$value = undef;
				$state = 'name';
			}
		}
	}
	
	if ($state eq 'reqexp') {
		print "ERROR : unterminated REGEXP for option $name !!\n";
	}
	else {
		# store the last value if any ...
		if (defined $name) {
			
			# remove leading blanks if any
			$value =~ s/^\s*//m if $value;
			
			$H_opt{$name} = $value;
		}
	}
	
#	for my $opt (keys %H_opt) {
#		if (defined $H_opt{$opt}) {
#			print "    $opt => ".$H_opt{$opt}."\n";
#		}
#		else {
#			print "    $opt => undef\n";
#		}
#	}
	
	return \%H_opt;
}

sub loadExternalFromPackage($$) {
	my $techno = shift;
	my $DB = shift;
	
	my $module = "framework/external.pm";
	
	eval {
		require $module;
	};
	if ($@)
	{
		framework::Logs::Warning("Unable to load module: $module. No external framework pattern will be loaded. ($@)\n");
		return;
	}
	
	framework::Logs::printOut("external framework detection patterns loaded.\n");
	
	mergeExternal($DB, framework::external::getDB($techno));

		for my $env (keys %$DB) {
			my $patternDB = $DB->{$env}->{'PATTERNS'};
			for my $item (keys %{$patternDB}) {
				my $itemData = $patternDB->{$item};
				my $options = $itemData->[$framework::dataType::IDX_OPTIONS];
				$itemData->[$framework::dataType::IDX_OPTIONS] = parseOptions($options);
			}
		}
	
}

sub loadUserDefinedFramework($$) {
	my $file = shift;
	my $DB = shift;
	return $DB;
}

sub loadDescriptionfromCsv($) {
	my $DBFile = shift;
	framework::Logs::printOut "Loading framework description in $DBFile\n";
	
	my $ret = open DB, "<$DBFile";
	
	if (! defined $ret) {
		framework::Logs::Warning("unable to open framework descriptions ($!)\n");
		return (undef, $CODE_FILE_IO);
	}
	
	$/ = undef;
	
	my $buf = <DB>;
	my %H_DB = ();
	
	my $errorcode = $CODE_OK;
	my $techno = undef;
	my @columnNames = ();
	my $H_item = {};
	my $item = undef;
	my $linecount = 0;
	while ($buf =~ /^(.*)$/mg) {
		my $line = $1;
		$linecount++;
		
		# skip empty lines
		if ($line =~ /^;*$/m) {
			next;
		}
		
		# skip commented lines
		if ($line =~ /^\s*#/m) {
			next;
		}
		
		my @data = split ';', $line;
		
		#--------------- WORDING LINE --------------
		if (($data[0] eq "techno")) {
			# column name specification
			@columnNames = ();
			shift @data; # first column is the techno (do not memorize this mandatory field) !!
			shift @data; # second column is the name of the framework (do not memorize this mandatory field) !!
			
			for my $name (@data) {
				push @columnNames, $name;
			}
		}
		#--------------- DATA LINE -----------------
		else {
			# --------------- CHECK TECHNO COLUMN ------------
			$techno = shift @data;
			if ((! defined $techno) || ($techno eq '')) {
				framework::Logs::Warning("$DBFile: missing techno field at lin $linecount !!\n");
				last;
			}
			
			# --------------- CHECK NAME COLUMN ------------
			# Read the name column.
			my $name = shift @data;
			
			if (!defined $name) {
				framework::Logs::Warning("$DBFile: missing name field at lin $linecount !!\n");
				last;
			}
			
			# --------------- GET OTHERS COLUMNS ... ------------
			for my $column (@columnNames) {
				my $value = shift @data;
				if (defined $value) {
					if ($value eq '') {
						$value = undef;
					}
				}
				$H_DB{$techno}->{$name}->{$column} = $value;
			}
		}
		
	}
	
	close DB;
	return (\%H_DB, $errorcode);
}

sub BuiltFrameworkNamesListExceptEnv($$) {
	my $technoDB = shift;
	my $excludedEnv = shift;
	
	my %hash = ();
	my @list = ();
	
	for my $env (keys %$technoDB) {
		next if ($env eq $excludedEnv);
		my $items = $technoDB->{$env}->{'PATTERNS'};
		for my $item (keys %$items) {
			my $name = $items->{$item}->[$framework::dataType::IDX_NAME];
			if (! exists $hash{$name}) {
				$hash{$name} = 1;
				push @list, $name;
			}
		}
	}
	return \@list;
}

sub getHashLowercaseNames($) {
	my $technoDB = shift;
	my %hash = ();
	
	for my $env (keys %$technoDB) {
		my $items = $technoDB->{$env}->{'PATTERNS'};
		for my $item (keys %$items) {
			my $name = $items->{$item}->[$framework::dataType::IDX_NAME];
			if (defined $name) {
				$hash{lc($name)} = $name;
			}
		}
	}
	return \%hash;
}

1;
