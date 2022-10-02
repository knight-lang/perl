#!/usr/bin/perl

use warnings;
use strict;

no warnings 'recursion'; # `run` has lots of recursion

# Types in this implementation are handled via hashes: The `kind` value is one
# of the following constants, and the `data` value corresponds to the data of
# that type. Only the `FUNC_KIND` functions differently---instead of a `data`
# field, it has both `func` and `args` fields.

#####################################
# Value representation and creation #
#####################################
use constant INT_KIND => 0;
use constant STR_KIND => 1;
use constant LIST_KIND => 2;
use constant BOOL_KIND => 3;
use constant NULL_KIND => 4;
use constant VAR_KIND => 5;
use constant FUNC_KIND => 6;

our $NULL =  { kind => NULL_KIND, data => 0 };
our $TRUE =  { kind => BOOL_KIND, data => 1 };
our $FALSE = { kind => BOOL_KIND, data => 0 };

sub new_int  { {kind => INT_KIND,  data => int shift} }
sub new_str  { {kind => STR_KIND,  data => shift} }
sub new_list { {kind => LIST_KIND, data => [@_]} }
sub new_bool { shift ? $TRUE : $FALSE }

our %known_variables;
sub lookup_variable {
	my $name = shift;
	$known_variables{$name} ||= { kind => VAR_KIND, data => undef }
}

###################
# Utility Methods #
###################

# Returns the data and kind of its argument
sub explode {
	@{shift()}{'kind','data'}
}

sub run;
sub run_if_needed {
	my $value = shift;
	$value = run $value if VAR_KIND <= $value->{kind};
	$value
}

####################
# Value Conversion #
####################

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
	return $data ? $TRUE : () unless $kind == INT_KIND;
	map {new_int($data < 0 ? -$_ : $_)} split //, abs $data
}

sub repr {
	my ($kind, $data) = explode shift;

	return $data if $kind == INT_KIND;
	return $data ? 'true' : 'false' if $kind == BOOL_KIND;
	return 'null' if $kind == NULL_KIND;
	return '[' . join(', ', map {repr($_)} @$data) . ']' if $kind == LIST_KIND;
	return "<other>" unless $kind == STR_KIND;

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
}


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
	die "cannot compare $lkind" unless $lkind == LIST_KIND;

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

register 'R', 0, sub {
	new_int int rand 0xffff_ffff
};

sub parse;
register 'E', 1, sub {
	run parse to_str shift
};

register 'B', 1, sub {
	shift
};

register 'C', 1, sub {
	run run shift
};

register '`', 1, sub {
	my $str = to_str shift; new_str scalar `$str`
};

register 'Q', 1, sub {
	exit to_int shift
};


register '!', 1, sub {
	new_bool !to_bool shift
};

register 'L', 1, sub {
	# We cant make this one because if `to_list` returns a single element, it
	# won't return 1 from `scalar`, but rather the element's pointer..
	my @list = to_list shift;
	new_int scalar @list
};

register 'D', 1, sub {
	my $value = run shift;
	print repr $value;
	$value
};

register 'O', 1, sub {
	$_ = to_str shift;
	s/\\$// or $_ .= "\n";
	print;
	$NULL
};

register 'A', 1, sub {
	my ($kind, $data) = explode run shift;
	return new_str chr $data if $kind == INT_KIND;
	return new_int ord $data if $kind == STR_KIND;
	die "cannot ascii $kind";
};

register '~', 1, sub {
	new_int -to_int shift
};

register ',', 1, sub {
	new_list run shift
};

register '[', 1, sub {
	my ($kind, $data) = explode run shift;

	return new_str substr $data, 0, 1 if $kind == STR_KIND;
	return $data->[0] if $kind == LIST_KIND;

	die "cannot get head of $kind"
};

register ']', 1, sub {
	my ($kind, $data) = explode run shift;

	return new_str substr $data, 1 if $kind == STR_KIND;
	return new_list @{$data}[1..$#$data] if $kind == LIST_KIND;

	die "cannot get tail of $kind";
};

register '+', 2, sub {
	my ($kind, $data) = explode run shift;

	return new_int $data + to_int shift if $kind == INT_KIND;
	return new_str $data . to_str shift if $kind == STR_KIND;
	return new_list @$data, to_list shift if $kind == LIST_KIND;

	die "cannot add $kind";
};

register '-', 2, sub {
	new_int to_int(shift) - to_int(shift)
};

register '*', 2, sub {
	my ($kind, $data) = explode run shift;
	my $amnt = to_int shift;

	return new_int $data * $amnt if $kind == INT_KIND;
	return new_str $data x $amnt if $kind == STR_KIND;
	die "cannot multiply $kind" unless $kind == LIST_KIND;

	my @list;
	@list = (@list, @$data) while $amnt--;
	return new_list @list;
};

register '/', 2, sub {
	new_int to_int(shift) / (to_int(shift) or die "cannot divide by zero")
};

register '%', 2, sub {
	new_int to_int(shift) % (to_int(shift) or die "cannot modulo by zero")
};

register '^', 2, sub {
	my ($kind, $data) = explode run shift;

	return new_int $data ** to_int shift if $kind == INT_KIND;
	return new_str join to_str(shift), map{to_str $_} @$data if $kind == LIST_KIND;

	die "cannot exponentiate $kind";
};

register '<', 2, sub {
	new_bool(0 > compare run(shift), run(shift))
};

register '>', 2, sub {
	new_bool(0 < compare run(shift), run(shift))
};

register '?', 2, sub {
	new_bool are_eql run(shift), run(shift)
};

register '&', 2, sub {
	my $value = run shift;
	return $value unless to_bool $value;
	run shift;
};

register '|', 2, sub {
	my $value = run shift;
	return $value if to_bool $value;
	run shift
};

register ';', 2, sub {
	run shift;
	run shift
};

register '=', 2, sub {
	my ($variable, $value) = @_;
	die "cannot assign to $variable->{kind}" unless $variable->{kind} == VAR_KIND;
	$variable->{data} = run $value
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
	return new_list @{$data}[$idx..$idx + $len - 1] if $kind == LIST_KIND;

	die "cannot get subcontainer of $kind";
};

register 'S', 4, sub {
	my ($kind, $data) = explode run shift;
	my $idx = to_int shift;
	my $len = to_int shift;
	my $repl = run shift;

	if ($kind == STR_KIND) {
		return new_str(
			substr($data, 0, $idx)
			. to_str($repl)
			. substr($data, $idx + $len)
		);
	}

	if ($kind == LIST_KIND) {
		return new_list(
			@{$data}[0..$idx-1],
			to_list($repl),
			@{$data}[$idx + $len..$#$data]
		);
	}

	die "cannot set subcontainer of $kind";
};

sub parse {
	$_ = shift;

	# Strip comments and whitespace
	s/^(?:[\s():]|#\N*)+//;

	# Parse non-functions with the simple regex.
	s/^\d+// and return new_int $&;
	s/^(["'])(.*?)\1//s and return new_str $2;
	s/^[a-z_][a-z0-9_]*// and return lookup_variable $&;
	s/^([TF])[A-Z_]*// and return new_bool($1 eq 'T');
	s/^N[A-Z_]*// and return $NULL;
	s/^@// and return new_list;

	# If we can't parse a function, return nothing.
	s/^([A-Z_]+|.)// or return;
	my $name = substr $&, 0, 1;
	my ($arity, $func) = @{$functions{$name} or die "unknown token start '$name'"};

	# Parse Arguments
	my @args;
	for (my $i = 0; $i < $arity; $i++) {
		push @args, (parse $_ or die "missing argument $i for function '$name'");
	}

	# Create the function
	{ kind => FUNC_KIND, func => $func, args => \@args }
}

my $flag = shift @ARGV;
unless ($#ARGV == 0 && ($flag eq '-e' || $flag eq '-f')) {
	die "usage: $0 (-e 'expr' | -f file)"
}

my $expr = parse($flag eq '-e' ? shift : join '', <>) or die 'nothing to parse?';
run $expr;
