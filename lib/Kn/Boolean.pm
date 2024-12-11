package Kn::Boolean;

use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'""'  => sub { shift ? 'true' : 'false' },
	'@{}' => sub { $_[0] ? [$_[0]] : [] };

# Parses a new boolean.
sub parse {
	my ($class, $stream) = @_;
	$$stream =~ s/\A([TF])[A-Z]*//p or return;
	$class->new($1 eq 'T')
}

# Dump simply returns the boolean itself, as its tostr conversion is the same as its dump output.
sub dump {
	shift
}

# Comparing booleans converts the second argument to a boolean, and then does numerical comparison.
sub compare {
	(!!shift) <=> (!!shift)
}

1;
