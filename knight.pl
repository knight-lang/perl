#!/usr/bin/perl

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
	my $name = shift;
	$known_variables{$name} ||= { kind => VAR_KIND, data => undef }
}

sub assign_variable {
	my ($variable, $value) = @_;
	$variable->{data} = $value;
}

sub run;

sub explode {
	@{shift()}{'kind','data'}
}

sub new_int {
	{kind => INT_KIND, data => int shift}
}

sub new_str {
	{kind => STR_KIND, data => shift}
}

sub new_list {
	{kind => LIST_KIND, data => [@_]}
}

sub new_bool { shift ? $TRUE : $FALSE }

######################
# Conversion Methods #
######################
sub run_if_needed {
	my $value = shift;
	$value = run $value if VAR_KIND <= $value->{kind};
	$value
}

sub to_int {
	my ($kind, $data) = explode run_if_needed shift;

	return int @$data if $kind == LIST_KIND;
	return int $data unless $kind == STR_KIND;

	# Normal perl string->int conversion doesn't follow the knight spec.
	($data =~ /^\s*([-+]?\d+)/) ? $1 : 0
}

sub to_str {
	my ($kind, $data) = explode run_if_needed shift;

	return $data if $kind <= STR_KIND;
	return join "\n", map{to_str($_)} @$data if $kind == LIST_KIND;
	return '' if $kind == NULL_KIND;
	$data ? 'true' : 'false'
}

sub to_bool {
	my ($kind, $data) = explode run_if_needed shift;

	return '' ne $data if $kind == STR_KIND;
	return scalar @$data if $kind == LIST_KIND;
	$data
}

sub to_list {
	my ($kind, $data) = explode run_if_needed shift;

	return @$data if $kind == LIST_KIND;
	return map {new_str $_} split(//, $data) if $kind == STR_KIND;

	if ($kind == INT_KIND) {
		my $is_neg = $data < 0;
		return map {$is_neg and $_ = -$_; new_int $_} split //, abs $data
	}

	$data ? ($TRUE) : ();
}

sub repr {
	my ($kind, $data) = explode shift;

	return $data if $kind == INT_KIND;
	return $data ? 'true' : 'false' if $kind == BOOL_KIND;
	return 'null' if $kind == NULL_KIND;
	return '[' . join(', ', map {repr($_)} @$data) . ']' if $kind == LIST_KIND;
	if ($kind == STR_KIND) {
		my $r = '"';
		foreach (split //, $data) {
			if ($_ eq "\r") { $r .= '\r'; next }
			if ($_ eq "\n") { $r .= '\n'; next }
			if ($_ eq "\t") { $r .= '\t'; next }
			$r .= '\\' if $_ eq '\\' || $_ eq '"';
			$r .= $_;
		}
		return $r . '"'
	}
	"<other>"
}


# print to_bool new_str "";
# exit;
# print !to_bool $FALSE;

# print repr to_list new_int 123;
# exit;

sub are_eql {
	my ($lhs, $rhs) = @_;
	return 1 if $lhs == $rhs;

	my ($lkind, $ldata) = explode $lhs;
	my ($rkind, $rdata) = explode $rhs;

	return 0 unless $lkind == $rkind;
	return $ldata == $rdata if $lkind == INT_KIND;
	return $ldata eq $rdata if $lkind == STR_KIND;
	return 0 unless $lkind == LIST_KIND;

	my @l = @$ldata;
	my @r = @$rdata;
	return 0 unless $#l == $#r;
	are_eql($l[$_], $r[$_]) or return 0 for 0..$#l;
	1
}

sub compare {
	my ($lhs, $rhs) = @_;
	my ($lkind, $ldata) = explode $lhs;

	return $ldata <=> to_int $rhs if $lkind == INT_KIND;
	return $ldata cmp to_str $rhs if $lkind == STR_KIND;
	return $ldata <=> !!to_bool $rhs if $lkind == BOOL_KIND;

	my @lhs = @$ldata;
	my @rhs = to_list $rhs;
	my $limit = $#lhs < $#rhs ? $#lhs : $#rhs;

	# Compare individual elements
	my $cmp;
	for (my $i = 0; $i <= $limit; $i++) {
		$cmp = compare($lhs[$i], $rhs[$i]) and return $cmp;
	}

	# Compare lengths
	$#lhs <=> $#rhs
}

sub run {
	my $value = shift;
	my ($kind, $data) = explode $value;

	return $value if $kind < VAR_KIND;
	return $data if $kind == VAR_KIND;

	$value->{func}->(@{$value->{args}})
}

sub parse :prototype(_);

our %functions;
sub register {
	my ($name, $arity, $sub) = @_;
	$functions{$name} = [$arity, $sub];
}

register 'P', 0, sub {
	my $line = <>;
	return $NULL unless defined $line;
	$line =~ s/\r*\n?$//;
	new_str $line
};
register 'R', 0, sub { new_int int rand 0xffff_ffff };
register 'E', 1, sub { run parse to_str shift };
register 'B', 1, sub { shift };
register 'C', 1, sub { run run shift };
register '`', 1, sub { my $str = to_str shift; new_str scalar `$str` };
register 'Q', 1, sub { exit to_int shift };
register '!', 1, sub { new_bool !to_bool shift };
register 'L', 1, sub { my @l = to_list shift; new_int scalar @l };
register 'D', 1, sub { my $value = run shift; print repr $value; $value };
register 'O', 1, sub { $_ = to_str shift; s/\\$// or $_ .= "\n"; print; $NULL };
register 'A', 1, sub {
	my ($kind, $data) = explode run shift;
	$kind == INT_KIND ? new_str(chr $data) : new_int(ord $data)
};
register '~', 1, sub { new_int -to_int shift };
register ',', 1, sub { new_list run shift };
register '[', 1, sub {
	my ($kind, $data) = explode run shift;
	return new_str substr $data, 0, 1 if $kind == STR_KIND;
	$data->[0]
};
register ']', 1, sub {
	my ($kind, $data) = explode run shift;
	return new_str substr $data, 1 if $kind == STR_KIND;
	my @list = @$data;
	new_list @list[1..$#list];
};

register '+', 2, sub {
	my ($kind, $data) = explode run shift;

	return new_int $data + to_int shift if $kind == INT_KIND;
	return new_str $data . to_str shift if $kind == STR_KIND;
	new_list @$data, to_list shift
};

register '-', 2, sub { new_int to_int(shift) - to_int(shift) };
register '*', 2, sub {
	my ($kind, $data) = explode run shift;
	my $amnt = to_int shift;

	return new_int $data * $amnt if $kind == INT_KIND;
	return new_str $data x $amnt if $kind == STR_KIND;

	my @list;
	@list = (@list, @$data) while ($amnt--);
	new_list @list
};
register '/', 2, sub { new_int to_int(shift) / to_int(shift) };
register '%', 2, sub { new_int to_int(shift) % to_int(shift) };
register '^', 2, sub {
	my ($kind, $data) = explode run shift;
	return new_int $data ** to_int shift if $kind == INT_KIND;

	new_str join to_str(shift), map{to_str $_} @$data
};
register '<', 2, sub { new_bool(0 > compare run(shift), run(shift)) };
register '>', 2, sub { new_bool(0 < compare run(shift), run(shift)) };
register '?', 2, sub { new_bool are_eql run(shift), run(shift) };
register '&', 2, sub { my $v = run shift; to_bool($v) ? run(shift) : $v; };
register '|', 2, sub { my $v = run shift; to_bool($v) ? $v : run(shift); };
register ';', 2, sub { run shift; run shift };
register '=', 2, sub {
	my ($variable, $value) = @_;
	assign_variable $variable, run $value;
};
register 'W', 2, sub {
	my ($cond, $body) = @_;
	run $body while to_bool $cond;
	$NULL
};

register 'I', 3, sub {
	my ($cond, $iftrue, $iffalse) = @_;
	run(to_bool($cond) ? $iftrue : $iffalse)
};

register 'G', 3, sub {
	my ($kind, $data) = explode run shift;
	my $idx = to_int shift;
	my $len = to_int shift;

	return new_str substr $data, $idx, $len if $kind == STR_KIND;
	my @list = @$data;
	new_list @list[$idx..$idx + $len - 1]
};
register 'S', 4, sub {
	my ($kind, $data) = explode run shift;
	my $idx = to_int shift;
	my $len = to_int shift;
	my $repl = run shift;

	if ($kind == STR_KIND) {
		return new_str substr($data, 0, $idx) . to_str($repl) . substr($data, $idx + $len);
	}

	my @list = @$data;
	return new_list @list[0..$idx-1], to_list($repl), @list[$idx + $len..$#list];
};

sub parse :prototype(_);
sub parse :prototype(_) {
	$_ = shift;
	s/^(?:[\s():]|#\N*)+//;

	s/^\d+// and return new_int $&;
	s/^(["'])(.*?)\1//s and return new_str $2;
	s/^[a-z_][a-z0-9_]*// and return lookup_variable $&;
	s/^([TF])[A-Z_]*// and return new_bool($1 eq 'T');
	s/^N[A-Z_]*// and return $NULL;
	s/^@// and return new_list;

	s/^([A-Z]+|.)// or return;
	my $name = substr $1, 0, 1;
	my ($arity, $func) = @{$functions{$name} or die "unknown token start '$name'"};
	my @args;

	for (my $i = 0; $i < $arity; $i++) {
		push @args, (parse or die "missing argument $i for function '$name'");
	}

	{ kind => FUNC_KIND, func => $func, args => \@args }
}

my $flag = shift @ARGV;
unless ($#ARGV == 0 && ($flag eq '-e' || $flag eq '-f')) {
	die "usage: $0 (-e 'expr' | -f file)"
}

my $expr = parse($flag eq '-e' ? shift : join '', <>) or die 'nothing to parse?';
run $expr;
