#----------------------------------------------------------------------#
#                         @ISOSCOPE 2008                               #
#----------------------------------------------------------------------#
#               Auteur  : ISOSCOPE SA                                  #
#               Adresse : TERSUD - Bat A                               #
#                         5, AVENUE MARCEL DASSAULT                    #
#                         31500  TOULOUSE                              #
#               SIRET   : 410 630 164 00037                            #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Framework
# Description: Protocole de communication montante vers l'IHM

use strict;
use warnings ;

use IO::Handle;

package Progression;

use SourceUnit;

# Name of the Original source file, in case of SPLIT mode...
my $CurrentSourceFile = undef;
my $RemainingUnits = 0;

# Name of the current concatened file in case of CONCAT mode...
my $CurrentConcatenedFileName = undef;


# Creation de l'objet permettant de communiquer avec l'IHM.
sub new ($)
{
  my $perlClass=shift;
  my ($ProgressionFilename)=@_;

  my $self = {};

  bless $self;

  my $handle ;
  open ( $handle, '>:raw',$ProgressionFilename) or die "Ne peut creer le fichier $ProgressionFilename $! $@ $?\n";
  $handle->autoflush(1);

  $self->{'sock'}=$handle;
  $self->{'appliN'}=-1;
  $self->{'listN'}=-1; # En mode non IHM pas de concept appli.

  my %notanalyzedStat = ();
  $self->{'notanalyzedStat'} = \%notanalyzedStat;

  return $self;
}



sub GetTimeStamp()
{
 # recuperation de la date et de l'heure par localtime
 my ($S, $Mi, $H, $J, $Mo, $A) = (localtime) [0,1,2,3,4,5];
 return  sprintf('%04d-%02d-%02d_%02d:%02d:%02d',
        eval($A+1900), eval( $Mo +1) , $J, $H, $Mi, $S);
}


sub SendMessage($$)
{
  my ( $self, $refCommonMessage) = @_ ; 
  my $sock = $self->{'sock'};

  my @message = (  GetTimeStamp()  );
  push @message , @{$refCommonMessage};

  my $buffer = '';
  $buffer = GetTimeStamp() .';' ;
  $buffer = join ('; ', @message);
                
#print STDERR $buffer . "\n";
  print $sock $buffer . "\n" ;
}

# Informations fichiers

sub ProgressBeginFile($$)
{
  my ( $self, $filename ) = @_ ;

  SourceUnit::open_CurrentUnit($filename);

  my $UnitFilename  = undef;

  # Default Values correspond to the NORMAL MODE.
  my $needFileModeData = 1;
  my $needAnalysisUnitModeData = 0;

  #-----------------------------------------
  # CONCAT MODE MANAGEMENT 
  #-----------------------------------------
  #
  if ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_CONCAT) {
    # In this mode, Begin info of the underlying original source(s) file(s) are not sent yet.
    $needFileModeData = 0;

    # Record the name of the current concatened file name... 
    $CurrentConcatenedFileName = $filename;

    $self->{'concatStart'} = time();
    $self->{'concatN'}++;
    my $n = $self->{'concatN'};
    my @commonData = ( 'concat', $n , 0, 'filename', $filename  );
    $self->SendMessage(\@commonData);
  }

  #-----------------------------------------
  # SPLIT MODE MANAGEMENT : initilization of a new split.
  #-----------------------------------------

  elsif ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_SPLIT) {

    $needAnalysisUnitModeData = 1;

    # In SPLIT mode, the filename parameter is a unit filename, not
    # the original filename. So, storing it in an appropriate variable.
    $UnitFilename  = $filename ;

    # In this mode, $filename is an Analysis Unit, so we should retrieve the
    # original source filename.
    if ( ! defined $CurrentSourceFile) {

      # As it is a new original source file, this unit is the first associated. 
      # So, RAZ the counter.
      $self->{'unitN'} = -1;

      # Record the number of error of each class encountered in the analysis of each
      # analysis unit.
      $self->{'abortClass_0'}=0;
      $self->{'abortClass_1'}=0;
      $self->{'abortClass_2'}=0;

      # Retrieves the associated original Source file.
      $CurrentSourceFile = SourceUnit::get_SourceFile($filename) ;
      $RemainingUnits = SourceUnit::get_SourceNbUnits($CurrentSourceFile) ;

      # Filename to be used for NORMAL MODE infos is the corresponding source file
      # of the unit being treated. 
      $filename = $CurrentSourceFile;
    }
    else {
      # If Source file is already being treated no need to log file infos ...
      $needFileModeData = 0;
    }
  }

  #-----------------------------------------
  # NORMAL MODE : Progression info for source file
  #-----------------------------------------

  elsif ( ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_NORMAL) ||
          ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_EXCLUDED) ) {
	# In NORMAL MODE, files are not concatened nor splited, but they can be in the temporary directory for
	# source that have been prepared ... (TSQL, ABAP, ..)
	# check if an original source file is available, else work with the default filename.
    my $originalName = SourceUnit::get_UnitInfo($filename, 'origin');
    if ( defined $originalName) {
		$filename = $originalName;
	}
  }

  if ($needFileModeData) {
    $self->{'fileN'}++;
    my $n = $self->{'fileN'};

    my $nb_cible= $self->{'nb_cible'};
    $self->{'fileStart'} = time();

    my @commonData = ( 'file', $n , 0, 'filename', $filename );

    $self->SendMessage(\@commonData);

    if ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_SPLIT) {
      my @commonData = ( 'file', $n , 0, 'nb_units', $RemainingUnits  );
      $self->SendMessage(\@commonData);
    }
  }

  #-----------------------------------------
  # SPLIT MODE : Progression info for split unit
  #-----------------------------------------

  if ( $needAnalysisUnitModeData) {
    $self->{'unitStart'} = time();
    $self->{'unitN'}++;
    my $n = $self->{'unitN'};
    my @commonData = ( 'unit', $n , 0, 'filename', $UnitFilename  );
    $self->SendMessage(\@commonData);
    $RemainingUnits --;
  }

}

sub ProgressLineNumberFile($$)
{
  my ( $self, $lines) = @_ ; 

  #-------------------------------------
  # SPLIT MODE
  #-------------------------------------
  if ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_SPLIT) {
    my $n = $self->{'unitN'};
    my $laps = time() - $self->{'unitStart'} ;
    my @commonData = ( 'unit', $n , $laps, 'lines' , $lines );
    $self->SendMessage(\@commonData);
  }
  #-------------------------------------
  # NORMAL MODE
  #-------------------------------------
  elsif ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_NORMAL) {
    my $n = $self->{'fileN'};
    my $laps = time() - $self->{'fileStart'} ;
    my @commonData = ( 'file', $n , $laps, 'lines' , $lines );
    $self->SendMessage(\@commonData);
  }
  #-------------------------------------
  # CONCAT MODE
  #-------------------------------------
  elsif ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_CONCAT) {
	  # NO NEED IN THIS MODE.
  }
}

#sub ProgressBaseNameFile($$)
#{
#  my ( $self, $basename) = @_ ; 
#
#  #-------------------------------------
#  # SPLIT MODE
#  #-------------------------------------
#  if ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_SPLIT) {
#    $basename = $CurrentSourceFile.'#'.$basename;
#    my $n = $self->{'unitN'};
#    my $laps = time() - $self->{'unitStart'} ;
#    my @commonData = ( 'unit', $n , $laps, 'basename' , $basename );
#    $self->SendMessage(\@commonData);
#  }
#  #-------------------------------------
#  # NORMAL MODE
#  #-------------------------------------
#  else {
#    my $n = $self->{'fileN'};
#    my $laps = time() - $self->{'fileStart'} ;
#    my @commonData = ( 'file', $n , $laps, 'basename' , $basename );
#    $self->SendMessage(\@commonData);
#  }
#}
#
#sub ProgressBytesSizeFile($$)
#{
#  my ( $self, $bytesSize) = @_ ; 
#
#  my $needFileInfo = 1;
#  #-------------------------------------
#  # SPLIT MODE
#  #-------------------------------------
#  if ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_SPLIT) {
#
#    $needFileInfo = 0;
#
#    my $n = $self->{'unitN'};
#    my $laps = time() - $self->{'unitStart'} ;
#    my @commonData = ( 'unit', $n , $laps, 'size' , $bytesSize );
#    $self->SendMessage(\@commonData);
#
#    if ( ! $RemainingUnits ) {
#      $bytesSize = SourceUnit::get_SourceSize($CurrentSourceFile) ;
#      $needFileInfo = 1;
#    }
#  }
#
#  #-------------------------------------
#  # SPLIT MODE
#  # (or SPLIT MODE when the last unit went just to been analyszed).
#  #-------------------------------------
#  if ($needFileInfo ) {
#    my $n = $self->{'fileN'};
#    my $laps = time() - $self->{'fileStart'} ;
#    my @commonData = ( 'file', $n , $laps, 'size' , $bytesSize );
#    $self->SendMessage(\@commonData);
#  }
#}

sub ProgressEndFile($$)
{
  my ( $self, $basename, $bytesSize, $abortClass, $abortNumber) = @_ ; 

  my @commonData;

  #-------------------------------------
  # SPLIT MODE
  #-------------------------------------
  if ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_SPLIT) {
    my $laps = time() - $self->{'unitStart'} ;
    my $n = $self->{'unitN'};
    # Basename info
    #my $unitBasename = $CurrentSourceFile.' ('.$basename.')';
    @commonData = ( 'unit', $n , $laps, 'basename' , $basename );
    $self->SendMessage(\@commonData);

    # Size info
    @commonData = ( 'unit', $n , $laps, 'size' , $bytesSize );
    $self->SendMessage(\@commonData);
    
    # abort info
    @commonData = ( 'unit', $n , $laps, 'abort', $abortClass . '_' . $abortNumber );
    $self->SendMessage(\@commonData);

    # Number of unit analysis result in each class (OK, partially, not analyzed)
    if ( $abortClass == 1 ) {
      $self->{'abortClass_1'}++ ;
    }
    elsif ( $abortClass == 2 ) {
      $self->{'abortClass_2'}++ ;
    }
    elsif ( $abortClass == 3 ) {
      $self->{'abortClass_3'}++ ;
    }

    # If the last Unit of a source file has been analyzed, then write de info
    # about this original source file.
    if ( ! $RemainingUnits ) { 

      my $n = $self->{'fileN'};
      my $laps = time() - $self->{'fileStart'} ;
      $self->{'notanalyzedStat'}->{$abortNumber}++;

      # the nbline writing in function ProgressEndFile() is specific to
      # the SPLIT mode. In NORMAL mode, this is done in the process_file()
      # function.
      # FIXME : in future evolution, this could be here for both mode ...
      my $nblines = SourceUnit::get_SourceNbLines($CurrentSourceFile);
      @commonData = ( 'file', $n , $laps, 'lines' , $nblines );
      $self->SendMessage(\@commonData);

      # basename info
      @commonData = ( 'file', $n , $laps, 'basename' , $CurrentSourceFile );
      $self->SendMessage(\@commonData);          
      # size infos

      # In SPLIT mode, the FILE info are writed only when there is
      # no more unit to process for the correspondind original source file.
      # In this case we should replace the unit file size by the original source file size !!
      $bytesSize = SourceUnit::get_SourceSize($CurrentSourceFile) ;
      @commonData = ( 'file', $n , $laps, 'size' , $bytesSize );
      $self->SendMessage(\@commonData);

      # abort info
   
      # The abort cause is set to Erreur::ABORT_CAUSE_ANALYSIS_UNIT_MODE (value=11).
      # for Signification, see Erreur.pm
      #
      # Remain : class 1 is "OK"
      #          class 2 is "interrupted"
      #          class 3 is "not analyzable"
      
      if (SourceUnit::get_SourceNbUnits($CurrentSourceFile) > 1) {
		$abortNumber = 11;
	  }

      if ( ($self->{'abortClass_1'} == 0) &&
           ($self->{'abortClass_2'} == 0) ) {
	# Not analyzed
        $abortClass = 3;
      }
      elsif ( $self->{'abortClass_2'} != 0) {
	# partialy analyzed
        $abortClass = 2;
      }
      else {
	# OK
        $abortClass = 1;
      }
      @commonData = ( 'file', $n , $laps, 'abort', $abortClass . '_' . $abortNumber );
      $self->SendMessage(\@commonData);

      # This step is the end of the analysis of the original source file.
      # The memorized name should then be reseted.
      $CurrentSourceFile = undef;
    }
  }
  #-------------------------------------
  # CONCAT MODE
  #-------------------------------------
  elsif ( SourceUnit::get_SourceMode() == $SourceUnit::MODE_CONCAT) {

    if (defined $CurrentConcatenedFileName) {

      my @ConcatenedList = SourceUnit::get_ConcatenedFiles($CurrentConcatenedFileName);
  
      # End of the analysis this file ...
      $CurrentConcatenedFileName = undef;
  
      # For each original concatened files, send "virtual progression" info.
      for my $ConcatFile ( @ConcatenedList) {

        my $basename = $ConcatFile;
	$basename =~ s/.*[\\\/]//;
        my $nblines = SourceUnit::get_SourceNbLines($ConcatFile);
        my $bytesSize = SourceUnit::get_SourceSize($ConcatFile);

	if (! defined $nblines ) { $nblines = "unknow"; print STDERR "WARNING : unknow nb lines for $ConcatFile\n";}
	if (! defined $bytesSize ) { $bytesSize = "unknow"; print STDERR "WARNING : unknow size for $ConcatFile\n";}

        $self->{'fileN'}++;
        my $n = $self->{'fileN'};
        my $laps = 'N/A';
        $self->{'notanalyzedStat'}->{$abortNumber}++;
  
        @commonData = ( 'file', $n , 0, 'filename', $ConcatFile  ); 
        $self->SendMessage(\@commonData);

        # basename info
        @commonData = ( 'file', $n , $laps, 'basename' , $basename );
        $self->SendMessage(\@commonData);
  
        # lines infos
        @commonData = ( 'file', $n , $laps, 'lines' , $nblines );
        $self->SendMessage(\@commonData);
            
        # size infos
        @commonData = ( 'file', $n , $laps, 'size' , $bytesSize );
        $self->SendMessage(\@commonData);
  
        # abort info
        @commonData = ( 'file', $n , $laps, 'abort', $abortClass . '_' . $abortNumber );
        $self->SendMessage(\@commonData); 
      }

      my $laps = time() - $self->{'concatStart'} ;
      my $n = $self->{'concatN'};
      # Basename info
      @commonData = ( 'concat', $n , $laps, 'basename' , $basename );
      $self->SendMessage(\@commonData);

      # Size info
      @commonData = ( 'concat', $n , $laps, 'size' , $bytesSize );
      $self->SendMessage(\@commonData);
    
      # abort info
      @commonData = ( 'concat', $n , $laps, 'abort', $abortClass . '_' . $abortNumber );
      $self->SendMessage(\@commonData);
    }
  }
  #-------------------------------------
  # NORMAL MODE
  #-------------------------------------
  else {

    my $n = $self->{'fileN'};
    my $laps = time() - $self->{'fileStart'} ;
    $self->{'notanalyzedStat'}->{$abortNumber}++;

    # basename info
    @commonData = ( 'file', $n , $laps, 'basename' , $basename );
    $self->SendMessage(\@commonData);


    # lines infos
    #@commonData = ( 'file', $n , $laps, 'lines' , $nblines );
    #$self->SendMessage(\@commonData);
          
    # size infos
    if (! defined $bytesSize) {
      $bytesSize = "unknow";
    }
    @commonData = ( 'file', $n , $laps, 'size' , $bytesSize );
    $self->SendMessage(\@commonData);

    # abort info
    @commonData = ( 'file', $n , $laps, 'abort', $abortClass . '_' . $abortNumber );
    $self->SendMessage(\@commonData);
  }

  SourceUnit::close_CurrentUnit();
}

# Informations liste

sub ProgressBeginList($$$)
{
  my ( $self, $nbFiles, $listName ) = @_ ;

  $self->{'listN'}++;
  my $n = $self->{'listN'};
  $self->{'fileN'}=-1;

  $self->{'listStart'} = time();

  my @commonData = ( 'list', $n , 0, 'listname' , $listName || '' );
  $self->SendMessage(\@commonData);

  #-------------------------------------
  # If source have been redefined (REDEFINE_ON) ...
  # (The nbFiles parameter indicates the number of units, not the number of original source files.
  # So we should retrieve this information ...
  #-------------------------------------
  if ( SourceUnit::get_AnalysisMode() == $SourceUnit::REDEFINE_ON) {
    # listName is the name of the list (see call of ProgressBeginList)
    if ($listName !~ /^Ana/m) {
		$listName = "Ana$listName";
	}
    $nbFiles = SourceUnit::get_AnalyzerNbFile($listName);
  }

  @commonData = ( 'list', $n , 0, 'nbfiles' , $nbFiles );
  $self->SendMessage(\@commonData);
}

sub ProgressEndList($$)
{
  my ( $self, $info) = @_ ; 
  my $n = $self->{'listN'};
  my $laps = time() - $self->{'listStart'} ;
  my @commonData = ( 'list', $n , $laps, 'info', $info );
  $self->SendMessage(\@commonData);
}

# Informations Application

sub ProgressBeginAppli($$$)
{
  my ( $self, $nbFiles, $csvname ) = @_ ;

  $self->{'appliN'}++;
  my $n = $self->{'appliN'};
  $self->{'listN'}=-1;

  $self->{'appliStart'} = time();

  my @commonData = ( 'appli', $n , 0, 'nbfiles' , $nbFiles );
  $self->SendMessage(\@commonData);

  @commonData = ( 'appli', $n , 0, 'CSV' , $csvname );
  $self->SendMessage(\@commonData);
}

sub ProgressEndAppli($$$)
{
  my ( $self, $info, $filename) = @_ ; 
  my $n = $self->{'appliN'};
  my $laps = time() - $self->{'appliStart'} ;

  my @keys = keys(%{$self->{'notanalyzedStat'}});
  my @vals = map  { $_.':'.$self->{'notanalyzedStat'}->{$_} } @keys;

  my @commonData = ( 'appli', $n , $laps, 'notanalyzed' , join (' ', @vals)  );
  $self->SendMessage(\@commonData);

  @commonData = ( 'appli', $n , $laps, 'stop' , $filename);
  $self->SendMessage(\@commonData);

  @commonData = ( 'appli', $n , $laps, 'info' , $info );
  $self->SendMessage(\@commonData);
}

sub ProgressStopAppli($$)
{
  my ( $self, $info) = @_ ; 
  my $n = $self->{'appliN'};
  my $laps = time() - $self->{'appliStart'} ;

  my @keys = keys(%{$self->{'notanalyzedStat'}});
  my @vals = map  { $_.':'.$self->{'notanalyzedStat'}->{$_} } @keys;

  my @commonData = ( 'appli', $n , $laps, 'stop' , '');
  $self->SendMessage(\@commonData);

  @commonData = ( 'appli', $n , $laps, 'info' , $info );
  $self->SendMessage(\@commonData);
}


1;
