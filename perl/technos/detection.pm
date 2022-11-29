package technos::detection;

use warnings;
use strict;

use technos::id;
use technos::config;
use technos::check;
use technos::lib;
use CheckObjHpp;

sub storeFile($$) {
  my $filenode = shift;
  my $potentialTechnos = shift;

  if ( scalar @$potentialTechnos > 0) {
    # - add to potential list.
    technos::lib::addPotentialFileTechno($filenode, $potentialTechnos);
  }
  else {
    # - add to unknow list.
    technos::lib::addUnknowFileTechno($filenode);
  }
}

sub declareFile($) {

  my $complete_path = shift;

#  my ($ext) = $$complete_path =~ /\.([^\.\\\/]*)$/;

  my $filenode = technos::lib::createFileNode($complete_path);

  # check if the file is a binary library
  # if yes, it will managed as such, and will not be involved in the techno discoverer process.
  if (! checkBinaryLib($filenode)) {

	# Not a binary lib !!!!
	# ==> declare this new file for techno discovering process.
	technos::lib::newFile($complete_path, $filenode);

	my $tooBigSize = technos::config::isTooBig($complete_path);
	if ($tooBigSize) {
		technos::lib::addFileError("too big", $filenode, $tooBigSize);
	}
	elsif ( technos::config::isExcludedExtension($filenode->[FILE_EXTENSION])) {
		technos::lib::addFileError("excluded extension", $filenode, $filenode->[FILE_EXTENSION]);
	}
	else {
		my $potentialTechnos;
		my $resolved = 0;
		($potentialTechnos, $resolved) = checkFromHistory($filenode);
		# Try if the techno can be deduce from name. If yes, this would be an 
		# optimization because there would be no potential techno, and then no
		# checking for validating them...
    
		if (! $resolved) {
			$potentialTechnos = checkFromName($filenode);
		}

		# @potentialTechnos the list of the potential technos to be resolved.
		# - EMPTY means that no techno is associated with this file extension.
		# - UNDEFINED means that the techno has already been completly resolved
		#   by name or extension, so there is nothing to do with it.
		if (defined $potentialTechnos) {
			storeFile($filenode, $potentialTechnos);
		}
	}
  }
}

sub initCacheContext();

sub start() {
  initCacheContext();
  technos::lib::initProgression();
  technos::check::init_check();
}

#--------------------------------------------------
#---------------- CHECK POTENTIAL TECHNO ----------
#--------------------------------------------------

# The first techno that matches will be the one.
sub tryDiscrimination($$$) {
  my $file = shift;
  my $technos = shift;
  my $content = shift;

  # For each potential techno
  # -------------------------
  for my $techno (keys %$technos) {

    my $res = technos::lib::checkExclusiveTechno($techno, $content);

    # The callback returns :
    #     1 if the techno is validated.
    #    -1 if the techno is excluded.
    # undef else. 
    if (defined $res) {
      if ($res == 1) {
        # OK -> techno is confirmed ...
        # Set this only techno to the file.
	technos::lib::resetFilePotentialTechnos($file);
        technos::lib::setFileTechno($file, $techno, "exclusive check");
      }
      else {
        # KO -> techno is invalided ...
        # remove from list of potential technos. 
        technos::lib::removeFileTechno($file, $techno);
      }

      if ( ! technos::lib::isFilePotentialTechnosRemaining($file)) {
        # the file is entirely resolved ...
        $file = undef; 
        # do not check other potential technos for the file.
        last;
      }
    }
  }

  # the caller should know if $file has been set to undef or not !
  return $file;
}

sub tryTechnosExtraction($$$) {
  my $file = shift;
  my $technos = shift;
  my $content = shift;

  my %contentTypes = ();
  # collect contents types ...
  for my $techno (keys %$technos) {
    my $type = technos::lib::getType($techno);
    if (defined $type) {
      $contentTypes{$type} = 1;
    }
  }

  # Call corresponding callbacks ...
  for my $type (keys %contentTypes) {
    my $callback = technos::lib::getExtractionCallback($type);
    my ($TechnosPresent, $TechnosAbsent) = $callback->($content, $file->[FILE_EXTENSION]);

    for my $TechPres (@$TechnosPresent) {
      if (defined $technos->{$TechPres}) {
	# Resolve the techno only if it was in a potential techno associated
	# with the extension of the file.
	# If the callback return an unsupported techno, it is simply forgotten.
        technos::lib::setFileTechno($file, $TechPres, "techno extraction");
      }
    }

    for my $TechAbs (@$TechnosAbsent) {
      if (defined $technos->{$TechAbs}) {
	# if the techno is not a potential techno associated with the extension
	# of the file, do not remove it, it would produced something undetermined.
	# TODO : the robustness could be reported in removeFileTechno() ...
        technos::lib::removeFileTechno($file, $TechAbs);
      }
    }

    if ( ! technos::lib::isFilePotentialTechnosRemaining($file)) {
      # the file is entirely resolved ...
      $file = undef; 
      # do not check other potential technos for the file.
      last;
    }
  }

  # the caller should know if $file has been set to undef or not !
  return $file;
}

sub tryVadidation($$$) {
  my $file = shift;
  my $technos = shift;
  my $content = shift;

  # For each potential techno
     # -------------------------
     for my $techno (keys %$technos) {

	 # skip if the techno has already been checked in "discrimination"
	 # routine (discrimination algo is based on exclusiveness of a techno).
         next if (technos::lib::isExclusiveTechno($techno));

         my $res = technos::lib::checkTechno($techno, $content);

	 # The callback returns :
	 #     1 if the techno is validated.
	 #    -1 if the techno is excluded.
	 # undef else. 
	 if (defined $res) {
	   if ($res == 1) {
	     # OK -> techno is confirmed ...
	     # Set techno to the file.
	     technos::lib::setFileTechno($file, $techno, "simple check");
	   }
	   else {
	     # KO -> techno is invalided ...
	     # remove from list of potential technos. 
	     technos::lib::removeFileTechno($file, $techno);
	   }

	   if ( ! technos::lib::isFilePotentialTechnosRemaining($file)) {
	     # the file is entirely resolved ...
             $file = undef; 
	     # do not check other potential technos for the file.
	     last;
	   }
	 }
     }

     # the caller should know if $file has been set to undef or not !
     return $file;
}

# If there is only one potential techno and no techno have been found,
# then set the potential techno as the techno for the file.
sub checkDefaultTechno($) {
  my $filenode = shift;

  my @potentialTechnos = keys %{$filenode->[FILE_POTENTIAL_TECHNOS]};

  if (scalar @potentialTechnos == 1) {

    if (technos::config::isDefaultResolutionAllowed($filenode->[FILE_EXTENSION], $potentialTechnos[0])) {
	    technos::lib::setFileTechno($filenode,
  	            $potentialTechnos[0],
	            "default check");
      return undef;
    }
  }
  return $filenode;
}

sub checkFromHistory($) {
	my $filenode = shift;
	my $resolved = 0;
	
	my $history = technos::lib::getHistory($filenode);
	
	if (defined $history) {
		my $technos = $history->[0];
		if (defined $technos) {
			$resolved = 1 if (scalar @$technos > 0);
			for my $tech (@$technos) {
				technos::lib::setFileTechno($filenode,
  	            $tech,
	            "from history");
			}
		}
	}
	return (undef, $resolved)
}

sub checkFromExtension($) {
  my $filenode = shift;

  my $ext = $filenode->[FILE_EXTENSION];

  my $technos = technos::config::getPotentialTechnosFromExtension($ext);

  if (scalar @$technos == 1) {
    my $tech = $technos->[0];
    if (technos::config::isDirectResolutionAllowed($ext, $tech)) {
      technos::lib::setFileTechno($filenode, $tech, "from extension");
      return undef;
    }
  }
  return $technos;
}

sub checkFromName($) {
  my $filenode = shift;

  my @none = ();

  my $ext = $filenode->[FILE_EXTENSION];

  my $callback = technos::config::getNameCheckingCallback($ext);

  my $techno;

  if (defined $callback) {
    $techno = $callback->($filenode, $ext);
    if (defined $techno) {
      # the techno has been detected from the name.
      technos::lib::setFileTechno($filenode, $techno, "from name");
      return undef;
    }
  }

  # Try finding technos from the extension.
  return checkFromExtension($filenode);
}

sub checkBinaryLib($) {
	my $filenode = shift;

	my $ext = $filenode->[FILE_EXTENSION];

	if (technos::config::isBinaryLib($ext)) {
		if (technos::lib::addBinaryLib($filenode) == 1) {
			return 1;
		}
	}

	return 0;
}


###############################################################################
#  CHECK POTENTIAL TECHNOS
###############################################################################
sub checkPotentialTechno() {

  technos::lib::tagTime("BEGIN checkPotentialTechno");

  my $PotentialFilesTechnos = technos::lib::getPotentialTechnoFileList();

  my $nbTotalPotential = scalar (@{$PotentialFilesTechnos});
  my $nbProcessedPotential = 0;

  technos::lib::phase_checking_potential($nbTotalPotential);

  # For each file with POTENTIAL techno
  # -----------------------------------
  for my $file (@{$PotentialFilesTechnos}) {
     my $technos = technos::lib::getFilePotentialTechnos($file);
     
     $nbProcessedPotential++;
     my $filePath = technos::lib::getFilePath($file);
     technos::lib::SEND_GUI("CHECK_POTENTIAL;\"$filePath\";$nbProcessedPotential;$nbTotalPotential");
     
#print "\n*** FILE ".$file->[FILE_NAME]."\n";
     # try checking content if :
     #     - there is more than one potential techno
     #     - OR there is 1 potential techno, but the content validation is required.
     my @techlist = keys %$technos;

     if (  (scalar (@techlist) > 1) ||
             ((scalar (@techlist) == 1) &&
  	      ( technos::config::isContentCheckingRequired($file->[FILE_EXTENSION]), $techlist[0])
             ) ) {

         my $content =  technos::lib::getFileContent($file);

         if (defined $content) {

           # Discrimination should be checked first because it is exclusive :
           # if it matches no more tests should be done behind.
           if (defined $file) {
             $file = tryDiscrimination($file, $technos, $content);
           }

           # Extract technos if possible.
           if (defined $file) {
             $file = tryTechnosExtraction($file, $technos, $content);
           }

           # Validation check all potential technos one after the other.
           if (defined $file) {
             $file = tryVadidation($file, $technos, $content);
           }
         }
         else {
	   $file = undef;
         }
     }
     

     # IF IT REMAIN POTENTIAL TECHNOS.
     if (defined $file) {

       # IF SOME TECHNOS HAVE BEEN FOUND FOR THE FILE
       if ((scalar keys %{$file->[FILE_TECHNOS]} > 0) or
           (scalar keys %{$file->[FILE_EXCLUDED_TECHNOS]} > 0)) {
       #
       # Remove useless potential techno.
       # If one (or more) techno have been found for this file but there remain
       # potential technos, we consider these potential technos are useless. The
       # file should be removed from potential techno list for clarification.
       # Indeed, in mind, the list of potential techno file is considered as
       # a list of unresolved files and this intuitive concept would become
       # false if we keep in potential techno list some files that have been
       # resolved.

       # So, remove from list of file with potential technos. Eventual remaining
       # potential techno for this file are no more considered.
         technos::lib::clearFileTechnos($file);
         $file = undef;
       }
       
       # IF NONE TECHNOS HAVE BEEN FOUND FOR THE FILE
       else {
	 # If possible, resolve to the only possible techno
         $file = checkDefaultTechno($file);
       }
     }

     technos::lib::incProcessedProgression();

  }

  # remove entries that have been deleted by setting to undef.
  @{$PotentialFilesTechnos} = grep defined, @{$PotentialFilesTechnos};
  
  technos::lib::traceEvent("Check potential techno");
  
  technos::lib::printResolvedStat();
}  

###############################################################################
#  CHECK WITHOUT POTENTIAL TECHNOS
###############################################################################

sub checkWithoutPotentialTechno() {

  technos::lib::tagTime("BEGIN checkWithoutPotentialTechno");

  my $UnknowFilesTechnos = technos::lib::getUnknowTechnoFileList();
  
  my $nbTotalUnknown = scalar (@{$UnknowFilesTechnos});
  my $nbProcessedUnknown = 0;

  technos::lib::phase_checking_without_potential($nbTotalUnknown);

  # For each file without potential techno
  # --------------------------------------
  for my $file (@{$UnknowFilesTechnos}) {
    technos::lib::incProcessedProgression();
    
    $nbProcessedUnknown++;
    my $filePath = technos::lib::getFilePath($file);
    technos::lib::SEND_GUI("CHECK_UNKNOWN;\"$filePath\";$nbProcessedUnknown;$nbTotalUnknown");

    my $techs = technos::lib::getTechnosWithAnyExt();
   
    # Keep only contextual technos
    $techs = technos::config::getContextualTechnos($techs);

    # if none technos are contextual, do not check content ... 
    if (scalar @$techs == 0) {
      # set out of context
      technos::lib::setFileOutOfContext($file);
      
      # do not remove from  "unknow" list because we don't know if the
      # file is out of context because we don't know its techno !!! 
      
      # $file = undef;
    }
    else {
      my $content =  technos::lib::getFileContent($file);
        
      if (defined $content) {
        
        # FIXME : get technos in the neighboring (same dir).
        # if FOUND : check these technos.
        # FIXME : try checking callback for files without extension.
        
        # Fix bug performence with lots of empty lines into file content
        $$content =~ s/^\s*\n$//mg;
        
        for my $techno (@{technos::lib::getTechnosWithAnyExt()}) {

          my $res = technos::lib::checkTechno($techno, $content);

	  if (defined $res) {
	     if ($res == 1) {
	       # OK -> techno is confirmed ...
	       # Set techno to the file.
	       technos::lib::resolveFileTechno($file, $techno, "from unknow extension");

	       # the file techno resolved ...
           $file = undef;
	       # do not check other potential technos for the file.
	       last;
	     }
	   }
        }
      }
      else {
        $file = undef;
      }
    }
  }

  # remove entries that have been deleted by setting to undef.
  @{$UnknowFilesTechnos} = grep defined, @{$UnknowFilesTechnos};
  
  technos::lib::traceEvent("Check without potential techno");
  
  technos::lib::printResolvedStat();
}

###############################################################################
#  CHECK FROM CONTEXT
###############################################################################

my %cacheDirExtTechno = ();

sub initCacheContext() {
	%cacheDirExtTechno = ();
}

sub addCacheContext($$$) {
	my $dirnode = shift;
	my $ext = shift;
	my $tech = shift;
	
	if (! exists $cacheDirExtTechno{$dirnode}) {
		my %empty = ();
		$cacheDirExtTechno{$dirnode} = \%empty;
	}
	
	if (! exists $cacheDirExtTechno{$dirnode}{$ext}) {
		my %empty = ();
		$cacheDirExtTechno{$dirnode}{$ext} = \%empty;
	}
	
	$cacheDirExtTechno{$dirnode}{$ext} = $tech;
}

sub getCacheContext($$) {
	my $dirnode = shift;
	my $ext = shift;
	
	if (exists $cacheDirExtTechno{$dirnode}) {
		if (exists $cacheDirExtTechno{$dirnode}{$ext}) {
			return $cacheDirExtTechno{$dirnode}{$ext};
		}
	}
	return undef;
}

sub getTechnosFromDir($$) {
  my $dirnode = shift;
  my $ext = shift;

# FIXME : optimization : memorizes the result for a couple of dir/ext
  my $cacheContextTechnos = getCacheContext($dirnode, $ext);
  if (defined $cacheContextTechnos) {
	  return $cacheContextTechnos;
  }

  my %technos = ();

  my $fileslist = technos::lib::getDirFiles($dirnode);

  for my $file (@$fileslist) {
	if ( defined $file->[0]) {
	
		# escaped special characters that can appear in extentions.
		# for example "h++" (where "+" is a regexp quantifier). 
		my $quoted_ext = quotemeta $ext;
		
		# if the file matches the asked extension ...
        if ($file->[0] =~ /\.$quoted_ext$/) {

			# get the technos associated with this file.
			my $techs = technos::lib::getFileTechnos($file);
			for my $tech (keys %{$techs} ) {
				$technos{$tech} = 1;
			}
		}
	}
	else {
		technos::lib::OUTPUT "FIXME - bad file node ...!\n";
		return;
	}
  }
    
  addCacheContext($dirnode, $ext, \%technos);
    
  return \%technos;
}

sub __checkWithContextFromPotential($$) {
        my $filenode = shift;
        my $dirnode = shift;
        
		
		my $ext = $filenode->[FILE_EXTENSION];
		my $resolvedTechno = undef;
		
		if (technos::config::hasPotentialContextPriority($ext) ) {
			# apply a resolution based on the priority between several potential techno.
			$resolvedTechno = technos::config::resolvePotentialwithContextPriority($filenode->[FILE_POTENTIAL_TECHNOS], $dirnode->[DIR_TECHNOS], $ext);
		}
		else {
			
			# Default resolution algo : search among the potential techno of the file
			# if there is one that is already detected in the directory, AND NOT THE OTHER.
			my $technoFoundInDir = undef;
			
			for my $potech (keys %{$filenode->[FILE_POTENTIAL_TECHNOS]}) {
				if ($dirnode->[DIR_TECHNOS]->{$potech}) {
					if (defined $technoFoundInDir) {
						# several techno already detected in the directory ==> cannot statute ==> set to undef.
						$technoFoundInDir = undef;
						last;
					}
					else {
						$technoFoundInDir = $potech;
					}
				}
			}
			$resolvedTechno = $technoFoundInDir;
		}
		
		return $resolvedTechno;
}

use constant COMMON_POTECHS => 0;
use constant FILES_IDX => 1;

sub __checkWithContextFromPotentialStatistics($) {
	my $files = shift;
	
	my %dirs = ();
	
	my $file_idx = -1;
	for my $filenode (@$files) {
		$file_idx++;
#print STDERR "FILE : $filenode->[FILE_NAME]\n";
		my $ext = $filenode->[FILE_EXTENSION];
		
		if (technos::config::isStatResolution_FromPotential_Allowed_For_Extension($ext)) {
			my $dirnode = technos::lib::getFileDir($filenode);
			my $potech = $filenode->[FILE_POTENTIAL_TECHNOS];

			# ** Manage stats technos for each extension in each directory
			
			# create dir entry if needed
			if (! defined $dirs{$dirnode}) {
				$dirs{$dirnode} = {};
			}
			
			# create an entry for the extension if needed for the directory, 
			# --> associate to dir/ext :
			#         	- the list of common potential techno
			#			- the indexes of concerned files.
			if (! defined $dirs{$dirnode}->{$ext}) {
				my @commonPotechs = ();
				my @indexes = ();
				push @indexes, $file_idx;
				$dirs{$dirnode}->{$ext} = [\@commonPotechs, \@indexes];
				# add first list of potential technos
				for my $techno (keys %$potech) {
					push @commonPotechs, $techno;
				}
#print STDERR "$dirnode->[DIR_NAME]/[$ext] : INIT TO ".join(',', @commonPotechs)."\n";
				next;
			}
			else {
				push @{$dirs{$dirnode}->{$ext}->[FILES_IDX]}, $file_idx;
			}
			
			# next file if the current has no potential techno (else common technos will be set to none !!)
			next if (scalar keys %$potech == 0);

			# merge technos discovered for others files in the same directory, with the same extension
			my $commonPotech = $dirs{$dirnode}->{$ext}->[COMMON_POTECHS];
#print STDERR "MERGING ".join(',', keys %$potech)."\n";
			for my $techno (@{$commonPotech}) {
				if (! defined $potech->{$techno}) {
					# if the techno is not found for this new file, then it is no common
#print STDERR "$dirnode->[DIR_NAME]/[$ext] : REMOVE NON COMMON $techno\n";
					$techno = undef;
				}
			}
			@$commonPotech = grep defined, @$commonPotech;
			
			if (scalar @$commonPotech == 1) {
#print STDERR "$dirnode->[DIR_NAME]/[$ext] : RESOLVED TO $commonPotech->[0]\n";
				# resolve all files concerned.
			}
		}
	}
	
	for my $dirnode (keys %dirs) {
		my $H_ext = $dirs{$dirnode};
		for my $ext (keys %$H_ext) {
			if (scalar @{$H_ext->{$ext}->[COMMON_POTECHS]} == 1 ) {
				my $resolved_techno = $H_ext->{$ext}->[COMMON_POTECHS]->[0];
				# In this dir, the files having the extension $ext are resolved to a known techno.
				for my $file_idx (@{$H_ext->{$ext}->[FILES_IDX]}) {
					my $fnode = $files->[$file_idx];
					technos::lib::setFileTechno($fnode, $resolved_techno, "statistic from potential");
					$files->[$file_idx] = undef;
				}
			}
		}
	}
	
	# remove entries that have been deleted by setting to undef.
	@$files = grep defined, @$files;
}

sub __checkWithContext($) {
  my $files = shift;

#  my %cache = ();

  for my $filenode (@$files) {
#print "FILE : ". $filenode->[FILE_NAME]."\n";
    # do not resolve by context a file for which a techno has already been found.
    next if ((scalar keys %{$filenode->[FILE_TECHNOS]} > 0) or
             (scalar keys %{$filenode->[FILE_EXCLUDED_TECHNOS]} > 0));

    my $dirnode = technos::lib::getFileDir($filenode);
    my $extension = $filenode->[FILE_EXTENSION];

    my $technoResolved = undef;
    my $method = "";

    # (1) try to resolve potential techno with context (according to techno priority or techno already found in the directory).
    #--------------------------------------------------------------------------------------------------------------------------
    if (scalar keys %{$filenode->[FILE_POTENTIAL_TECHNOS]} > 0) {
       $technoResolved = __checkWithContextFromPotential($filenode, $dirnode);
       if (defined $technoResolved) {
		   $method = "from context with potential techno";
	   }
	}

	#(2) try to resolve from context with extension 
	#---------------------------------------------- 
	if (! defined $technoResolved) {
		# looking for associated extensions in the same directory, that could be charateristic of a techno...
		#----------------------------------------------------------------------------------------------------
		# 
		# NOTE : Extension checking is not case sensitive.
		my $associated_ext = technos::config::getAssociatedExtensions(lc($extension));
		if (defined $associated_ext) {
			my $DirFiles = technos::lib::getDirFiles($dirnode);
			for my $file (@$DirFiles) {
				if ($file->[FILE_NAME] =~ /\.(\w+)$/) {
					if (defined $associated_ext->{lc($1)}) {
						$technoResolved = $associated_ext->{lc($1)};
						last;
					}
				}
			}
		}
	}

    if (! defined $technoResolved) {
		# looking techno already discovered for file with the same extension in the same directory...
		#-------------------------------------------------------------------------------------------- 
        my $technos;


		# get technos of files with same extension in the dir.
#		if (exists $cache{$dirnode}) {
#print "FOUND $dirnode in cache\n;";
#			$technos=$cache{$dirnode};
#	    }
#	    else {
		    $technos = getTechnosFromDir($dirnode, $extension);
#print "TECHNO IN DIR : ".(join (',', keys %$technos))."\n";
#print "---> CACHING : $dirnode for ".$dirnode->[DIR_NAME]."\n";
#            $cache{$dirnode}=$technos;
#	    }

		my @contextualTechs = keys %$technos;

		# if all files with the same extension have the same techno, then
		# the file is to be resolved to this techno (unless context is not allow for this techno).
		if ((scalar @contextualTechs == 1) &&
		    (technos::config::isContextResolutionAllowed($extension, $contextualTechs[0]))) {
				 			 
			$technoResolved = $contextualTechs[0];
			$method = "from context";
		}
	}
	
	if (! defined $technoResolved) {
		# (3) try to resolve potential to ultimate default.
		#--------------------------------------------------
		my $ultimateDefault = technos::config::getUltimateDefaut($extension);
		if ($ultimateDefault) {
			if (exists $filenode->[FILE_POTENTIAL_TECHNOS]->{$ultimateDefault}) {
				$technoResolved = $ultimateDefault;
				$method = "from context with last resort default";
			}
		}
    }
	
	if (defined $technoResolved) {
		technos::lib::resolveFileTechno($filenode, $technoResolved, $method);
		# remove file from the corresponding list
		$filenode = undef;
	}
  }

  # remove entries that have been deleted by setting to undef.
  @$files = grep defined, @$files;

}

sub checkWithContext() {

  technos::lib::phase_checking_with_context();

  technos::lib::tagTime("Check with context");
  # For eah file with potential techno
  # -----------------------------------
  __checkWithContext(&technos::lib::getPotentialTechnoFileList());
  __checkWithContextFromPotentialStatistics(&technos::lib::getPotentialTechnoFileList(&technos::lib::getPotentialTechnoFileList()));

  technos::lib::traceEvent("Check with context using potential technos");
  # For each file without potential techno
  # --------------------------------------
  __checkWithContext(&technos::lib::getUnknowTechnoFileList());

  technos::lib::traceEvent("Check with context without potential technos");
  
  technos::lib::printResolvedStat();
}

#--------------------------------------------------
#---------------------- PRINT ----------------------
#--------------------------------------------------

sub exportResult($$;$) {
  my $root = shift;
  my $options = shift;
  my $dialogDir = $options->{'dialog'};
  my $format = $options->{'export'};

  if (!defined $format) {
    $format = "";
  }

###################################
#  Desactivate exportation to GUI
###################################
  $dialogDir = undef;
###################################

  my $fd_STDOUT = *STDOUT;

  technos::lib::OUTPUT " * Following Dirs contain following technos :\n";
  technos::lib::OUTPUT "   ------------------------------------------\n";
  technos::lib::printTree($root);

  technos::lib::ExportStartTechnoFound($format);

  my $H_technosStatus = technos::lib::getTechnosStatus();

  my $FD_fileList;
  for my $techno ( keys %$H_technosStatus) {
    my $nb_files = 0;

	my $FD_EXPORT = technos::lib::get_FD_TECH_FOUND();;

	if (technos::config::isOutOfContext([$techno])) {
		$FD_EXPORT = technos::lib::get_FD_TECH_OOC();
	}

    technos::lib::Export_TechnoFound_Techno($format, $techno);

    my $filename="unknow";

    # If dialog option is ON, then generate list of source file detected.
    if (defined $dialogDir) {
      if ($dialogDir !~ /\/$/) {
        $dialogDir .= '/';
      }
      $filename = $dialogDir.$techno."_FileList.txt";
      my $ret = open FICLIST, ">$filename";
      if (!$ret) {
        print "unable to write file list : $filename. File list will dumped hereafter :\n";
      }
      else {
	print "WRITING $filename\n";
        my $tmp_FD_fileList = *FICLIST;
        $FD_fileList=\$tmp_FD_fileList;
      }
    }
    
    # Retrieves file list and output each file.
    my $filelist = @{$H_technosStatus->{$techno}}[1];
    for my $file (@$filelist) {

      technos::lib::Export_TechnoFound_File($format, $file, $FD_EXPORT);

      if (defined $dialogDir) {
        print $FD_fileList technos::lib::getFileDir($file)->[5]."/".$file->[FILE_NAME]."\n";
      }

      $nb_files++;
    }

    if (defined $dialogDir) {
      my $analyzer = technos::config::getTechnoAnalyzer($techno);
      if (!defined $analyzer) {
		  $analyzer = "unknow";
	  }
      technos::lib::SEND_EVENT("TECHNO_FOUND;$techno;$nb_files;$filename;$analyzer");
      close $$FD_fileList;
    }
  }

  technos::lib::ExportStopTechnoFound($format);

  technos::lib::printPotentialFileTechno($format);
  technos::lib::OUTPUT "\n";
  technos::lib::printUnknowFileTechno($format);

  technos::lib::export_Errors($format);
}

1;
