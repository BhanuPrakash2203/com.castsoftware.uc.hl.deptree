package framework::R_FW;

use warnings;
use strict;
use framework::baseFramework;
use framework::maven;
use framework::projectFiles;

our @ISA = ("framework::baseFramework");

my $TECHNO = 'R';

# Il faut spécifier aussi la vue dans laquelle doit être faite la recherce de pattern. (code ar défaut).

#******************** MAIN LIST **************************

my %DB = (
	'code' => {
		'PATTERNS' => {}
	}
);


sub new($$) {
	my $class = shift;
	my $techno = shift;
	my $tabTabSource = shift;
	
	my $self = $class->SUPER::new($techno, \%DB, $tabTabSource);

	bless ($self, $class);
	
	print "[framework] R framework detection plugin loaded ...\n";
	
	return $self;
}

sub preAnalysisDetection() {
	my $self = shift;
}

#-----------------------------------------------------------------------

# TODO :
# 1 - pre record all variables initialised with a literal list
# 2 - if a monitored variable has been checked, do not check anymore
# 3 - monitored variable in a for loop.
# 4 - when searching functions calls in getFunctionCall_FirstParam_List(), search ALL occurences, not only the first (do a loop) ! 


my %VAR_INITIALIZED_WITH_LIST = ();

sub getParenthesesContent($) {
	my $code = shift;
	my $level = 1;
	my $args = "";
	while ($$code =~ /\G([^\(\)]*|\(|\))/gc) {
		if ($1 eq '(') {
			$level++;
			$args .= $1;
		}
		elsif ($1 eq ')') {
			$level--;
			if ($level == 0) {
				return $args;
			}
			else {
				$args .= $1;
			}
		}
		else {
			$args .= $1;
		}
	}
}

sub getInitWith_LiteralList($) {
	my $code = shift;
	
	my $items;
	pos($$code) = 0;
	
	while ($$code =~ /(?:\G\s*|[^\(,\s]\s*)\b([\w\.]+)\s*(?:<-|=)\s*c\(/gc) {
		my $var = $1;
		$items = getParenthesesContent($code);
		$items =~ s/\s//g;
		my @list = split /,/, $items; 
		$VAR_INITIALIZED_WITH_LIST{$var} = \@list;
#print STDERR "VARIABLE $var INITIALIZED WITH : $items\n";
	}
}

my @CONTEXT = ();
my %MONITORED_VARIABLE = ();

# SEARCH calls of a given function somewhere in the code
# --> then return its first parameter value if it is initialized with a literal list
sub getFunctionCall_FirstParam_List($$) {
	my $functionName = shift;
	my $code = shift;;
	
	my $items;
	my @list = ();
	
	# CONVENTIONAL FUNCTION CALL
	my $pos = pos($$code);
	pos($$code) = 0;
	while ($$code =~ /\b$functionName\s*\(/gc) {
#print STDERR "CONVENTIONAL CALL : $functionName\n";
		# is the first parameter an explicit literal list ...
		if ($$code =~ /\G\s*c\(/gc) {
			$items = getParenthesesContent($code);
		}
		# is the first parameter is a variable ...
		elsif ($$code =~ /\G\s*([\w\.]+)/gc) {
			my $var = $1;
			# is the variable explicitely initialized somwhere in the code with a list ? 
			my $L = $VAR_INITIALIZED_WITH_LIST{$var};
			if (defined $L) {
				push @list, @$L
			}
		}
		
		if (defined $items) {
#print STDERR "----> ITEMS = $items\n";
					
			$items =~ s/\s//g;
			push @list, split /,/, $items;
		}
	}
	
	# MAPPING FUNCTION CALL
	pos($$code) = 0;
	while ($$code =~ /\b[sl]apply\s*\(\s*(([\w+\.]+)|c\(([^\(\)]*)\))\s*,\s*$functionName/gc) {
#print STDERR "MAPPING CALL : $functionName over $1\n";
		if (defined $2) {
			my $L = $VAR_INITIALIZED_WITH_LIST{$2};
			if (defined $L) {
				push @list, @$L
			}
		}
		else {
			$items = $3;
		}
		
		if (defined $items) {
#print STDERR "----> ITEMS = $items\n";
			
			$items =~ s/\s//g;
			push @list, split /,/, $items;
		}
	}
	
	pos($$code) = $pos;
	return \@list;
}


sub getMonitoredVariableListValue($$) {
	my $var = shift;
	my $code = shift;
	
	my $itemsList;

	my $data = $MONITORED_VARIABLE{$var};
	if ($data->{'checked'} == 0) {
		if ($data->{'monitoring'} eq 'function_call') {
			# the variable is the first parameter of a function call.
			# To know its value, we should search the calls ...
			$itemsList = getFunctionCall_FirstParam_List($data->{'value'}, $code);
		}
		elsif ($data->{'monitoring'} eq 'for') {
			# the variable is the iterator of a "for" loop.
			# To know its value, we should search the tracked data ...
			my $tracked = $data->{'value'};
			if (ref $tracked eq "ARRAY") {
				$itemsList = $tracked;
			}
			else {
				$itemsList = getVariableListValue($tracked, $code);
			}
		}
		$data->{'checked'} = 1;
	}

	return $itemsList;
}

# SEACH if a given variable is initialized with a literal list somewhere in the code ...
sub getVariableListValue($$) {
	my $var = shift;
	my $code = shift;
	
	my $itemsList;
	
	my $pos = pos($$code);
	pos($$code) = 0;
	
	# is the variable initialyzed indirectly through a monitored variable ? 
	if (exists $MONITORED_VARIABLE{$var}) {
#print STDERR "--> get MONITORED VARIABLE value : $var\n";
		$itemsList = getMonitoredVariableListValue($var, $code);
	}
	# The variable is not monitored. So is it explicitely initialized somewhere ? 
	else {
		$itemsList = $VAR_INITIALIZED_WITH_LIST{$var};
	}
	
	#elsif ($$code =~ /\b$var\s*<-\s*c\(/gc) {
#print STDERR "--> NON MONITORED VARIABLE : $var, initialized with a list\n";
	#	$items = getParenthesesContent($code);
	#}

	pos($$code) = $pos;

	return $itemsList;
}


# If lapply() OR sapply() is mapping require() OR library() function call
# --> try to return the list of module passed in FIRST PARAMETER (use light data flow if needed)
sub check_lapply($$) {
	my $args = shift;
	my $code = shift;
#print STDERR "MAPPING : $args\n";
	my $ret = {};
	
	my $itemsList;
	
	if ($args =~ /\Ac\(/gc) {
		# FIRST PARAMETER is a literal list
		my $items = getParenthesesContent(\$args);
		$items =~ s/\s//g;
		@$itemsList = split /,/, $items;
	}
	elsif ($args =~ /\A([\w\.]+)/gc) {
		# FIRST PARAMETER is a variable
		my $variable = $1;
		
		# try to get the value of the variable
		$itemsList = getVariableListValue($variable, $code);
	}
	
	if (scalar @$itemsList) {
		if ($args =~ /\G,(require|library)\b/gc) {
			$ret->{'function'} = $1;
			$ret->{'modules'} = $itemsList;

			return $ret;
		}
	}
	
	return undef;
}


sub isModuleVariable($$) {
	my $module = shift;
	my $code = shift;
	
	my $pos = pos($$code);
	pos($$code) = 0;
	
	if ($module =~ /[\.\/]/) {
		pos($$code) = $pos;
		return 0;
	}
	
	if ($$code =~ /\bfor\s*\(\s*$module\s+in/) {
		pos($$code) = $pos;
		return 1;
	}
	
	pos($$code) = $pos;
	return 0;
}

my $FUNCTION_REG = qr/[\w\.]+\s*(?:<-|=)\s*function\s*\(/;
my $FOR_REG = qr/\bfor\s*\(\s*[\w\.]+\s+in\b\s*/;


sub detection($$$) {
	my $filename = shift;
	my $views = shift;
	my $H_FileDetection = shift;
	
	my $code = \$views->{'code'};
	my $HString = $views->{'HString'};
	
	my $line = 1;
	if (defined $code) {
		
		getInitWith_LiteralList($code);
		pos($$code) = 0;
		
		# To be strict:
		# - "install_load" should be validated by the presence of : library('install.load')
		# - pacman::p_load should be validated by the presence of : library('pacman')
		# --> we assume that the user will not create its own symbols to do anything else ...
		
		while ($$code =~ /\b(require|library|install_load|pacman::p_load|[ls]apply)\b\s*|($FUNCTION_REG)|($FOR_REG)|(\n)|(\{)|(\})/gc) {
			if (defined $4) {
				$line++;
			}
			elsif (defined $5) {
				# opening {
				push @CONTEXT, {'type' => 'unknow'};
			}
			elsif (defined $6) {
				# closing }
				if (scalar @CONTEXT) {
					my $context = pop @CONTEXT;
					my $var = $context->{'variable'};
					if (defined $var) {
						delete $MONITORED_VARIABLE{$var};
					}
				}
				else {
					print STDERR "Unmatched closing accolade at line $line\n";
				}
			}
			elsif (defined $2) {
				# FUNCTION context
				my $pattern = $2;

				if ($$code =~ /\G([\w\.]+)\s*,[^\(\)]*\)\s*\{/gc) {
#print STDERR "FUNCTION: $pattern\n";
					# the body is enclosed with accolade ...
					my $var = $1;
#print STDERR "--> MONITORED VARIABLE : $var\n";
					my ($funcName) = $pattern =~ /\A\s*([\w\.]+)/;
					
					push @CONTEXT, {'type' => 'function', 'name' => $funcName, 'variable' => $var};
					$MONITORED_VARIABLE{$var} = {'monitoring' => 'function_call', 'value' => $funcName, 'checked' => 0};
				}
			}
			elsif (defined $3) {
				# FOR iteration context
				my $pattern = $3;
#print STDERR "FOR: $3\n";
				my ($var) = $pattern =~ /\(\s*([\w\.]+)/gc;
				if (defined $var) {
					my $tracked;
					if ($$code =~ /\G\s*(?:([\w\.]+)\s*|(c\([^\(\)]*\)))\s*\)\s*\{/gc) {
						if (defined $1) {
#print STDERR "--> ITERATION of $var over $1\n";
							$tracked = $1;
						}
						else {
							my $items = $2;
#print STDERR "--> ITERATION of $var over $items\n";
							$items =~ s/\s*//g;
							$tracked = [split /,/, $items];
						}
					}
					$MONITORED_VARIABLE{$var} = {'monitoring' => 'for', 'value' => $tracked, 'checked' => 0};
				}
				push @CONTEXT, {'type' => 'for', 'variable' => $var};
			}
			else {
				# PATTERN for install/load dependencies
				my $function = $1;
				my $args = "";
				if ($$code =~ /\G\(/gc) {
					$args .= getParenthesesContent($code);
					$args =~ s/\s//g;
#print STDERR "DETECTION : $function ($args)\n";
					
					my $modules = [];
					if ($function eq "pacman::p_load") {
						# pacman::p_load( ... )
						# --> the modules list is the whole parameters list
						@$modules = split /,/, $args;
					}
					elsif (($function eq "lapply") || ($function eq "sapply")){
						# lapply OR sapply invokation ...
						# --> check if this invokation concerns module loading ...
						my $ret = check_lapply($args, $code);
						
						# no modules found ...
						next if (! defined $ret);
						
						# get modules
						$modules = $ret->{'modules'};
						$function .= "/".$ret->{'function'};
					}
					else {
						# require( ... ) OR library( ... ) OR install_load( ... )
						# --> the modules list is a single item corresponding to the first element
						my ($param) = $args =~ /\A\s*([\w\.\/]+)/;
						
						# case 1 : the parameter is a monitored variable ...
						if (exists $MONITORED_VARIABLE{$param} ) {

#print STDERR "Function $function applying to monitored variable $param\n";

							$modules = getMonitoredVariableListValue($param, $code);
						}
						
						# case 2 : the parameter is a the name of the module ...
						else {
							$modules = [ $param ];
						}
					}
					
					for my $module (@$modules) {
						if ($module =~ /\b(CHAINE_\d+)\b/) {
							if (defined $HString->{$1}) {
								$module = $HString->{$1};
								$module =~ s/["']//g;
							}
						}
					
						if (! isModuleVariable($module, $code)) {
#print STDERR " FOUND MODULE ------> $module\n";
							my $itemResult = {};
							my $version = "0";
							$itemResult->{'framework_name'} = "cran/$module";
							$itemResult->{'data'}->{$framework::dataType::ITEM} = "$module#$version";
							$itemResult->{'data'}->{$framework::dataType::MIN_VERSION} = undef;
							$itemResult->{'data'}->{$framework::dataType::MAX_VERSION} = undef;
							$itemResult->{'data'}->{$framework::dataType::MATCHED_PATTERN} = $function;
							$itemResult->{'data'}->{$framework::dataType::EXPORTABLE} = 1;
							$itemResult->{'data'}->{$framework::dataType::ENVIRONMENT} = 'code';
							$itemResult->{'data'}->{$framework::dataType::STATUS} = $framework::dataType::STATUS_DISCOVERED;
							$itemResult->{'data'}->{$framework::dataType::ARTIFACT} = $filename;
							framework::detections::addItemDetection($H_FileDetection, $itemResult);
						}
					}
				}
				else {
					print STDERR "ERROR : function $function without parenthesed arguments at line $line\n";
				}
			}
		}
	}
}

sub insideSourceDetection($$) {
	my $self = shift;
	my $views = shift;
	my $filename = shift;

	# tell the parent to not merge the result. This will be done in this overriding function.
	my $merge_result_in_parent = 0;
	
	# scan the code source 
	my $H_FileDetection = $self->SUPER::insideSourceDetection($views, $filename, $merge_result_in_parent);
	
	# Put here the code for analyzing correlation between detections and eventually modify some data (like version !)
	# ...
	detection($filename, $views, $H_FileDetection);

	# merge into SUPER::H_detmergeInsideSourceDetectionections. (that will be stored when calling potAnalysisDetection)
	$self->mergeInsideSourceDetection($H_FileDetection, \&framework::detections::default_merge_callback);
}

sub postAnalysisDetection() {
	my $self = shift; 
	
	# scan the maven project
	#my $H_MavenDetection = framework::maven::detect($self->{'tabSourceDir'}, $self->{'DB'});
	
	# store the results.
	#$self->store_result($H_MavenDetection);
	
	# scan project file : !!! this is assumed by SUPER::postAnalysisDetection  !!! 
	#my $H_ProjectFilesDetection = framework::projectFiles::detect($self->{'tabSourceDir'}, $self->{'DB'}, "Java");
	# store the results.
	#$self->store_result($H_ProjectFilesDetection);
	
	$self->SUPER::postAnalysisDetection();
}

1;
