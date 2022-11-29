package TypeScript::Identifiers;

my $IDENTIFIER = '[\w$]+';
my $IDENTIFIER_CHARACTERS = '[\w$]';

my $DEREF_EXPRESSION = '[\w$\.]+';

sub getIdentifiersPattern() {
  return $IDENTIFIER;
}

sub getIdentifiersCharacters() {
  return $IDENTIFIER_CHARACTERS;
}

sub getDereferencementPattern() {
  return $DEREF_EXPRESSION;
}

1;
