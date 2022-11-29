package Lib::CountUtils;
# les modules importes
use strict;
use warnings;
#use diagnostics; #FIXME: est-ce compatible Strawberry?
#no warnings 'recursion'; 

use Erreurs;
use Lib::Log;

sub getStatistic($) {
	my $values = shift;
	my $nb_values = scalar @$values;
	
	return (0,0,0) if (!$nb_values);
	
	my $total = 0;
	my $max = 0;
	for my $value (@$values) {
		$total += $value;
		$max = $value if ($value > $max);
	}
	my $median;

	if ($nb_values % 2 == 0) {
		$median = ($values->[int($nb_values/2)-1]+$values->[int($nb_values/2)])/2;
	}
	else {
		$median = $values->[int($nb_values/2)];
	}
	
	my $average = 0;
	$average = $total/$nb_values if $nb_values;
	
	return ($max, $average, $median);
}

sub CountGrepWithLine($$$$) {
	my $reg = shift;
	my $mnemo = shift;
	my $msg = shift;
	my $code = shift;
	my $violation = 0;
	
	my $line = 1;
	while ($$code =~ /(?:(\n)|($reg))/g) {
		if (defined $1) {
			$line++;
		}
		else {
			$violation++;
			Erreurs::VIOLATION($mnemo, "$msg at line $line");
			$line += $2 =~ tr{\n}{\n};
		}
	}
	return $violation;
}

1;
