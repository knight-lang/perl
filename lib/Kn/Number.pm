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

	die "Invalid ascii value '$num'." unless 0 < $num <= ord '~';

	Kn::String->new(chr $num);
}

# Adds two Values together by converting them both to numbers.
sub add {
	Kn::Number->new(int(shift) + int(shift));
}

# Subtract two Values by converting them both to numbers.
sub sub {
	Kn::Number->new(int(shift) - int(shift));
}

# Multiply two Values by converting them both to numbers.
sub mul {
	Kn::Number->new(int(shift) * int(shift));
}

# Divides the first number by the second, `die`ing if the second's zero.
sub div {
	my $lhs = int shift;
	my $rhs = int shift or die 'cant divide by zero';

	Kn::Number->new(int($lhs / $rhs));
}

# Modulo the first number by the second, `die`ing if the second's zero.
sub mod {
	my $lhs = int shift;
	my $rhs = int shift or die 'cant modulo by zero';

	Kn::Number->new($lhs % $rhs);
}

# Raises the first number to the power of the second.
sub pow {
	my $base = int shift;
	my $exp  = int shift;

	die 'cannot raise zero to a negative power' if !$base && $exp < 0;

	Kn::Number->new(int($base ** $exp));
}

# Converts both values to integers and compares them.
sub cmp {
	int(shift) <=> int(shift);
}

1;
