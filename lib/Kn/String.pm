package Kn::String;
use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'bool' => sub { ${shift()} ne '' },
	'0+' => sub {
		no warnings;
		${shift()} =~ m/^\s*[-+]?\d*/p;
		int ${^MATCH}
	},
	'@{}'  => sub {
		my $str = ${shift()};
		my @list = map {__PACKAGE__->new($_)} split //, $str;
		\@list
	};

# Converts both arguments to a string and concatenates them.
sub add {
	__PACKAGE__->new(shift . shift)
}

# Duplicates the first argument by the second argument's amount.
sub mul {
	__PACKAGE__->new(shift() x shift)
}

# Compares two strings lexicographically.
sub compare {
	"$_[0]" cmp "$_[1]"
}

# Checks to see if two strings are equal.
sub is_equal {
	my ($lhs, $rhs) = @_;
	ref $lhs eq ref $rhs && $$lhs eq $$rhs
}

# Parses a string out, which should start with either `'` or `"`, after which all characters (except
# for that quote) are taken literally. If the closing quote isn't found, the program fails.
sub parse {
	my ($class, $stream) = @_;

	$$stream =~ s/\A(["'])((?:(?!\1).)*)(\1)?//s or return;
	die 'missing closing quote' unless $3;

	$class->new($2)
}

# Gets a string representation of the string.
sub dump {
	my $str = ${shift()};
	my $dump = '';

	foreach (split //, $str) {
		if ($_ eq "\r") {
			$dump .= '\r'
		} elsif ($_ eq "\n") {
			$dump .= '\n'
		} elsif ($_ eq "\t") {
			$dump .= '\t'
		} else {
			$dump .= '\\' if $_ eq '\\' || $_ eq '"';
			$dump .= $_;
		}
	}

	qq("$dump")
}

# Converts the first character into its codepoint.
sub ascii {
	my $string = ${shift()};
	length $string or die 'ascii on empty string';
	Kn::Number->new(ord $string)
}

# Return a new string of just the first character.
sub head {
	my $string = ${shift()};
	length $string or die 'head on empty string';
	return __PACKAGE__->new(substr $string, 0, 1)
}

# Return a new string of everything but the first character.
sub tail {
	my $string = ${shift()};
	length $string or die 'tail on empty string';
	return __PACKAGE__->new(substr $string, 1)
}

# Gets a substring of the first argument, starting at the second argument, with a length of the
# third argument.
sub get {
	my ($str, $start, $len) = @_;
	__PACKAGE__->new(substr $$str, $start, $len)
}

# Returns a new string where the first argument's string starting at the second argument with length
# the third argument is replaced with the fourth.
sub set {
	my ($str, $start, $len, $repl) = @_;
	$start = int $start;
	$len   = int $len;
	$repl  = "$repl";

	no warnings;
	__PACKAGE__->new(substr($str, 0, $start) . $repl . substr($str, $start + $len))
}

1;
