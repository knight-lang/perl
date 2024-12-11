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
	$class->new($1 eq 'T');
}

# Dumps the class's info. Used for debugging.
sub dump {
	shift;
}

# Compares the booleans strings lexicographically.
sub cmp {
	(!!shift) <=> (!!shift)
}

1;
