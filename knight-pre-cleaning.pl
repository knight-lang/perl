#!/usr/bin/env perl
use warnings;
use strict;

no warnings 'recursion'; # `run` has lots of recursion

# Types in this implementation are handled via hashes: The `kind` value is one
# of the following constants, and the `data` value corresponds to the data of
# that type. Only the `FUNC_TYPE` functions differently---instead of a `data`
# field, it has both `func` and `args` fields.
use constant INT_TYPE => 0;
use constant STR_TYPE => 1;
use constant LIST_TYPE => 2;
use constant BOOL_TYPE => 3;
use constant NULL_TYPE => 4;
use constant VAR_TYPE => 5;
use constant FUNC_TYPE => 6;

# These are the only instances of their corresponding types.
our $NULL =  { kind => NULL_TYPE, data => 0 };
our $TRUE =  { kind => BOOL_TYPE, data => 1 };
our $FALSE = { kind => BOOL_TYPE, data => 0 };

###############
## Variables ##
###############
our %known_variables;
sub lookup_variable {
	my ($name) = @_;
	$known_variables{$name} ||= { kind => VAR_TYPE, data => undef }
}

sub assign_variable {
	my ($variable, $value) = @_;
}

sub run :prototype(_);

sub kind :prototype(_) { shift->{kind} }
sub data :prototype(_) { shift->{data} }
sub adata :prototype(_) { @{data shift} }

# Metjhpo
sub newint { {kind => INT_TYPE, data => int(shift)} }
sub newstr { {kind => STR_TYPE, data => shift} }
sub newlist { {kind => LIST_TYPE, data => [@_] } }
sub newbool { shift ? $TRUE : $FALSE }



sub repr :prototype(_);
sub repr :prototype(_) {
	my $value = shift;
	$value = run $value if VAR_TYPE <= kind $value;

	return data if INT_TYPE == kind;
	return data ? 'true' : 'false' if BOOL_TYPE == kind;
	return 'null' if $_ == $NULL;
	return '[' . join(', ', map {repr} adata) . ']' if LIST_TYPE == kind;

	my $r = '"';
	foreach (split //, data) {
		if ($_ eq "\r") { $r .= '\r'; next }
		if ($_ eq "\n") { $r .= '\n'; next }
		if ($_ eq "\t") { $r .= '\t'; next }
		$r .= '\\' if $_ eq '\\' || $_ eq '"';
		$r .= $_;
	}
	$r . '"';
}

sub toint :prototype($) {
	$_ = shift;
	$_ = run if VAR_TYPE <= kind;

	no warnings qw(numeric);
	return int adata if LIST_TYPE == kind;
	return int data unless STR_TYPE == kind;
	data() =~ /^\s*([-+]?\d+)/;
	$1 || 0
}

sub tostr :prototype($);
sub tostr :prototype($) {
	$_ = shift;
	$_ = run if VAR_TYPE <= kind;

	return data if STR_TYPE >= kind;
	return join "\n", map{ tostr($_) } adata if LIST_TYPE >= kind;
	return '' if $_ == $NULL;
	$_ == $TRUE ? 'true' : 'false'
}

sub tobool :prototype(_) {
	$_ = shift;
	$_ = run if VAR_TYPE <= kind;

	return '' ne data if STR_TYPE == kind;
	return scalar adata if LIST_TYPE == kind;
	data
}

sub tolist :prototype($) {
	$_ = shift;
	$_ = run if VAR_TYPE <= kind;

	return adata if LIST_TYPE == kind;
	return map {newstr $_} split //, data if STR_TYPE == kind;

	if (INT_TYPE == kind) {
		my $is_neg = 0 > data;
		return map {$is_neg and $_ = -$_; newint $_} split //, abs data
	}

	data ? $_ : ();
}

sub run :prototype(_) {
	$_ = shift;

	return $_ if VAR_TYPE > kind;
	return data if VAR_TYPE == kind;

	$_->{func}->(@{$_->{args}})
}

sub are_eql :prototype($$);
sub are_eql :prototype($$) {
	$_ = shift;
	my $rhs = shift;

	return 1 if $_ == $rhs;
	return 0 unless kind $rhs == kind;

	return data $rhs == data if INT_TYPE == kind;
	return data $rhs eq data if STR_TYPE == kind;
	return 0 unless LIST_TYPE == kind;

	my @l = adata;
	my @r = adata $rhs;
	return 0 unless $#l == $#r;
	are_eql($l[$_], $r[$_]) or return 0 for 0..$#l;
	1
}

sub compare :prototype($$);
sub compare :prototype($$) {
	$_ = shift;

	return data() <=> toint(shift) if INT_TYPE == kind;
	return data() cmp tostr(shift) if STR_TYPE == kind;
	return data() <=> !!tobool(shift) if BOOL_TYPE == kind;
	my @lhs = adata;
	my @rhs = tolist shift;
	my $limit = $#lhs < $#rhs ? $#lhs : $#rhs;
	for (my $i = 0; $i <= $limit; $i++) {
		my $cmp = compare($lhs[$i], $rhs[$i]);
		return $cmp if $cmp;
	}
	$#lhs <=> $#rhs

}

sub parse :prototype(_);

my %functions = (
	'P' => [0, sub { newstr scalar <>; }],
	'R' => [0, sub { newint int rand 0xffff_ffff }],

	'E' => [1, sub { run parse tostr shift }],
	'B' => [1, sub { shift }],
	'C' => [1, sub { run run shift }],
	'`' => [1, sub { my $str = tostr shift; newstr scalar `$str` }],
	'Q' => [1, sub { exit toint shift }],
	'!' => [1, sub { newbool !tobool shift }],
	'L'  => [1, sub { my @a = tolist shift; newint scalar @a }],
	'D'  => [1, sub { $_ = run shift; print repr; $_ }],
	'O'  => [1, sub { $_ = tostr shift; s/\\$// or $_ .= "\n"; print; $NULL }],
	'A'  => [1, sub {
		$_ = run shift;
		return newstr chr data if INT_TYPE == kind;
		newint ord data
	}],
	'~'  => [1, sub { newint -toint shift }],
	','  => [1, sub { newlist run shift }],
	'['  => [1, sub {
		$_ = run shift;
		return newstr substr data, 0, 1 if STR_TYPE == kind;
		(adata)[0];
	}],
	']'  => [1, sub {
		$_ = run shift;
		return newstr substr data, 1, length data if STR_TYPE == kind;
		my @list = adata;
		newlist @list[1..$#list];
	}],

	'+' => [2, sub {
		$_ = run shift;
		return newint data() + toint shift if INT_TYPE == kind;
		return newstr data() . tostr shift if STR_TYPE == kind;
		newlist adata, tolist shift
	}],
	'-' => [2, sub { newint toint(shift) - toint(shift) }],
	'*' => [2, sub {
		my $tmp = run shift;
		my $amnt = toint shift;
		$_ = $tmp;

		return newint data() * $amnt if INT_TYPE == kind;
		return newstr data() x $amnt if STR_TYPE == kind;

		my @list;
		@list = (@list, adata) while ($amnt--);
		newlist @list
	}],
	'/' => [2, sub { newint toint(shift) / toint(shift) }],
	'%' => [2, sub { newint toint(shift) % toint(shift) }],
	'^' => [2, sub {
		$_ = run shift;
		return newint data() ** toint shift if INT_TYPE == kind;
		my @eles = adata;
		newstr join tostr(shift), map{tostr $_} @eles
	}],
	'<' => [2, sub { newbool(0 > compare run(shift), run(shift)) }],
	'>' => [2, sub { newbool(0 < compare run(shift), run(shift)) }],
	'?' => [2, sub { newbool are_eql run(shift), run(shift) }],
	'&' => [2, sub { $_ = run shift; tobool ? run(shift) : $_; }],
	'|' => [2, sub { $_ = run shift; tobool ? $_ : run(shift); }],
	';' => [2, sub { run shift; run shift }],
	'=' => [2, sub { $_[0]->{data} = run $_[1] }],
	'W' => [2, sub { run $_[1] while tobool $_[0]; $NULL }],

	'I' => [3, sub { run $_[!tobool shift] }],
	'G' => [3, sub {
		my $cont = run shift;
		my $idx = toint shift;
		my $len = toint shift;

		return newstr substr data $cont, $idx, $len if STR_TYPE == kind $cont;
		my @list = adata $cont;
		newlist @list[$idx..$idx + $len - 1]
	}],
	'S' => [4, sub {
		my $cont = run shift;
		my $idx = toint shift;
		my $len = toint shift;
		my $repl = run shift;

		if (STR_TYPE == kind $cont) {
			return newstr substr(data $cont, 0, $idx) . tostr($repl) . substr(data $cont, $idx + $len);
		}

		my @list = adata $cont;
		return newlist @list[0..$idx-1], tolist($repl), @list[$idx + $len..$#list];
	}]
);

sub parse :prototype(_);
sub parse :prototype(_) {
	$_ = shift;
	s/^(?:[\s():]|#\N*)+//;

	s/^\d+// and return newint $&;
	s/^(["'])(.*?)\1//s and return newstr $2;
	s/^[a-z_][a-z0-9_]*// and return lookup_variable $&;
	s/^([TF])[A-Z_]*// and return newbool($1 eq 'T');
	s/^N[A-Z_]*// and return $NULL;
	s/^@// and return newlist;

	s/^([A-Z]+|.)// or return;
	my $name = substr $1, 0, 1;
	my ($arity, $func) = @{$functions{$name} or die "unknown token start '$name'"};
	my @args;

	for (my $i = 0; $i < $arity; $i++) {
		push @args, (parse or die "missing argument $i for function '$name'");
	}

	{ kind => FUNC_TYPE, func => $func, args => \@args }
}

my $flag = shift;

die "usage: $0 (-e 'expr' | -f file)" unless !$#ARGV && ($flag eq '-e' || $flag eq '-f');

my $expr = parse($flag eq '-e' ? shift : join '', <>) or die 'nothing to parse?';
run $expr;
