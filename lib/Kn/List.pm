package Kn::List;
use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'bool' => sub { $#{shift()}; },
	'0+' => sub { $#{shift()}; },
	'""' => sub { join "\n", map{"$_"} shift(); }; # todo: can this just be `join "\n",shift`

# Creates a new `Value` (or whatever subclasses it) by simply getting a
# reference to the second argument.
sub new {
	my $class = shift;
	bless \@_, $class;
}

sub parse {
	my ($class, $stream) = @_;
	$$stream =~ s/\A@//s or return;
	$class->new()
}

# Converts both arguments to a string and concatenates them.
sub add {
	Kn::List->new(@{shift()}, @{shift()});
}

# Duplicates the first argument by the second argument's amount.
sub mul {
	my @list = @{shift()};
	my $amnt = int shift;
	my @res;
	@res = (@res, @list) while ($amnt--)
	Kn::List->new(shift() x shift);
}

# Compares the two strings lexicographically.
sub cmp {
	"$_[0]" cmp "$_[1]"
}

# Checks to see if two strings are equal. This differs from `Value`'s in that
# we check for equality with `eq` not `==`.
sub eql {
	my ($lhs, $rhs) = @_;

	ref($lhs) eq ref($rhs) && $$lhs eq $$rhs
}
# Dumps the class's info. Used for debugging.
sub dump {
	my @list = @{shift()};
	my $dump = '[';

	'[' . join(', ', map{$_->dump()} @list) . ']'
}

1;
