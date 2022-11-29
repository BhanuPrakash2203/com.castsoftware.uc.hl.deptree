package SourceUnit;

use strict;
use warnings;

use File::Path;

use AutoDecode;
use Encode;
use Lib::Data;

# Give Source file associated to an Unit.
my %H_Unit2Source = ();

# Record file info : number of units, number of lines
my %H_SourceInfo = ();

# Record unit info : number of lines, mode, related origin source ...
my %H_UnitInfo = ();

# Record analyseur info : number of files.
my %H_AnalyzerInfo = ();

#File Types :
my $TYPE_UNKNOW = 3;
my $TYPE_STANDARD = 1;
my $ABAP_TYPE_WEBDYN = 2;
my $ABAP_CLASSPOOL = 3;

# Analysis Mode Management
our $REDEFINE_OFF=0;
our $REDEFINE_ON=1;

my $AnalysisMode = $REDEFINE_OFF;

sub get_AnalysisMode() {
  return $AnalysisMode;
}

# File Mode management
our $MODE_NORMAL = 0;
our $MODE_SPLIT = 1;
our $MODE_CONCAT = 2;
our $MODE_EXCLUDED = 3;
my $SourceMode = $MODE_NORMAL;

sub get_SourceMode() {
  return $SourceMode;
}

# Current Unit Analysis management

my $CurrentUnitName = "";

sub open_CurrentUnit($) {
  $CurrentUnitName = shift;
  if (defined $H_UnitInfo{$CurrentUnitName}->{'mode'}) {
    $SourceMode = $H_UnitInfo{$CurrentUnitName}->{'mode'};
  }
  else {
    $SourceMode = $MODE_NORMAL ;
  }
}

sub close_CurrentUnit() {
  $CurrentUnitName = "";
  $SourceMode = $MODE_NORMAL;
}

sub ReadFile($) {
  my $file = shift;

  $/ = undef;
  my $ret = open FIC, "<$file";

  if (defined $ret) {
    my $content = <FIC>;
    if (defined $content) {
      return \$content;
    }
  }
print STDERR "[SourceUnit] Unable to read $file\n";
  return undef;
}


sub WriteFile($$$;$) {
  my ($fullname, $data, $context, $mode) = @_;
  # $mode : 1 ==> append mode.
  # $mode : 0 ==> create mode.

  if (! defined $mode) {
    $mode = 0;
  }

  my $ret;
  if ($mode == 1) {
    $ret = open FIC, ">>$fullname";
  }
  else {
    $ret = open FIC, ">$fullname";
  }

  if (defined $ret) {
    print FIC $$data;
    close FIC;


    # Add file in the output list, except in "append" mode ...
    # In append mode, the file is allready existing, so it should already be
    # in the list => do not add once !!!
    push @{$context->[0]}, $fullname unless $mode == 1;

    # Record metainfo ...
    $H_UnitInfo{$fullname} = $context->[3] ;
  }
  else {
    print "[SourceUnit] ERROR : unable to create $fullname\n";
  }
}

#-----------------------------------------------------------------
#     GETTER
#-----------------------------------------------------------------

sub get_SourceFile($) {
  my $UnitName = shift;
  if ( defined $H_Unit2Source{$UnitName} ) {
    return  $H_Unit2Source{$UnitName};
  }
  else {
    print STDERR "UNIT ERROR : no corresponding source for $UnitName !!\n";
    return '';
  }
}

sub get_SourceNbUnits($) {
  my $source = shift;
  if ( defined $H_SourceInfo{$source} ) {
    return  $H_SourceInfo{$source}->[0];
  }
  else {
    print STDERR "UNIT ERROR : no corresponding number of unit for $source !!\n";
    return 0;
  }
}

sub get_SourceSize($) {
  my $source = shift;
  if ( defined $H_SourceInfo{$source} ) {
    return  $H_SourceInfo{$source}->[1];
  }
  else {
    print STDERR "UNIT ERROR : no corresponding size for $source !!\n";
    return 0;
  }
}

sub get_SourceNbLines($) {
  my $source = shift;
  if ( defined $H_SourceInfo{$source} ) {
    return  $H_SourceInfo{$source}->[2];
  }
  else {
    print STDERR "UNIT ERROR : no corresponding number of lines for $source !!\n";
    return 0;
  }
}

sub get_UnitInfo($$) {
  my $UnitFileName = shift;
  my $infokey = shift;
  if (defined $H_UnitInfo{$UnitFileName}) {
    return  $H_UnitInfo{$UnitFileName}->{$infokey};
  }
  else {
    return undef;
  }
}

sub get_ConcatenedFiles($) {
  my $concatFile = shift;
  my $list = $H_UnitInfo{$concatFile}->{'origin'};
  if ( ! defined $list) {
    return ();
  }
  else {
    return split ',', $list;
  }

}


sub get_AnalyzerNbFile($) {
  my $analyzer = shift;
  if ( defined $H_AnalyzerInfo{$analyzer} ) {

    return  $H_AnalyzerInfo{$analyzer};
  }
  else {
    print STDERR "UNIT ERROR : number of file not available for $analyzer !!\n";
    return 0;
  }

}

#-----------------------------------------------------------------
#     Redefined Source Code.
#-----------------------------------------------------------------
sub redefineSource($$$$) {
  my $InputList = shift;
  my $Analyzer = shift;
  my $SrcDir = shift;
  my $options = shift;
  my $OutputListFormat = 0; # Line command mode by default.
  my %H_ListSource = ();

  if (! defined $Analyzer) {
    return $InputList;
  }

  if ( defined $options->{'--force-file-mode'} ) {
    return $InputList;
  }

  # canonise the analyser name
  if (lc($Analyzer) eq "tsql") {
    $Analyzer = "AnaTSql";
  }
  elsif (lc($Analyzer) eq "abap") {
    $Analyzer = "AnaAbap";
  }

  # Original number of source file given by the HMI.
  $H_AnalyzerInfo{$Analyzer} = scalar @{$InputList} ;

  for my $item ( @{$InputList} ) {

    my $fichier;

    if (ref $item eq 'ARRAY' )
    {
      # In HMI mode, items of the file list are a list of informations about the file ...
      
      $OutputListFormat = 1; # HMI list format

      my $analyseur_fichier;
      ( $analyseur_fichier, $fichier ) = @{$item};
      if ( defined $analyseur_fichier )
      {
        $Analyzer = $analyseur_fichier;
      }
    }
    else
    {
      # In line command, items of the file list are directly the name of the file.
      $fichier = $item;
    }

    # rebuild a specific list by analyzer in case of several analyzer ...
    if ( ! exists $H_ListSource{$Analyzer}) {
      $H_ListSource{$Analyzer} = [];
    }
    push @{$H_ListSource{$Analyzer}}, $fichier;

  }

  my @OutputFileList = ();
  for my $Ana ( keys %H_ListSource ) {

    # Case of TSql files ...
    if ($Ana eq "AnaTSql") {
      $SourceMode = $MODE_SPLIT; # FIXME : to remove
      $AnalysisMode = $REDEFINE_ON;
      push @OutputFileList, @{Preprocess_TSql_AnalysisUnit($H_ListSource{$Analyzer}, $SrcDir, $OutputListFormat)};
    }

    if ($Ana eq "AnaAbap") {
      $SourceMode = $MODE_CONCAT; # FIXME : to remove
      $AnalysisMode = $REDEFINE_ON;
      push @OutputFileList, @{Preprocess_Abap_AnalysisUnit($H_ListSource{$Analyzer}, $SrcDir, $OutputListFormat)};
    }

    #if ($Ana eq "AnaPHP") {
    #  $SourceMode = $MODE_CONCAT; # FIXME : to remove
    #  $AnalysisMode = $REDEFINE_ON;
    #  push @OutputFileList, @{Preprocess_PHP_AnalysisUnit($H_ListSource{$Analyzer}, $SrcDir, $OutputListFormat)};
    #}
  }

  if ( ! scalar @OutputFileList) {
    # @OutputFileList is empty means that the file did'nt need to be preprocessed into analysis Units.
    # So the input list is returned ...
    return $InputList;
  }
  else {
    return \@OutputFileList;
  }
}


my $CurrentIdent = 0;

sub nextIdent() {
  return $CurrentIdent++;
}

sub addFileUnit($$) {
  my $filename = shift;
  my $context = shift;

  my $item = $filename;

  # $context->[2] is the format
  if ($context->[2]) {
    # $context->[1] is the analyseur
    $item = [ $context->[1], $filename ];
  }

  push (@{$context->[0]}, $item);

  # $context->[4] is the orignal source filename.
  $H_Unit2Source{$filename} = $context->[4];

  # Record Unit Info
  my %H_info = ();
  $H_info{'mode'} = $MODE_SPLIT; # Allways SPLIT for TSQL ...
  $H_UnitInfo{$filename} = \%H_info;
}

sub dumpArtifact($$;$) {
  my $r_buf = shift;
  my $context = shift;
  my $specified_name = shift;

  # INFO : $context->[3] is basefilename.
  # INFO : $context->[5] is the file extension.
 
  # Compute the name of the file (without path nor extension)
  # ---------------------------------------------------------
  my $ident;
  if (defined $specified_name)  {
    #PATTERN : <sql_source_file_whithout_extension>.<specified_artifact_name>
    $ident = $context->[3];
    $ident =~ s/\.sql$//mi ;
    $ident .= ".".$specified_name;
  }
  else {
    #PATTERN : <sql_source_file_whithout_extension>.<uniq_ident>
    # By default, use the basename added with a uniq ident.
    $ident = $context->[3].".".nextIdent();
  }

  # Complete with path and extension.
  # -----------------------------------
  my $filename = "tmp/$ident".$context->[5];

  # Check if the created filename already exists
  # ---------------------------------------------
  # If some file already use this name, then differente it
  # by addition of a uniq identifer ...
  while ( exists $H_Unit2Source{$filename} ) {
    $filename = "tmp/$ident".".".nextIdent().$context->[5];
  }

    # FILE NAME PATTERN : <file_basename>.[<schema>.]<name>.[<id>].sql
    #
    # Where :
    # ---------
    # <file_basename> is the base name (without extension) of the source file.
    # <schema> when present, is schema part in the name of the artifact.
    # <name> is the name of the artifact
    # <id> is a uniq id use to differenciate file name in case there where 
    # redundancies. 


  # Write the file
  # ---------------
  my $ret = open ARTIFILE, ">$filename";

  if ( ! defined $ret) {
    print STDERR "Unable to write artifact in $filename\n";
    return 0;
  }
  print ARTIFILE $$r_buf;
  addFileUnit($filename, $context);
  close ARTIFILE;

  return 1;
}

sub extractArtifactName($) {
  my $code = shift;
  my $name;

  my $IDENT = '(?:\[[^\[\]]+\]|\"[^\"]+\"|[\w$#@]+)';

  if ($$code =~ /\bcreate\s+(?:procedure|proc|function|trigger)\b\s*(${IDENT})(?:\s*\.\s*(${IDENT}))?/is) {
    if ((defined $2) && ($2 ne '')) {
       $name = GetString($1).".".GetString($2);
    }
    else {
       $name = GetString($1);
    }
  }
  else {
    $name = "NotRecognized_Name";
  }
  # As the file name based on the artifact name will be used in a csv file,
  # the name of the artifact can not contain ";" or '"'.
  # As windows does not support some characters in filename, the following
  # are banned: \/=*?"<>
  #
  # So these characters will be replaced by ~
  $name =~ s/[;"\\\/=\*\?<>]/~/g;
  return $name;
}

# return 1 if the artifact has been dumped
# return 0 if not.
sub TSqlArtifact($$$) {
  my $r_code = shift;
  my $r_source = shift;
  my $context = shift;

  #if ( $$r_code =~ /\bcreate\s+(?:(procedure|proc)|(function)|(trigger))\b(.*?)\b(?:AS|on|RETURN)\b/i ) {
  if ( $$r_code =~ /\bcreate\s+(?:procedure|proc|function|trigger)\b/i ) {
    my $name = extractArtifactName($r_code);

    return dumpArtifact($r_source, $context, $name );
  }
  else {
    return 0;
  }
}


#------------------- CONTEXT MANAGEMENT -----------
my $INCODE = 1;
my $INCOMMENT = 2;
my $INSTRING = 3;
my $INEXECUTESQL = 4;

my @TextState = ('U', 'P', 'C', 'S', 'E');

my @ContextStack = ();

sub newContext($$) {
  my $state = shift;
  my $closing = shift;
  my %H = ('state' => $state, 'closing' => $closing, 'code' => '', 'source' => '' );
  #my %H = ('state' => shift, 'closing' => shift, 'code' => '');
  push @ContextStack, \%H ;
  return $ContextStack[-1];
}

sub previousContext() {
  if (scalar @ContextStack > 0) {
    # remove current context ...
    my $removed = pop @ContextStack;

    # return previous context ...
    if (scalar @ContextStack > 0) {
      # The removed context was a sub-context of the previous one. So, its corresponding
      # source code is part of the previous context source code. It is then concatenated.
      $ContextStack[-1]->{'source'} .= $removed->{'source'};
      return $ContextStack[-1];
    }
    else {
      print "[Source preparation] ERROR : no previous context to resume ...\n";
      return newContext($INCODE, '');
    }
  }
  else {
    print "[Source preparation] ERROR : no current context to remove ...\n";
    return newContext($INCODE, '');
  }
}

#===========================================================
#------------------- SOURCE PREPARATION TREATMENT ----------
#===========================================================


#---------------------------------------------
# - - - - - - - - - - TSQL - - - - - - - - - -
#---------------------------------------------

my %H_STRING = ();
my $CURRENT_STRING = "";
my $CURRENT_KEY = "";
my $NEXT_ID = 0;
sub GetString($) {
  my $s = shift;
  if (exists $H_STRING{$s}) {
    return $H_STRING{$s};
  }
  else {
    return $s;
  }
}

sub Preprocess_TSql_AnalysisUnit($$$) {
  my $InputList = shift;
  my $SrcDir = shift;
  my $Format = shift;

  my @OutputList = ();
  my @GeneralContext = (\@OutputList, "AnaTSql", $Format);

  for my $file ( @{$InputList} ) {

	my $needEncoding = Lib::Sources::needEncodingForExisting($SrcDir, $file); 
	if (defined $needEncoding) {
	  if ($needEncoding ne "unknow") {
		  print STDERR "[SourceUnit] /!\\ using encodage $needEncoding for file name : $file\n";
		  print STDERR "--> before encodage : ".Lib::Data::hexdump_String($file)."\n";
		  # encode file name with the detected encoding
		  $file = Encode::encode($needEncoding, $file);  
		  print STDERR "--> after encodage  : ".Lib::Data::hexdump_String($file)."\n";
	  }
	  else {
		  print STDERR "[SourceUnit] WARNING : file $file seems to be not existing in default encoding\n";
		  print STDERR "--> current encodage : ".Lib::Data::hexdump_String($file)."\n";
	  }
	}

    $GeneralContext[4] = $file;

    # Full filename.
    my $fullfilename = $file;
    
    # filter DOS full path name (x:\...\)
    if (( $SrcDir ne "") && ($file !~ /^\w+:[\\\/]/m)) {
      $fullfilename = $SrcDir."/".$file ;
    }

    # Exension
    my ($extension) = $file =~ /.*(\.\w*)$/ ;
    if ( defined $extension) {
      $GeneralContext[5] = $extension;
    }
    else {
      $GeneralContext[5] = "";
    }

    my $ret = open SRCFILE, "<$fullfilename" ;
    
    if (! $ret ) {
		print STDERR "Unable to open $fullfilename: $!\n";
		exit;
	}
    
    $/=undef;
    my $rawbuf = <SRCFILE>;
    close SRCFILE;

    #--------------------------------------------
    #  Manage encoding (decode UTF16) ...
    #--------------------------------------------

    my $detectedEncoding;
    my $buf = AutoDecode::BinaryBufferToTextBuffer ( $fullfilename, \$rawbuf, undef, \$detectedEncoding );

    #--------------------------------------------
    #  Treatments ...
    #--------------------------------------------

    my $basefilename = $file;
    $basefilename =~ s/.*[\\\/]// ;

    $GeneralContext[3] = $basefilename;

#my @parts = split (  /(\/\*|\*\/|--|\'\'|\"\"|\\\'|\\\"|\'|\"|\n|\bgo\b|\bsp_executesql\s+(?:\@statement)?\s*=\s*N\')/i , $buf );
my @parts = split (  /(\/\*|\*\/|--|\'\'|\"\"|\\\"|\'|\"|\n|\bgo\b|\bsp_executesql\s+(?:\@statement)?\s*=\s*N\')/i , $buf );

    my $quoteExpected = 0;
    my $state = $INCODE;
    my $context = newContext($INCODE, '');
    my $nb_Units = 0;
    my $size = (stat($fullfilename))[7];;
    my $nb_lines = () = $buf =~ /\n/g;

    push @parts, "__EOF__";

    for my $part (@parts) {
print "[".$TextState[$context->{'state'}]."] $part\n";
      

      #  ------ COMMENT ...
      if ($context->{'state'} == $INCOMMENT) {
        if ( $part eq $context->{'closing'} ) {
          $context = previousContext();
          # Concat to previous context ...
          $context->{'source'} .= $part;
        }
	else {
          # Concat to COMMENT context ...
          $context->{'source'} .= $part;
	}
      }
      #  ------ STRING ...
      elsif ($context->{'state'} == $INSTRING) {
        if ( $part eq $context->{'closing'} ) {
          $context = previousContext();
          # Concat to previous context ...
          $context->{'source'} .= $part;

	  $H_STRING{$CURRENT_KEY} = $CURRENT_STRING;
	  $CURRENT_STRING = "";
        }
	else {
          # Concat to STRING context ...
          $context->{'source'} .= $part;
	  $CURRENT_STRING .= $part;
	}
      }
      #  ------ EXECUTE ...
      elsif ($context->{'state'} == $INEXECUTESQL) {
        if (( $part eq $context->{'closing'} ) && (! $quoteExpected)) {

	  if (! exists $context->{'abort'}) {
            $context->{'source'} =~ s/\'\'/\'/sg ;
	    $nb_Units += TSqlArtifact(\$context->{'code'}, \$context->{'source'}, \@GeneralContext);
          }
          $context = previousContext();
          $context->{'source'} .= $part;
        }
        elsif ( $part eq "/*" ) {
          $context->{'source'} .= $part;
          $context->{'code'} .= " __COMMENT__ ";
	  $context = newContext($INCOMMENT, "*/");
        }
        elsif ( $part eq "--" ) {
          $context->{'source'} .= $part;
          $context->{'code'} .= " __COMMENT__ ";
          $context = newContext($INCOMMENT, "\n");
        }
        elsif ( $part eq "\'" ) {
          $context->{'source'} .= $part;
	  if ( ! $quoteExpected ) {
	    $CURRENT_KEY = "__STRING".($NEXT_ID++)."__";
            $context->{'code'} .=  " $CURRENT_KEY ";
            $context = newContext($INSTRING, "\'");
          }
	  # T $CURRENT_KEYhe expected quote has been consummed. So it is no longer expected.
	  $quoteExpected = 0;
        }
        elsif ( $part eq "\"" ) {
          $context->{'source'} .= $part;
	  $CURRENT_KEY = "__STRING".($NEXT_ID++)."__";
          $context->{'code'} .=  " $CURRENT_KEY ";
          $context = newContext($INSTRING, "\"");
        }
        elsif ( $part =~ /\Asp_executesql/ ) {
	  # If the code being executed throught by sp_executesql contain another
	  # sp_executesql expression, then raise a warning. The second instruction
	  # will be ignored ...
	  print "WARNING : sp_executesql inside sp_executesql. This feature is not supported, artificat will be skipped !\n";
	  $context->{'abort'} = 1;
          $context->{'source'} .= $part;
          $context->{'code'} .= $part;

	  # The regular expression containing "sp_executesql" has matched " .... N'" instead of
	  # " .... N''" (the double quote is required because the code is contained whithin a
	  #  string). The the following quote should be consumed whithout being interpreted
	  #  like end of the EXECUTE STRING, ...
	  $quoteExpected = 1;
        }
	else {
          $context->{'source'} .= $part;
          $context->{'code'} .= $part;
	}
      }
      #  ------ CODE ...
      elsif ($context->{'state'} == $INCODE) {

        if ( $part eq "/*" ) {$context->{'source'} .= $part;
          $context->{'source'} .= $part;
          $context->{'code'} .= " __COMMENT__ ";
	  $context = newContext($INCOMMENT, "*/");
        }
        elsif ( $part eq "--" ) {
          $context->{'source'} .= $part;
          $context->{'code'} .= " __COMMENT__ ";
          $context = newContext($INCOMMENT, "\n");
        }
        elsif ( $part eq "\'" ) {
          $context->{'source'} .= $part;
          $context->{'code'} .= " __STRING__ ";
          $context = newContext($INSTRING, "\'");
        }
        elsif ( $part eq "\"" ) {
          $context->{'source'} .= $part;
	  $CURRENT_KEY = "__STRING".($NEXT_ID++)."__";
          $context->{'code'} .=  " $CURRENT_KEY ";
          $context = newContext($INSTRING, "\"");
        }
        elsif ( $part =~ /\Asp_executesql/ ) {
          $context->{'source'} .= $part;
          $context->{'code'} .= " __sp_executesql__ ";
          $context = newContext($INEXECUTESQL, "\'");
        }
	else {
          $context->{'source'} .= $part;
          $context->{'code'} .= $part;
	}
      }

      # In "code" or "sp_executesql" context, the "go" keyword signifies the validation
      # of an artifact. So submit it and reinit buffer for the following...
      if  ( ( ( $context->{'state'} == $INCODE) ||
	      (( $context->{'state'} == $INEXECUTESQL) && (! exists $context->{'abort'}))  ) &&
            ( $part =~ /\b(?:go|__EOF__)\b/i) ) {

          # In case of code extacted from literal string of sp_executesql, the buffer should be
	  # decoded because simple quotes are doubled ...
	  if ( $context->{'state'} == $INEXECUTESQL) {
            $context->{'source'} =~ s/\'\'/\'/sg ;
	  }


          $nb_Units += TSqlArtifact(\$context->{'code'}, \$context->{'source'}, \@GeneralContext);
          # Reinit for the next artifact
          $context->{'code'} = '';
          $context->{'source'} = "";
      }
    }

    if ( ! $nb_Units ) {
      my $buf = "$file : insufficient code for HIGHLIGHT analysis.";
      my $ret = dumpArtifact(\$buf, \@GeneralContext);
      if ( $ret ) {
        $nb_Units = 1;
      }
      else {
        # FIXME 

      }
    }
    $H_SourceInfo{$file} = [ $nb_Units, $size, $nb_lines ];
  }
  return \@OutputList;
}

#---------------------------------------------
# - - - - - - - - - - ABAP - - - - - - - - - -
#---------------------------------------------

sub removeCastExtractorHeader($$) {
  my $content = shift;
  my $context = shift;

  if (defined $content) {
    if ($$content =~ /^(\* extractor_prog_Version[^\n]*\n(?:\*[^\n]*\n){3})/s ) 
	{
		my $header = $1;
		$$content =~ s/^\* extractor_prog_Version[^\n]*\n(?:\*[^\n]*\n){3}/\n/s;

		if ($header =~ /\bPROGRAM_STATUS\s+SYSTEM\b/s) 
		{
			$context->[3]->{'PROGRAM_STATUS'} = "SYSTEM";
		}
		elsif ($header =~ /\bPROGRAM_STATUS\s+(?:CUSTOM|TEST)\b/s)
		{
			$context->[3]->{'PROGRAM_STATUS'} = "CUSTOM";
		}
		else 
		{
			$context->[3]->{'PROGRAM_STATUS'} = "UNKNOWN";
		}
    }


  }
}

sub AbapFileType($) {
  my $name = shift;

  if ($name =~ /\.flow$/i ) {
    return (1, undef);  # Abap standard
  }

  if ($name =~ /^(SAP_R3WDYN_.*)\.xml$/i ) {
    return ( 2, $1); # Abap WebDyn
  }

  if ($name =~ /^(.*?)[=-]*I[UP]\.abap$/i ) {
    return ( 0, undef); # Abap INTERFACE POOL --> not analyzed
  }

  if ($name =~ /^(.*?)[=-]+(?:C(?:[ILOPTU]|M[0-9A-Z]{3})|CCDEF|CCIMP|CCMAC)\.abap$/i ) {
    return ( 3, $1); # Abap CLASS POOL
  }

  if ( ($name =~ /\.abap$/i ) && ($name !~ /^SAPLY/i ) ){
    return (1, undef); # Abap standard
  }

  return (0, undef);
}
#------Excluded Files
sub ABAP_ExcludeFile($$) {
  my ($file, $context) = @_ ;
  $context->[3]->{'origin'} = $context->[4];
  $context->[3]->{'mode'} = $MODE_EXCLUDED;
  my $content = "";
  WriteFile($context->[1], \$content, $context);
print "EXCLUDED : ".$context->[1]."\n";
  return undef; # nb lines is not computed ...
}

#------Standard Files
sub ABAP_StandardFile($$) {
  my ($file, $context) = @_ ;
  $context->[3]->{'origin'} = $context->[4];
  my $content = ReadFile($file);
  removeCastExtractorHeader($content, $context);

  if (!defined $content) {
    my $EmptyContent="";
    $context->[3]->{'statut'} = 'UNREADABLE';
    $context->[3]->{'mode'} = $MODE_EXCLUDED;
    WriteFile($context->[1], \$EmptyContent, $context);
  }
  else {
    $context->[3]->{'mode'} = $MODE_NORMAL;
    WriteFile($context->[1], $content, $context);
print "STANDARD : ".$context->[1]."\n";
  }
  return undef; # nb lines is not computed ...
}

#------WebDyn Files
sub ABAP_WebDynFile($$) {
  my ($file, $context) = @_ ;

  $context->[3]->{'origin'} = $context->[4];
  my $content = ReadFile($file);

  if (!defined $content) {
    my $EmptyContent="";
    $context->[3]->{'statut'} = 'UNREADABLE';
    $context->[3]->{'mode'} = $MODE_EXCLUDED;
    WriteFile($context->[1], \$EmptyContent, $context);
  }
  else {
    # split the buffer  ...
    my @tmp_tab = split '<!\[CDATA\[', $$content;
    # and ignore first element
    shift @tmp_tab;

    #my $ExtractedContent = "";
    foreach my $elem (@tmp_tab) {
      $elem =~ s/\]\]>.*//s;
      #$ExtractedContent .= $elem;
   }

   my $ExtractedContent = join "\n", @tmp_tab;
   $context->[3]->{'mode'} = $MODE_NORMAL;
   WriteFile($context->[1], \$ExtractedContent, $context);
print "WebDyn : ".$context->[1]."\n";
  }
  return undef; # nb lines is not computed ...
}

#------Class Pool Files

my $CurrentPool_Name = "";
my $CurrentPool_FullName = "";
my $CurrentPool_Meta = undef;
my $CurrentPool_Content = "";
my @CurrentPool_context ;

sub ClosePool() {
 
  my $mode = 0;
  $CurrentPool_context[3]->{'mode'} = $MODE_CONCAT;
  if (exists $H_UnitInfo{$CurrentPool_FullName}) {
    print STDERR "WARNING : Pool allready exists in $CurrentPool_FullName\n";
#    $CurrentPool_FullName =~ s/\.abap$/_.abap/m;
#    print STDERR "      ---> using $CurrentPool_FullName instead\n";
    print STDERR "      ---> data will be added to $CurrentPool_FullName\n";
    $mode = 1; # mode APPEND
  }
  # WriteFile will use the following data ...
  # $CurrentPool_FullName is the name of the class pool "virtual file".
  # $CurrentPool_Content is the content to be witten in the file.
  # $CurrentPool_context[0] is the output list, it will be updated with $CurrentPool_FullName
  # $CurrentPool_context[3] is the metainfo that will be saved in H_UnitInfo
  WriteFile($CurrentPool_FullName, \$CurrentPool_Content, \@CurrentPool_context, $mode);

  $CurrentPool_Name = "";
  $CurrentPool_FullName = "";
  $CurrentPool_Meta = undef;
  $CurrentPool_Content = "";
  @CurrentPool_context = ();
}

sub NewPool($$$$) {
  my $file = shift;
  my $content = shift;
  my $pool = shift;
  my $context = shift;
  if ($CurrentPool_FullName ne "") {
    ClosePool();
  }
 
  # Initialize a specific context ...
  my %H_metaInfo = ();
  #@CurrentPool_context = ( $context->[0], undef, undef, %H_metaInfo );
  @CurrentPool_context = @{$context};

  $CurrentPool_Name = $pool;
  $CurrentPool_FullName = "tmp/".$context->[2]."/CLASSPOOL_$pool.abap"; 
  if (defined $H_UnitInfo{$CurrentPool_FullName}) {
    $CurrentPool_context[3]->{'origin'} = $H_UnitInfo{$CurrentPool_FullName}->{'origin'};
    $CurrentPool_context[3]->{'origin'} .= ",$context->[4]";
  }
  else {
    $CurrentPool_context[3]->{'origin'} = $context->[4];
  }
#print "ORIGIN list = ".$CurrentPool_context[3]->{'origin'}."\n";
  $CurrentPool_Content .= $$content."\n";
}

sub AddPool($$$) {
  my $file = shift;
  my $content = shift;
  my $context = shift;
  $CurrentPool_context[3]->{'origin'} .= ",$context->[4]";
  $CurrentPool_Content .= $$content;
}

sub ABAP_ClassPoolFile($$$) {
  my ($file, $pool, $context) = @_ ;

  my $content = ReadFile($file);
  removeCastExtractorHeader($content, $context);

  if (!defined $content) {
    my $EmptyContent="";
    $context->[3]->{'statut'} = 'UNREADABLE';
    $context->[3]->{'mode'} = $MODE_EXCLUDED;
    WriteFile($context->[1], \$EmptyContent, $context);
  }
  else {
print "POOL : $file\n";
    if ($pool eq $CurrentPool_Name) {
      AddPool($file, $content, $context);
    }
    else {
      NewPool($file, $content, $pool, $context);
    }
  }

  my $nl = () = $content =~ /(\n)/sg ;
  return $nl;
}

sub Preprocess_Abap_AnalysisUnit($$$) {
  my $InputList = shift;
  my $SrcDir = shift;
  my $Format = shift;

  my @OutputList = ();
  my @context = (\@OutputList);

  my @SortedInput = sort @{$InputList};

  my $CurrentDir="";
  for my $file ( @SortedInput ) {

    my $needEncoding = Lib::Sources::needEncodingForExisting($SrcDir, $file); 
	if (defined $needEncoding) {
	  if ($needEncoding ne "unknow") {
		  print STDERR "[SourceUnit] /!\\ using encodage $needEncoding for file name : $file\n";
		  print STDERR "--> before encodage : ".Lib::Data::hexdump_String($file)."\n";
		  # encode file name with the detected encoding
		  $file = Encode::encode($needEncoding, $file);  
		  print STDERR "--> after encodage  : ".Lib::Data::hexdump_String($file)."\n";
	  }
	  else {
		  print STDERR "[SourceUnit] WARNING : file $file seems to be not existing in default encoding\n";
		  print STDERR "--> current encodage : ".Lib::Data::hexdump_String($file)."\n";
	  }
	}

    # Full filename.
    my $fullfilename = $file;
    if ( $SrcDir ne "") {
      $fullfilename = $SrcDir."/".$file ;
    }

    # relative dir + basename
    my ($dir, $name) = $file =~ /^(.*[\\\/])?(.*)/ ;

    if ( !defined $dir) {
      $dir = "";
    }

    if ( defined $name ) {
      my ($type, $pool) = AbapFileType($name);

      #------------------------------------------------------------
      # create tmp path
      #------------------------------------------------------------
      
      #adapt Windows path ...
      $dir =~ s/^(\w):[\\\/]/Drive_$1\// ;

      #adapt Unix path ...
      $dir =~ s/^\//FSROOT\// ;

      if ($dir ne $CurrentDir) {
        mkpath('tmp/'.$dir);
	$CurrentDir = $dir;
      }

      $context[1] = "tmp/$dir/$name"; # full tmp file name.
      $context[2] = "$dir";           # relative directory
      my %H_metaInfo = ();
      $context[3] = \%H_metaInfo;     # Meta-informations ...

      $context[3]->{'type'} = $type;

      $context[4] = $file;			  # Original file name

      # If the file does not belong to a pool and there is a openned pool,
      # then close this pool.
      if ( ($type != 3) && ($CurrentPool_FullName ne "") ) {
      	ClosePool();
      }
      my $nb_lines = undef;
      if ( $type == 0) {
        $nb_lines = ABAP_ExcludeFile($fullfilename, \@context)
      }
      elsif ($type == 1) {
        $nb_lines = ABAP_StandardFile($fullfilename, \@context);
      }
      elsif ($type == 2) {
        $nb_lines = ABAP_WebDynFile($fullfilename, \@context);
      }
      elsif ($type == 3) {
        $nb_lines = ABAP_ClassPoolFile($fullfilename, $pool, \@context);
      }
      my $size = (stat($fullfilename))[7];
      $H_SourceInfo{$fullfilename} = [ 0, $size, $nb_lines ];
    }
  }
  if ($CurrentPool_FullName ne "") {
    ClosePool();
  }

  for my $fic ( @OutputList) {
    print "$fic (".$H_UnitInfo{$fic}->{'mode'}.")\n";
  }

  return \@OutputList;
}

#---------------------------------------------
# - - - - - - - - - - PHP - - - - - - - - - -
#---------------------------------------------

sub PHP_preprocessFile($$) {
  my $fullname = shift;
  my $context = shift;

  my $content = ReadFile($fullname);

  my $data = "";

  my $INSIDE_PHP = 0;
  my $tagPHP_pattern = "";
  my $tagPHP_type = 0;

  while ( $$content =~ /(.*?)(?:(\<\?(?:php)?)|(\?\>))/sg ) {
print "iteration\n";
    if (defined $2) {
      $tagPHP_pattern = $2;
      $tagPHP_type = 1;   # ENTRY tag
    }
    else {
      $tagPHP_pattern = $3;
      $tagPHP_type = 0;   # LEAVE tag
    }

    if ($INSIDE_PHP) {
      if ($tagPHP_type == 0) {
        $data .= $1.$tagPHP_pattern."\n";
        $INSIDE_PHP = 0;
      }
      else {
        print "[PREPRO] error : unauthorized embedded PHP balise.\n";
      }
    }
    else {
      if ($tagPHP_type == 1) {
        $data .= $tagPHP_pattern;
        $INSIDE_PHP = 1;
      }
      else {
        print "[PREPRO] error : lonely end PHP balise.\n";
      }
    }
  }

  WriteFile($context->[1], \$data, $context);

  return undef;
}

sub Preprocess_PHP_AnalysisUnit($$$) {
  my $InputList = shift;
  my $SrcDir = shift;
  my $Format = shift;

  my @OutputList = ();
  my @context = (\@OutputList);

  my @SortedInput = sort @{$InputList};

  my $CurrentDir="";
  for my $file ( @SortedInput ) {

    # Full filename.
    my $fullfilename = $file;
    if ( $SrcDir ne "") {
      $fullfilename = $SrcDir."/".$file ;
    }

    # relative dir + basename
    my ($dir, $name) = $file =~ /^(.*[\\\/])?(.*)/ ;

    if ( !defined $dir) {
      $dir = "";
    }

    #------------------------------------------------------------
    # create tmp path
    #------------------------------------------------------------
      
    #adapt Windows path ...
    $dir =~ s/^(\w):[\\\/]/Drive_$1\// ;

    #adapt Unix path ...
    $dir =~ s/^\//FSROOT\// ;

    if ($dir ne $CurrentDir) {
      mkpath('tmp/'.$dir);
      $CurrentDir = $dir;
    }

    $context[1] = "tmp/$dir/$name"; # full tmp file name.
    $context[2] = "$dir";           # relative directory
    my %H_metaInfo = ();
    $context[3] = \%H_metaInfo;     # Meta-informations ...

    $context[3]->{'origin'} = $fullfilename;
    $context[3]->{'mode'} = $MODE_NORMAL;

    my $nb_lines = undef;
    $nb_lines = PHP_preprocessFile($fullfilename, \@context);

    my $size = (stat($fullfilename))[7];
    $H_SourceInfo{$fullfilename} = [ 0, $size, $nb_lines ];
  }

  for my $fic ( @OutputList) {
    print "$fic (".$H_UnitInfo{$fic}->{'mode'}.")\n";
  }

  return \@OutputList;
}



1;
