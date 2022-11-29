package KeywordScan::detector;

use strict;
use warnings;

my $DEBUG = 0;

sub new($$$) {
  my ( $classe, $scanName, $keywordsDescription ) = @_;

  # Vérifions la classe
  $classe = ref($classe) || $classe;

  # Création de la référence anonyme de hachage vide (futur objet)
  my $this = {};

  # Liaison de l'objet à la classe
  bless $this, $classe;

  $this->{NAME}         = $scanName;
  $this->{T_KEYWORDS_DESCRIPTION} = $keywordsDescription;
  $this->{H_KEYWORD}    = {};
  $this->{T_KEYWORD}    = [];
  $this->{T_FILES}    = [];
  $this->{H_VALUES}     = {};
  
  return $this;
}

sub getTabKeywords() {
	my $this = shift;
	return $this->{T_KEYWORD};
}

sub getHashKeywords() {
	my $this = shift;
	return $this->{H_KEYWORD};
}

sub getFileValues($) {
	my $this = shift;
	my $file_idx = shift; 
	return $this->{T_FILES}->[$file_idx];
}

sub addFileDetection($$$) {
	my $this = shift;
	my $file_idx = shift;
	my $keyword = shift;
	my $value = shift;
# print "ADD FILE: $file_idx // KEYWORD: $keyword // VALUE: $value\n";
	my $H_Keywords = $this->{H_KEYWORD};

	# store data
	if (! exists $H_Keywords->{$keyword}) {
		push @{$this->{T_KEYWORD}}, $keyword;
		$H_Keywords->{$keyword} = 1;
	}
	$this->{T_FILES}->[$file_idx]->{$keyword} = $value;
}

sub addFileDetectionNew($$$$) {
	my $this = shift;
	my $file_idx = shift;
	my $keyword = shift;
	my $searchID = shift;
	my $value = shift;
# print "ADD FILE: $file_idx // KEYWORD: $keyword // SEARCHID: $searchID // VALUE: $value\n";
	my $H_Keywords = $this->{H_KEYWORD};

	# store data
	if (! exists $H_Keywords->{$keyword}) {
		push @{$this->{T_KEYWORD}}, $keyword;
		$H_Keywords->{$keyword} = 1;
	}
	$this->{T_FILES}->[$file_idx]->{$keyword}->{$searchID} = $value;
}

# sub deleteFileDetection($$$) {
	# my $this = shift;
	# my $file_idx = shift;
	# my $keyword = shift;

	# # delete data
	# my $H_Keywords = $this->{H_KEYWORD};
 
	# if (exists $H_Keywords->{$keyword}) 
    # {
        # my $index = 0; 
        # my $bool_delete = 0;        
        # foreach my $keyword_T (@{$this->{T_KEYWORD}})
        # {
            # if ($keyword_T eq $keyword)
            # {
                # print "DELETE index $index   $this->{T_KEYWORD}->[$index]\n" if ($DEBUG);
                # $bool_delete = 1;  
                # last;
            # }
            # $index++;
        # }
        
        # if (exists $this->{T_FILES}->[$file_idx]->{$keyword} and $bool_delete == 1)
        # {
            # # print "DELETE file_idx=$file_idx keyword=$keyword => $this->{T_FILES}->[$file_idx]->{$keyword}\n";
            # delete $this->{T_FILES}->[$file_idx]->{$keyword};
        # }
    # }
# }

# sub deleteKeywordDetection($) {
	# my $this = shift;
	# my $keyword = shift;

	# # delete data
	# my $H_Keywords = $this->{H_KEYWORD};
 
	# if (exists $H_Keywords->{$keyword}) 
    # {
        # my $index = 0; 
        # my $bool_delete = 0;        
        # foreach my $keyword_T (@{$this->{T_KEYWORD}})
        # {
            # if ($keyword_T eq $keyword)
            # {
                # print "DELETE index $index   $this->{T_KEYWORD}->[$index]\n" if ($DEBUG);
                # $bool_delete = 1;  
                # last;
            # }
            # $index++;
        # }
        # splice(@{$this->{T_KEYWORD}}, $index, 1) if ($bool_delete == 1); 
    # }
# }

# sub setFileDetection($$$) {
	# my $this = shift;
	# my $file_idx = shift; 
	# my $keyword = shift;
	# my $value = shift;
    # # print "SET file_id $file_idx $keyword $value\n";
    # $this->{T_FILES}->[$file_idx]->{$keyword} = $value;
	# return $this->{T_FILES}->[$file_idx]->{$keyword};
# }


1;
