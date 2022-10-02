package Kn::Boolean;
use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'""' => sub { shift() ? 'true' : 'false'; },
	'@{}' => sub { my @l = shift() || (); \@l };

# Parses a new boolean.
sub parse {
	my ($class, $stream) = @_;

	$$stream =~ s/\A([TF])[A-Z]*//p or return;

	$class->new($1 eq 'T');
}

# Dumps the class's info. Used for debugging.
sub dump {
	shift() ? 'true' : 'false';
}

# Compares the booleans strings lexicographically.
sub cmp {
	(shift() ? 1 : 0) - (shift() ? 1 : 0)
}

1;
