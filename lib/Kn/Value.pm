package Kn::Value;

use strict;
use warnings;
no warnings qw/recursion/; # Knight does a lot of recursion.

# Default overloads (used by Identifier and Ast)
use overload
	'""'   => sub { ${shift->run} },
	'0+'   => sub { ${shift->run} },
	'@{}'  => sub { @{shift->run} };

# Creates a new `Value` (or whatever subclasses it) by simply getting a
# reference to the second argument.
sub new {
	my ($class, $data) = @_;
	bless \$data, $class
}

# Running a normal value simply returns it by default.
sub run {
	shift
}

# Import different types, so we can parse them.
use Kn::Number;
use Kn::Boolean;
use Kn::Identifier;
use Kn::Null;
use Kn::String;
use Kn::Ast;
use Kn::List;

# Parses a Value from the stream, stripping leading whitespace and comments. If the first character
# of the stream is invalid, the program `die`s.
sub parse {
	my $stream = $_[1];

	# Strip prefix
	$$stream =~ s/\A(?:[\s():]+|#[^\n]*)*//;

	foreach (qw/Kn::Number Kn::Identifier Kn::Null Kn::String Kn::Boolean Kn::Ast Kn::List/) {
		my $ret = $_->parse($stream);
		return $ret if defined $ret;
	}

	die "unknown token start '" . substr($$stream, 0, 1) . "'"
}

1;
