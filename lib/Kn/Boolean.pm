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
	$$stream =~ s/\A([TF])[A-Z_]*//p or return;
	$class->new($1 eq 'T')
}

# Dump simply returns the boolean itself, as its tostr conversion is the same as its dump output.
sub dump {
	shift
}

# Checks to see if the second argument is a boolean and equal to the first.
sub is_equal {
	my ($lhs, $rhs) = @_;
	ref $lhs eq ref $rhs && $$lhs == $$rhs
}

# Comparing booleans converts the second argument to a boolean, and then does numerical comparison.
sub compare {
	(!!shift) <=> (!!shift)
}

1;
