package Kn::List;
use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'bool' => sub { $#{shift()} >= 0 },
	'0+'   => sub { 1 + $#{shift()} },
	'""'   => sub { join "\n", @{shift()} },
	'@{}'  => sub { shift };

# Creates a new `Value` (or whatever subclasses it) by simply getting a
# reference to the second argument.
sub new {
	my $class = shift;
	bless [@_], $class
}

sub parse {
	my ($class, $stream) = @_;
	$$stream =~ s/\A@//s or return;
	$class->new
}

sub add {
	Kn::List->new(@{shift()}, @{shift()})
}

sub mul {
	my @list = @{shift()};
	my $amnt = int shift;

	my @res;
	@res = (@res, @list) while $amnt--;
	Kn::List->new(@res)
}

sub pow {
	my @list = @{shift()};
	my $sep = '' . shift;

	Kn::String->new(join $sep, @list)
}

# Compares the two strings lexicographically.
sub compare {
	my @lhs = @{shift()};
	my @rhs = @{shift()};

	my $minlen = $#lhs < $#rhs ? $#lhs : $#rhs;

	my $cmp;
	for (my $i = 0; $i <= $minlen; $i++) {
		$cmp = $lhs[$i]->compare($rhs[$i]) and return $cmp;
	}

	$#lhs <=> $#rhs
}

# Checks to see if two strings are equal. This differs from `Value`'s in that
# we check for equality with `eq` not `==`.
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

sub head {
	my @list = @{shift()};
	die 'head on empty list' if $#list == -1;
	return $list[0]
}

sub tail {
	my @list = @{shift()};
	die 'head on empty list' if $#list == -1;
	return __PACKAGE__->new(@list[1..$#list])
}

# Dumps the class's info. Used for debugging.
sub dump {
	my @list = @{shift()};
	my $dump = '[';

	'[' . join(', ', map{ $_->dump } @list) . ']'
}

sub get {
	my ($list, $start, $len) = @_;
	$start = int $start;
	$len   = int $len;
	__PACKAGE__->new(@$list[$start..$start + $len - 1])
}

sub set {
	my ($list, $start, $len, $repl) = @_;
	$start = int $start;
	$len   = int $len;
	__PACKAGE__->new(@$list[0..$start - 1], @$repl, @$list[$start + $len..$#$list])
}

1;
