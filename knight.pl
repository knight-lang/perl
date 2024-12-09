#!/usr/bin/perl

use warnings;
use strict;
no warnings 'recursion';

# Types in this implementation are handled via hashes: The `kind` value is one
# of the following constants, and the `data` value corresponds to the data of
# that type. Only the `KIND_FUNC` functions differently---instead of a `data`
# field, it has both `func` and `args` fields.

####################################################################################################
#                                          Value Creation                                          #
####################################################################################################

use constant KIND_INT  => 0;
use constant KIND_STR  => 1;
use constant KIND_LIST => 2;
use constant KIND_BOOL => 3;
use constant KIND_NULL => 4;
use constant KIND_VAR  => 5;
use constant KIND_FUNC => 6;

use constant IDX_KIND => 0;
use constant IDX_DATA => 1;
use constant IDX_FUNC => 1;
use constant IDX_ARGS => 2;

our $NULL =  [KIND_NULL, 0];
our $TRUE =  [KIND_BOOL, 1];
our $FALSE = [KIND_BOOL, 0];

sub new_int  { [KIND_INT,  int shift] }
sub new_str  { [KIND_STR,  shift] }
sub new_list { [KIND_LIST, [@_]] }
sub new_bool { shift ? $TRUE : $FALSE }

our %known_variables;
sub lookup_variable {
	$known_variables{$_[0]} ||= [KIND_VAR, undef]
}

####################################################################################################
#                                            Utilities                                             #
####################################################################################################

# Returns the data and kind of its argument
sub explode {
	@{shift()}[IDX_KIND, IDX_DATA]
}

sub run;
sub run_if_needed {
	my $value = shift;
	KIND_VAR <= $value->[IDX_KIND] ? run $value : $value;
}

####################################################################################################
#                                            Conversion                                            #
####################################################################################################

# Converts its argument to an integer.
sub to_int {
	my ($kind, $data) = explode run_if_needed shift;

	$kind == KIND_LIST and return int @$data;
	# Normal perl string->int conversion doesn't follow the knight spec.
	$kind == KIND_STR  and return ($data =~ /^\s*([-+]?\d+)/) ? $1 : 0;

	int $data
}


# Converts its argument to a string.
sub to_str {
	my ($kind, $data) = explode run_if_needed shift;

	$kind <= KIND_STR  and return $data;
	$kind == KIND_LIST and return join "\n", map{to_str($_)} @$data;
	$kind == KIND_NULL and return '';

	$data ? 'true' : 'false'
}

# Converts its argument to a boolean.
sub to_bool {
	my ($kind, $data) = explode run_if_needed shift;

	$kind == KIND_STR  and return '' ne $data;
	$kind == KIND_LIST and return scalar @$data;

	$data
}

# Converts its argument to a list.
sub to_list {
	my ($kind, $data) = explode run_if_needed shift;

	$kind == KIND_LIST and return @$data;
	$kind == KIND_STR  and return map {new_str $_} split(//, $data);
	$kind == KIND_INT  and return map {new_int($data < 0 ? -$_ : $_)} split //, abs $data;

	$data ? $TRUE : ()
}

####################################################################################################
#                                     Interacting With Values                                      #
####################################################################################################

# Gets a string representation of its argument.
sub repr {
	my ($kind, $data) = explode shift;

	$kind == KIND_INT  and return $data;
	$kind == KIND_BOOL and return $data ? 'true' : 'false';
	$kind == KIND_NULL and return 'null';
	$kind == KIND_LIST and return '[' . join(', ', map {repr($_)} @$data) . ']';
	$kind != KIND_STR  and return '<other>';

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

# Sees if two values are equal. Essentially `==`/`eq` for values.
sub are_eql {
	my ($lhs, $rhs) = @_;
	$lhs == $rhs                 and return 1; # Exact same object
	$lhs->[IDX_KIND] != $rhs->[IDX_KIND] and return 0; # Kinds aren't the same

	my ($lkind, $ldata) = explode $lhs;
	$lkind == KIND_INT  and return $ldata == $rhs->[IDX_DATA];
	$lkind == KIND_STR  and return $ldata eq $rhs->[IDX_DATA];
	$lkind != KIND_LIST and return 0; # All other kinds aren't equal

	my @l = @$ldata;
	my @r = @{$rhs->[IDX_DATA]};
	return 0 unless $#l == $#r;
	are_eql($l[$_], $r[$_]) or return 0 for 0..$#l;
	1
}

# Compares two values. Essentially `<=>`/`cmp` for values.
sub compare {
	my ($lhs, $rhs) = @_;
	my ($lkind, $ldata) = explode $lhs;

	$lkind == KIND_INT  and return $ldata <=> to_int $rhs;
	$lkind == KIND_STR  and return $ldata cmp to_str $rhs;
	$lkind == KIND_BOOL and return $ldata <=> !!to_bool $rhs;
	$lkind != KIND_LIST and die "cannot compare $lkind";

	my @lhs = @$ldata;
	my @rhs = to_list $rhs;
	my $limit = $#lhs < $#rhs ? $#lhs : $#rhs;

	# Compare individual elements
	my $cmp;
	for (my $i = 0; $i <= $limit; $i++) {
		return $cmp if $cmp = compare($lhs[$i], $rhs[$i]);
	}

	# Compare lengths
	$#lhs <=> $#rhs
}

# Executes its argument.
sub run {
	my $value = shift;
	my ($kind, $data) = explode $value;

	$kind < KIND_VAR  and return $value;
	$kind == KIND_VAR and return $data;

	# Manual tail-call recursion lmao
	@_ = @{$value->[IDX_ARGS]};
	goto $value->[IDX_FUNC]
}

####################################################################################################
#                                         Knight Functions                                         #
####################################################################################################

our %functions;
sub register {
	my ($name, $arity, $sub) = @_;
	$functions{$name} = [$arity, $sub];
}

# Reads a line from stdin.
register 'P', 0, sub {
	my $line = <STDIN>;
	return $NULL unless defined $line;
	$line =~ s/\r*\n?$//;
	new_str $line
};

# Gets a random integer from 0-0xffffffff
register 'R', 0, sub {
	new_int int rand 0xffff_ffff
};

# Evaluates its argument as knight code.
sub parse;
register 'E', 1, sub {
	run parse to_str shift
};

# Simply returns the argument unchanged.
register 'B', 1, sub {
	shift
};

# Calls a `B`'s return value.
register 'C', 1, sub {
	run run shift
};

# Executes its argument as a shell command, and returns it.
register '$', 1, sub {
	my $str = to_str shift;
	new_str scalar `$str`
};

# Stops the interpreter with the given exit code.
register 'Q', 1, sub {
	exit to_int shift
};

# Logically negates its argument.
register '!', 1, sub {
	new_bool !to_bool shift
};

# The length negates its argument.
register 'L', 1, sub {
	# We cant make this one-line because if `to_list` returns a single element,
	# it won't return 1 from `scalar`, but rather the element's pointer..
	my @list = to_list shift;
	new_int scalar @list
};

# Writes a debugging representation to stdout and then returns it.
register 'D', 1, sub {
	my $value = run shift;
	print repr $value;
	$value
};

# Writes the argument to stdout. If it ends with `\`, that's stripped,
# otherwise, it prints a newline.
register 'O', 1, sub {
	$_ = to_str shift;
	s/\\$// or $_ .= "\n";
	print;
	$NULL
};

# Returns either the `chr` or `ord` of its argument, depending on its type.
register 'A', 1, sub {
	my ($kind, $data) = explode run shift;
	$kind == KIND_INT and return new_str chr $data;
	$kind == KIND_STR and return new_int ord $data;
	die "cannot ascii $kind";
};

# Logically negates its argument.
register '~', 1, sub {
	new_int -to_int shift
};

# Returns a list of just its argument.
register ',', 1, sub {
	new_list run shift
};

# Gets the first element/character of its argument.
register '[', 1, sub {
	my ($kind, $data) = explode run shift;

	$kind == KIND_STR  and return new_str substr $data, 0, 1;
	$kind == KIND_LIST and return $data->[0];

	die "cannot get head of $kind"
};

# Gets everything _but_ first element/character of its argument.
register ']', 1, sub {
	my ($kind, $data) = explode run shift;

	$kind == KIND_STR  and return new_str substr $data, 1;
	$kind == KIND_LIST and return new_list @{$data}[1..$#$data];

	die "cannot get tail of $kind";
};

# Adds/concatenates its arguments together.
register '+', 2, sub {
	my ($kind, $data) = explode run shift;

	$kind == KIND_INT  and return new_int $data + to_int shift;
	$kind == KIND_STR  and return new_str $data . to_str shift;
	$kind == KIND_LIST and return new_list @$data, to_list shift;

	die "cannot add $kind";
};

# Subtracts the second argument from the first.
register '-', 2, sub {
	new_int to_int(shift) - to_int(shift)
};

# Multiplies/repeats its first argument with/by the second.
register '*', 2, sub {
	my ($kind, $data) = explode run shift;
	my $amnt = to_int shift; # all 3 types use an integer for amount.

	$kind == KIND_INT  and return new_int $data * $amnt;
	$kind == KIND_STR  and return new_str $data x $amnt;
	$kind != KIND_LIST and die "cannot multiply $kind";

	my @list;
	@list = (@list, @$data) while $amnt--;
	return new_list @list;
};

# Divides the first argument by the second. Second cannot be zero.
register '/', 2, sub {
	new_int to_int(shift) / (to_int(shift) or die "cannot divide by zero")
};

# Modulos the first argument by the second. Second cannot be zero.
register '%', 2, sub {
	new_int to_int(shift) % (to_int(shift) or die "cannot modulo by zero")
};

# Exponentiates integers or `join`s a list by a string.
register '^', 2, sub {
	my ($kind, $data) = explode run shift;

	$kind == KIND_INT  and return new_int $data ** to_int shift;
	$kind == KIND_LIST and return new_str join to_str(shift), map{to_str $_} @$data;

	die "cannot exponentiate $kind";
};

# Sees if the first argument is smaller than the second.
register '<', 2, sub {
	new_bool(0 > compare run(shift), run(shift))
};

# Sees if the first argument is larger than the second.
register '>', 2, sub {
	new_bool(0 < compare run(shift), run(shift))
};

# Sees if two arguments are equal.
register '?', 2, sub {
	new_bool are_eql run(shift), run(shift)
};

# If the executed first argument is falsey, it's returned. Otherwise the second
# executed and returned.
register '&', 2, sub {
	my $value = run shift;
	to_bool($value) ? run shift : $value;
};

# If the executed first argument is truthy, it's returned. Otherwise the second
# executed and returned.
register '|', 2, sub {
	my $value = run shift;
	to_bool($value) ? $value : run shift;
};

# Executes the first argument and then executes and returns the second.
register ';', 2, sub {
	run shift;
	run shift
};

# Assigns the first argument to the second. The first must be a variable.
register '=', 2, sub {
	my ($variable, $value) = @_;
	$variable->[IDX_KIND] == KIND_VAR or die "can't assign to $variable->[IDX_KIND]";
	$variable->[IDX_DATA] = run $value
};

# Executes the second argument whilst the first is true.
register 'W', 2, sub {
	my ($cond, $body) = @_;
	run $body while to_bool $cond;
	$NULL
};

# Executes the second/third argument depending on the truthiness of the first.
register 'I', 3, sub {
	my ($cond, $iftrue, $iffalse) = @_;
	run to_bool($cond) ? $iftrue : $iffalse
};

# Gets a sublist/substring of the first argument with the given range.
register 'G', 3, sub {
	my ($kind, $data) = explode run shift;
	my $idx = to_int shift;
	my $len = to_int shift;

	$kind == KIND_STR  and return new_str substr $data, $idx, $len;
	$kind == KIND_LIST and return new_list @{$data}[$idx..$idx + $len - 1];

	die "cannot get subcontainer of $kind";
};

# Replaces a new sublist/substring where the first argument's range is replaced
# with the fourth argument.
register 'S', 4, sub {
	my ($kind, $data) = explode run shift;
	my $idx = to_int shift;
	my $len = to_int shift;
	my $repl = run shift;

	if ($kind == KIND_STR) {
		return new_str(
			substr($data, 0, $idx)
			. to_str($repl)
			. substr($data, $idx + $len)
		);
	}

	if ($kind == KIND_LIST) {
		return new_list(
			@{$data}[0..$idx-1],
			to_list($repl),
			@{$data}[$idx + $len..$#$data]
		);
	}

	die "cannot set subcontainer of $kind";
};

####################################################################################################
#                                             Parsing                                              #
####################################################################################################

sub parse {
	$_ = shift;

	# Strip comments and whitespace
	s/^(?:[\s():]|#\N*)+//;

	# Parse non-functions with the simple regex.
	s/^\d+//              and return new_int $&;
	s/^(["'])(.*?)\1//s   and return new_str $2;
	s/^[a-z_][a-z0-9_]*// and return lookup_variable $&;
	s/^([TF])[A-Z_]*//    and return new_bool $1 eq 'T';
	s/^N[A-Z_]*//         and return $NULL;
	s/^@//                and return new_list;
	s/^([A-Z_]+|.)//      or  return; # If we can't parse a function, return nothing.

	my $name = substr $&, 0, 1;
	my ($arity, $func) = @{$functions{$name} or die "unknown character '$name'"};

	# Parse Arguments
	my @args;
	for (my $i = 0; $i < $arity; $i++) {
		push @args, (parse $_ or die "missing argument $i for function '$name'");
	}

	# Creates the function
	[KIND_FUNC, $func, \@args]
}

####################################################################################################
#                                  Command-Line Argument Handling                                  #
####################################################################################################

my $flag = shift || "";

my $expr;
if ($flag eq '-e') {
	$expr = shift;
} elsif ($flag eq '-f') {
	$expr = join '', <>;
}

die "usage: $0 (-e 'expr' | -f file)" unless defined($expr) && $#ARGV == -1;

run parse($expr) || die('nothing to parse?');
