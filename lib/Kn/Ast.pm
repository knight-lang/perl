package Kn::Ast;
use strict;
use warnings;
no warnings qw(recursion);

use Scalar::Util qw(refaddr); # for `is_equal`
use Kn::Function;
use parent 'Kn::Value';

# All overload functions for ASTs just default to `run`ing the AST. Perl converts the return value
# of `run` for us.
use overload
	'0+'   => 'run',
	'""'   => 'run',
	'bool' => 'run',
	'@{}'  => 'run';

# Creates a new `Ast` with the given function and arguments.
sub new {
	my ($class, $func, @args) = @_;
	bless { func => $func, args => \@args }, $class;
}

# An Ast is only equivalent to itself.
sub is_equal {
	my ($lhs, $rhs) = @_;
	ref $lhs eq ref $rhs && refaddr $lhs == refaddr $rhs;
}

# Running an AST executes its function with its arguments.
sub run {
	$_[0]->{func}->run(@{$_[0]->{args}})
} 

# Parsing an AST checks to make sure the function is a valid operator KNIGHT function name, and then
# parses and executes it..
sub parse {
	my ($class, $stream) = @_;

	$$stream =~ s(\A[A-Z][A-Z_]*|\A[-+*/\%^<?>&|!\$;=~,\[\]])()p or return;
	my $fnname = substr ${^MATCH}, 0, 1;
	my $func = Kn::Function->get($fnname) or die "[BUG] fn doesn't exist, but we parsed it? $fnname";

	my $ret = $class->new($func, map { Kn::Value->parse($stream) } 1..$func->arity);
	$ret
}

# Dump returns a string debugging representation of the class.
sub dump {
	my ($this) = @_;
	my $ret = "Function($this->{func}->{name}";
	$ret .= ', ' . $_->dump foreach @{$this->{args}};
	$ret . ')'
}

1;
