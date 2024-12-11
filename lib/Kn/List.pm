package Kn::List;
use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'0+'   => sub { 1 + $#{shift()} },
	'""'   => sub { join "\n", @{shift()} },
	'@{}'  => sub { shift };

# Creates a new `Value` (or whatever subclasses it) by simply getting a
# reference to the second argument.
sub new {
	my $class = shift;
	bless [@_], $class
}

# Parses `@` as an empty list literal.
sub parse {
	my ($class, $stream) = @_;
	return $class->new if $$stream =~ s/\A@//;

	# Support the `{ ... }` array extensions. Note it only works for literal values. (We could make
	# it work for functions too, but it'd require a separate type which overloaded `run`.)
	return unless $$stream =~ s/\A\{//;


	my @ary;
 	while (1) {
		push @ary, eval { Kn::Value->parse($stream) };
		next unless length $@;
		die $@ unless $@ =~ /^unknown token start '\}'/;
		$$stream =~ s/^\}//;
		last;
	}
	return $class->new(@ary);
}

# Converts both arguments to a list and concatenates them.
sub add {
	__PACKAGE__->new(@{shift()}, @{shift()})
}

# Repeats the first argument (the list) second argument (converted to an int) times.
sub mul {
	my @list = @{shift()};
	my $amnt = int shift;

	my @res;
	@res = (@res, @list) while $amnt--;
	__PACKAGE__->new(@res)
}

# Joins the list by the second argument converted to a string.
sub pow {
	my @list = @{shift()};
	my $sep = '' . shift;

	Kn::String->new(join $sep, @list)
}

# Compares the two lists element-by-element. If they're the same length, their lengths are compared.
sub compare {
	my @lhs = @{shift()};
	my @rhs = @{shift()};

	my $minlen = $#lhs < $#rhs ? $#lhs : $#rhs;

	my $cmp;
	for (my $i = 0; $i <= $minlen; $i++) {
		return $cmp if $cmp = $lhs[$i]->compare($rhs[$i]);
	}

	$#lhs <=> $#rhs
}

# Checks to see if two lists are equal.
sub is_equal {
	my ($lhs, $rhs) = @_;
	return unless ref $lhs eq ref $rhs; # Make sure they refer to the same type

	my @lhs = @$lhs;
	my @rhs = @$rhs;
	return unless $#lhs == $#rhs;
	
	for (my $i = 0; $i <= $#lhs; $i++) {
		return unless $lhs[$i]->is_equal($rhs[$i]);
	}

	1
}

# Return the first element.
sub head {
	my @list = @{shift()};
	die 'head on empty list' if $#list == -1;
	return $list[0]
}

# Return a new List of everything but the first element.
sub tail {
	my @list = @{shift()};
	die 'head on empty list' if $#list == -1;
	return __PACKAGE__->new(@list[1..$#list])
}

# Gets a debugging representation of the list.
sub dump {
	my @list = @{shift()};

	'[' . join(', ', map{ $_->dump } @list) . ']'
}

# Gets a sublist of the first argument, starting at the second argument, with a length of the
# third argument.
sub get {
	my ($list, $start, $len) = @_;
	$start = int $start;
	$len   = int $len;
	__PACKAGE__->new(@$list[$start..$start + $len - 1])
}

# Returns a new list where the first argument's list starting at the second argument with length the
# third argument is replaced with the fourth.
sub set {
	my ($list, $start, $len, $repl) = @_;
	$start = int $start;
	$len   = int $len;
	__PACKAGE__->new(@$list[0..$start - 1], @$repl, @$list[$start + $len..$#$list])
}

1;
