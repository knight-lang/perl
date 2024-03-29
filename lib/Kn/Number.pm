package Kn::Number;
use strict;
use warnings;

use parent 'Kn::Value';

use overload 
	'@{}' => sub {
		my $num = ${shift()};
		my @map = map {Kn::Number->new($num < 0 ? -$_ : $_)} split //, abs $num;
		\@map
	};

# Parses out a `Kn::Number` from the start of a stream.
# A Number is simply a sequence of digits. (The character after the number is
# ignored; `12a` will be parsed as the number 12, and sets the stream to `a`.)
# 
# The stream that is passed should be a reference to a string; it will be 
# modified in-place if the number parses successfully.
#
# If a number isn't at the start of the stream, the stream is left unmodified
# and `undef` is returned.
sub parse {
	my ($class, $stream) = @_;

	$$stream =~ s/\A\d+//p or return;

	$class->new(${^MATCH});
}

# Dumps the class's info. Used for debugging.
sub dump {
	shift;
}

# Converts its argument into an ASCII string.
sub ascii {
	my $num = ${shift()};

	die "Invalid ascii value '$num'." unless 0 < $num && $num <= ord('~');

	Kn::String->new(chr($num));
}

1;
