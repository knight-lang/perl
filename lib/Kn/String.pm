package Kn::String;
use strict;
use warnings;

use parent 'Kn::Value';

use overload
	'bool' => sub { ${shift()} ne '' },
	'0+' => sub {
		no warnings;

		${shift()} =~ m/^\s*[-+]?\d*/p;

		int ${^MATCH};
	},
	'@{}' => sub {
		my $str = ${shift()};
		my @list = map {Kn::String->new($_)} split //, $str;
		\@list
	};

# Converts both arguments to a string and concatenates them.
sub add {
	Kn::String->new(shift . shift);
}

# Duplicates the first argument by the second argument's amount.
sub mul {
	Kn::String->new(shift() x shift);
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

# Parses a string out, which should start with either `'` or `"`, after which
# all characters (except for that quote) are taken literally. If the closing
# quote isn't found, the program fails.
sub parse {
	my ($class, $stream) = @_;

	$$stream =~ s/\A(["'])((?:(?!\1).)*)(\1)?//s or return;
	die "missing closing quote" unless $3;

	$class->new($2)
}

# Dumps the class's info. Used for debugging.
sub dump {
	my $str = ${shift()};
	my $dump = '"';
	foreach (split //, $str) {
		if ($_ eq "\r") { $dump .= '\r'; next }
		if ($_ eq "\n") { $dump .= '\n'; next }
		if ($_ eq "\t") { $dump .= '\t'; next }
		$dump .= '\\' if $_ eq '\\' || $_ eq '"';
		$dump .= $_;
	}

	$dump . '"'
}

# Converts its argument into an ASCII value.
sub ascii {
	my $str = ${shift()};

	die "Passed string is empty" if $str eq '';

	Kn::Number->new(ord($str));
}

1;
