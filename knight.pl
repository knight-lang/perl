#!/usr/bin/env perl
use warnings;
use strict;

no warnings 'recursion'; # `run` has lots of recursion

# Types in this implementation are handled via hashes: The `kind` value is one
# of the following constants, and the `data` value corresponds to the data of
# that type. Only the `FUNC_KIND` functions differently---instead of a `data`
# field, it has both `func` and `args` fields.

use constant INT_KIND => 0;
use constant STR_KIND => 1;
use constant LIST_KIND => 2;
use constant BOOL_KIND => 3;
use constant NULL_KIND => 4;
use constant VAR_KIND => 5;
use constant FUNC_KIND => 6;

# These are the only instances of their corresponding types.
our $NULL =  { kind => NULL_KIND, data => 0 };
our $TRUE =  { kind => BOOL_KIND, data => 1 };
our $FALSE = { kind => BOOL_KIND, data => 0 };

###############
## Variables ##
###############
our %known_variables;
sub lookup_variable {
	my ($name) = @_;
	$known_variables{$name} ||= { kind => VAR_KIND, data => undef }
}

sub assign_variable {
	my ($variable, $value) = @_;
	$variable->{data} = $value;
}

sub run;

sub kind :prototype(_) { shift->{kind} }
sub data :prototype(_) { shift->{data} }
sub adata :prototype(_) { @{data shift} }


sub newint { {kind => INT_KIND, data => int(shift)} }
sub newstr { {kind => STR_KIND, data => shift} }
sub newlist { {kind => LIST_KIND, data => [@_] } }
sub newbool { shift ? $TRUE : $FALSE }

######################
# Conversion Methods #
######################
sub run_if_needed {
	my $value = shift;
	$value = run $value if $value->{kind} <= VAR_KIND;
	$value
}

sub to_int {
	print $_[0]->{kind};
	my $value = run_if_needed shift;
	print $value->{kind};
	my ($kind, $data) = @{$value}{'kind','data'};

	return int @$data if $kind == LIST_KIND;
	return int $data unless $kind == STR_KIND;

	# Normal perl string->int conversion doesn't follow the knight spec.
	($data =~ /^\s*([-+]?\d+)/) ? $1 : 0
}

sub to_str {
	my $value = run_if_needed shift;
	my ($kind, $data) = @{$value}{'kind','data'};

	return $data if $kind <= STR_KIND;
	return join "\n", map{ to_str($_) } @$data if $kind <= LIST_KIND;
	return '' if $kind == NULL_KIND;
	$data ? 'true' : 'false'
}

sub to_bool {
	my $value = run_if_needed shift;
	my ($kind, $data) = @{$value}{'kind','data'};

	return '' ne $data if $kind == STR_KIND;
	return scalar @$data if $kind == LIST_KIND;
	$data
}

sub to_list {
	my $value = run_if_needed shift;
	my ($kind, $data) = @{$value}{'kind','data'};

	return @$data if $kind == LIST_KIND;
	return map {newstr $_} split(//, $data) if $kind == STR_KIND;

	if ($kind == INT_KIND) {
		my $is_neg = 0 > $data;
		return map {$is_neg and $_ = -$_; newint $_} split //, abs $data
	}

	$data ? $TRUE : ();
}

sub repr {
	my $value = run_if_needed shift;
	my ($kind, $data) = @{$value}{'kind','data'};

	return $data if $kind == INT_KIND;
	return $data ? 'true' : 'false' if $kind == BOOL_KIND;
	return 'null' if $kind == NULL_KIND;
	return '[' . join(', ', map {repr($_)} adata) . ']' if $kind == LIST_KIND;

	my $r = '"';
	foreach (split //, $data) {
		if ($_ eq "\r") { $r .= '\r'; next }
		if ($_ eq "\n") { $r .= '\n'; next }
		if ($_ eq "\t") { $r .= '\t'; next }
		$r .= '\\' if $_ eq '\\' || $_ eq '"';
		$r .= $_;
	}
	$r . '"';
}

sub are_eql :prototype($$);
sub are_eql :prototype($$) {
	$_ = shift;
	my $rhs = shift;

	return 1 if $_ == $rhs;
	return 0 unless kind $rhs == kind;

	return data $rhs == data if kind($_) == INT_KIND;
	return data $rhs eq data if kind($_) == STR_KIND;
	return 0 unless kind($_) == LIST_KIND;

	my @l = adata;
	my @r = adata $rhs;
	return 0 unless $#l == $#r;
	are_eql($l[$_], $r[$_]) or return 0 for 0..$#l;
	1
}

sub compare :prototype($$);
sub compare :prototype($$) {
	$_ = shift;

	return data() <=> to_int(shift) if kind($_) == INT_KIND;
	return data() cmp to_str(shift) if kind($_) == STR_KIND;
	return data() <=> !!to_bool(shift) if kind($_) == BOOL_KIND;
	my @lhs = adata;
	my @rhs = to_list shift;
	my $limit = $#lhs < $#rhs ? $#lhs : $#rhs;
	for (my $i = 0; $i <= $limit; $i++) {
		my $cmp = compare($lhs[$i], $rhs[$i]);
		return $cmp if $cmp;
	}
	$#lhs <=> $#rhs

}

sub run {
	my $value = shift;
	my ($kind, $data) = @{$value}{'kind','data'};

	return $value if $kind < VAR_KIND;
	return $data if $kind == VAR_KIND;

	$value->{func}->(@{$value->{args}})
}

sub parse :prototype(_);

my %functions = (
	'P' => [0, sub { newstr scalar <>; }],
	'R' => [0, sub { newint int rand 0xffff_ffff }],

	'E' => [1, sub { run parse to_str shift }],
	'B' => [1, sub { shift }],
	'C' => [1, sub { run run shift }],
	'`' => [1, sub { my $str = to_str shift; newstr scalar `$str` }],
	'Q' => [1, sub { exit to_int shift }],
	'!' => [1, sub { newbool !to_bool shift }],
	'L'  => [1, sub { my @a = to_list shift; newint scalar @a }],
	'D'  => [1, sub { $_ = run shift; print repr $_; $_ }],
	'O'  => [1, sub { $_ = to_str shift; s/\\$// or $_ .= "\n"; print; $NULL }],
	'A'  => [1, sub {
		$_ = run shift;
		return newstr chr data if kind($_) == INT_KIND;
		newint ord data
	}],
	'~'  => [1, sub { newint -to_int shift }],
	','  => [1, sub { newlist run shift }],
	'['  => [1, sub {
		$_ = run shift;
		return newstr substr data, 0, 1 if kind($_) == STR_KIND;
		(adata)[0];
	}],
	']'  => [1, sub {
		$_ = run shift;
		return newstr substr data, 1, length data if kind($_) == STR_KIND;
		my @list = adata;
		newlist @list[1..$#list];
	}],

	'+' => [2, sub {
		$_ = run shift;
		return newint data() + to_int shift if kind($_) == INT_KIND;
		return newstr data() . to_str shift if kind($_) == STR_KIND;
		newlist adata, to_list shift
	}],
	'-' => [2, sub { newint to_int(shift) - to_int(shift) }],
	'*' => [2, sub {
		my $tmp = run shift;
		my $amnt = to_int shift;
		$_ = $tmp;

		return newint data() * $amnt if kind($_) == INT_KIND;
		return newstr data() x $amnt if kind($_) == STR_KIND;

		my @list;
		@list = (@list, adata) while ($amnt--);
		newlist @list
	}],
	'/' => [2, sub { newint to_int(shift) / to_int(shift) }],
	'%' => [2, sub { newint to_int(shift) % to_int(shift) }],
	'^' => [2, sub {
		$_ = run shift;
		return newint data() ** to_int shift if kind($_) == INT_KIND;
		my @eles = adata;
		newstr join to_str(shift), map{to_str $_} @eles
	}],
	'<' => [2, sub { newbool(0 > compare run(shift), run(shift)) }],
	'>' => [2, sub { newbool(0 < compare run(shift), run(shift)) }],
	'?' => [2, sub { newbool are_eql run(shift), run(shift) }],
	'&' => [2, sub { $_ = run shift; to_bool($_) ? run(shift) : $_; }],
	'|' => [2, sub { $_ = run shift; to_bool($_) ? $_ : run(shift); }],
	';' => [2, sub { run shift; run shift }],
	'=' => [2, sub { assign_variable $_[0], run $_[1]; }],
	'W' => [2, sub { run $_[1] while to_bool $_[0]; $NULL }],

	'I' => [3, sub { run $_[!to_bool shift] }],
	'G' => [3, sub {
		my $cont = run shift;
		my $idx = to_int shift;
		my $len = to_int shift;

		return newstr substr data $cont, $idx, $len if kind($cont) == STR_KIND;
		my @list = adata $cont;
		newlist @list[$idx..$idx + $len - 1]
	}],
	'S' => [4, sub {
		my $cont = run shift;
		my $idx = to_int shift;
		my $len = to_int shift;
		my $repl = run shift;

		if (kind($cont) == STR_KIND) {
			return newstr substr(data $cont, 0, $idx) . to_str($repl) . substr(data $cont, $idx + $len);
		}

		my @list = adata $cont;
		return newlist @list[0..$idx-1], to_list($repl), @list[$idx + $len..$#list];
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

	{ kind => FUNC_KIND, func => $func, args => \@args }
}

my $flag = shift;

die "usage: $0 (-e 'expr' | -f file)" unless !$#ARGV && ($flag eq '-e' || $flag eq '-f');

my $expr = parse($flag eq '-e' ? shift : join '', <>) or die 'nothing to parse?';
run $expr;
