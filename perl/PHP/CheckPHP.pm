package PHP::CheckPHP;

my $shortOpenTag = '<(?:%|\?(?:php)?)';
my $shortCloseTag = '(?:\?|%)>';
my $scriptOpenTag = '<\s*script\s+[^>]*\bphp\b[^>]*>';
my $scriptCloseTag = '<\s*\/\s*script\b[^>]*>';

sub CheckCodeAvailability($)
{
  my ($buffer) = @_;
  if ($$buffer =~ m/$shortOpenTag|$scriptOpenTag/sgmi) {
    return undef;
  } else {
    return 'No php section detected';
  }
}

1;
