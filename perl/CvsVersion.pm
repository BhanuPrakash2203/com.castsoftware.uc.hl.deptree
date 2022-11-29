#----------------------------------------------------------------------#
#                 @ISOSCOPE 2008                                       #
#----------------------------------------------------------------------#
#       Auteur  : ISOSCOPE SA                                          #
#       Adresse : TERSUD - Bat A                                       #
#                 5, AVENUE MARCEL DASSAULT                            #
#                 31500  TOULOUSE                                      #
#       SIRET   : 410 630 164 00037                                    #
#----------------------------------------------------------------------#
# Ce fichier a ete l'objet d'un depot aupres de                        #
# l'Institut National de la Propriete Industrielle (lettre Soleau)     #
#----------------------------------------------------------------------#

# Composant: Framework

package CvsVersion;


sub display_file_version($$$$$)
{
  my ($file, $status, $w_rev, $r_rev, $sticky )=@_;
  return '' if ( not defined $file );
  return '' if ( $status =~ m/Unknown/ );
  my $str_sticky = $sticky ;
  my $str_r_rev ;
  if ( $w_rev ne $r_rev )
  {
    $str_r_rev= '/' . $r_rev;
  }
  else
  {
    $str_r_rev= '' ;
  }
  my $display =   $file .',' . $w_rev . $status . $str_r_rev . $str_sticky ;
  #$display =~ tr/[\t]//cd ;
  $display =~ s/[\t]//g ;
  #print 'Fichier :' . $display . "\n" ;
  return $display;
}


sub getVersion (;$)
{
  my ($rep ) = @_;
  my @output = ();
  my $commande = 'cvs status  -l' ;
  if ($rep)
  {
    if ( ($rep =~ m{\A/} )
      or ($rep =~ m{\A.:} ) )
    {
      return undef;
    }
    opendir(DIR, "$rep");
    my $filter_file_to_analyse = ".*\\.p[lm]\$";
    #my $filter_file_to_analyse = ".*";
    my @fichiers_in = sort(grep(/$filter_file_to_analyse$/,readdir(DIR)));
    @fichiers_in = map { $rep.$_ } @fichiers_in ;
    closedir(DIR);
    $commande = 'cvs status ' .  join ( ' ' , @fichiers_in );
  }
# $rep . ' -l ';
  @output = qx($commande ) ;
  
  my @revisions = ();
  my ($file, $status, $w_rev, $r_rev, $sticky );
  foreach my $line  ( @output )
  {
    # ===================================================================
    # File: Analyse.pm        Status: Up-to-date
  
    # Working revision:    1.53
    # Repository revision: 1.53    /home/cvs/Repository/Alarmes/Compteurs/Analyse.pm,v
    # Sticky Tag:          (none)
    # Sticky Date:         (none)
    # Sticky Options:      (none)
  
    if ( $line =~ m/^File: ([^ \t]*)\s*.*Status: (.*)/g )
    {
      my $revision = display_file_version ($file, $status, $w_rev, $r_rev, $sticky );
      push @revisions, $revision;
      $file = $1 ;
      $status = $2 ;
      if ( $status =~ m/Up-to-date/ )
      {
        $status = '';
      }
      elsif ( $status =~ m/Needs Patch/ )
      {
        $status = '-';
      }
      elsif ( $status =~ m/Locally Modified/ )
      {
        $status = '+';
      }
      ( $w_rev, $r_rev, $sticky ) = ( '', '', '' ) ;
      #print $line ;
    } 
    elsif  ( $line =~ m/^\s*Working revision:\s*(.*)/g )
    {
      $w_rev = $1 ;
    }
    elsif  ( $line =~ m/^\s*Repository revision:\s*(\S*)/g )
    {
      $r_rev = $1 ;
    } 
    elsif  ( $line =~ m/^\s*Sticky (.*):\s*(.*)/g )
    {
      my $sticky_type = $1 ;
      my $sticky_val = $2 ;
      if ( $sticky_val !~ m/\(none\)/ )
      {
        $sticky .= '(' . $sticky_type . ':' . $sticky_val . ')' ;
      }
    }
    else
    {
      ; # don't care.
    }
  }
  my $revision = display_file_version ($file, $status, $w_rev, $r_rev, $sticky );
  push @revisions, $revision;
  return \@revisions ;
}

sub main()
{
  print join ( "\n... " , @ARGV );
  print "\n" ;
  print $ARGV[0] ;
  print "\n" ;
  my $revisions=getVersion( $ARGV[0] );
  return if (not defined $revisions);
  print "#### Les versions des fichiers a jour sont :";
  print join ( "\n", @{$revisions} );
  print "\n#### Les sources modifies ou pas a jour sont :\n";
  foreach my $line (@{$revisions})
  {
    if ($line =~ /,(.*-)|\+|Needs Merge/)
    {
      print "$line\n";
    }
  }
}

if (not defined caller() )
{
  main();
}

 1;
