#!/usr/bin/perl

# This implements Knight in perl. It should work on most modern perl versions, but I've only tested
# it on version 5.34.
#
# It's the standard tree-walker implementation, where objects are represented by a two-value-long
# array where the first value is the the kind of the object. I've written it in somewhat-readable
# perl.

####################################################################################################
#                                             Prelude                                              #
####################################################################################################

# Enable warnings and strict mode. We disable `recursion` as we do a lot of recursion in Knight.
use warnings;
use strict;
no warnings 'recursion';

####################################################################################################
#                                          Value Creation                                          #
####################################################################################################

# Constants for value representation.
use constant {
	KIND_INT  => 0,
	KIND_STR  => 1,
	KIND_LIST => 2,
	KIND_BOOL => 3,
	KIND_NULL => 4,
	KIND_VAR  => 5,
	KIND_FUNC => 6,
};

# Constants for indexing into values.
use constant {
	IDX_KIND => 0,
	IDX_DATA => 1,
};

# Constants used within Knight itself.
use constant {
	KN_NULL  => [KIND_NULL, 0],
	KN_TRUE  => [KIND_BOOL, 1],
	KN_FALSE => [KIND_BOOL, 0],
};

# The list of all variables. This is used within `new_var`.
our %variables;

# Creation functions
sub new_int  { [KIND_INT,  int shift] }
sub new_str  { [KIND_STR,  shift] }
sub new_list { [KIND_LIST, [@_]] }
sub new_bool { shift ? KN_TRUE : KN_FALSE }
sub new_var  { $variables{shift()} ||= [KIND_VAR, undef] }
sub new_func { [KIND_FUNC, @_] }

####################################################################################################
#                                            Conversion                                            #
####################################################################################################

# Utility function to execute arguments if needed.
sub run_if_needed {
	sub run;

	my $value = shift;
	KIND_VAR <= $value->[IDX_KIND] ? run $value : $value;
}


# Converts its argument to an integer.
sub to_int {
	my ($kind, $data) = @{run_if_needed shift};

	$kind == KIND_LIST and return int @$data;
	$kind == KIND_STR  and $data =~ /^\s*\K[-+]?\d+/, return $& || 0;

	int $data
}

# Converts its argument to a string.
sub to_str {
	my ($kind, $data) = @{run_if_needed shift};

	$kind <= KIND_STR  and return $data;
	$kind == KIND_LIST and return join "\n", map{to_str($_)} @$data;
	$kind == KIND_NULL and return '';

	$data ? 'true' : 'false'
}

# Converts its argument to a boolean.
sub to_bool {
	my ($kind, $data) = @{run_if_needed shift};

	$kind == KIND_STR  and return '' ne $data;
	$kind == KIND_LIST and return scalar @$data;

	$data
}

# Converts its argument to a list.
sub to_list {
	my ($kind, $data) = @{run_if_needed shift};

	$kind == KIND_LIST and return @$data;
	$kind == KIND_STR  and return map {new_str $_} split //, $data;
	$kind == KIND_INT  and return map {new_int $data < 0 ? -$_ : $_} split //, abs $data;

	$data ? KN_TRUE : ()
}

####################################################################################################
#                                     Interacting With Values                                      #
####################################################################################################

# Gets a string representation of its argument.
sub repr {
	my ($kind, $data) = @{shift()};

	$kind == KIND_INT  and return $data;
	$kind == KIND_BOOL and return $data ? 'true' : 'false';
	$kind == KIND_NULL and return 'null';
	$kind == KIND_LIST and return '[' . join(', ', map {repr($_)} @$data) . ']';
	$kind == KIND_STR  or  return '<other>';

	$_ = $data;
	s/[\\"]/\\$&/g;
	s/\r/\\r/g;
	s/\n/\\n/g;
	s/\t/\\t/g;
	return qq/"$_"/;
}

# Sees if two values are equal. Essentially `==`/`eq` for values.
sub are_eql {
	my ($lhs, $rhs) = @_;
	return 1 if $lhs == $rhs; # Exact same object
	return 0 unless $lhs->[IDX_KIND] == $rhs->[IDX_KIND]; # Kinds aren't the same

	my ($lkind, $ldata) = @$lhs;
	$lkind == KIND_INT  and return $ldata == $rhs->[IDX_DATA];
	$lkind == KIND_STR  and return $ldata eq $rhs->[IDX_DATA];
	$lkind == KIND_LIST or  return 0; # All other kinds aren't equal

	my @l = @$ldata;
	my @r = @{$rhs->[IDX_DATA]};
	return 0 unless $#l == $#r;
	are_eql($l[$_], $r[$_]) or return 0 for 0..$#l;
	1
}

# Compares two values. Essentially `<=>`/`cmp` for values.
sub compare {
	my ($lhs, $rhs) = @_;
	my ($lkind, $ldata) = @$lhs;

	$lkind == KIND_INT  and return $ldata <=> to_int $rhs;
	$lkind == KIND_STR  and return $ldata cmp to_str $rhs;
	$lkind == KIND_BOOL and return $ldata <=> !!to_bool $rhs;
	$lkind == KIND_LIST or  die "cannot compare $lkind";

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
	my ($value) = @_;
	$value->[IDX_KIND] < KIND_VAR  and return $value;
	$value->[IDX_KIND] == KIND_VAR and return $value->[IDX_DATA];

	(undef, my $sub, @_) = @$value;
	goto &$sub;
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
	$_ = <STDIN>; # Technically `<>` is the same, as the command-line args are all handled.
	return KN_NULL unless defined; # Ensure a line is read in
	s/\r*\n?$//; # Strip trailing `\r\n`
	new_str $_
};

# Gets a random integer from 0-0xffffffff
register 'R', 0, sub {
	new_int int rand 0xffff_ffff
};

# Evaluates its argument as knight code.
register 'E', 1, sub {
	sub play;
	play to_str shift
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
	my $shell_command = to_str shift;
	new_str scalar `$shell_command`
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
	KN_NULL
};

# Returns either the `chr` or `ord` of its argument, depending on its type.
register 'A', 1, sub {
	my ($kind, $data) = @{run shift};

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
	my ($kind, $data) = @{run shift};

	$kind == KIND_STR  and return new_str substr $data, 0, 1;
	$kind == KIND_LIST and return $data->[0];

	die "cannot get head of $kind"
};

# Gets everything _but_ first element/character of its argument.
register ']', 1, sub {
	my ($kind, $data) = @{run shift};

	$kind == KIND_STR  and return new_str substr $data, 1;
	$kind == KIND_LIST and return new_list @{$data}[1..$#$data];

	die "cannot get tail of $kind";
};

# Adds/concatenates its arguments together.
register '+', 2, sub {
	my ($kind, $data) = @{run shift};

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
	my ($kind, $data) = @{run shift};
	my $amnt = to_int shift; # all 3 types use an integer for amount.

	$kind == KIND_INT  and return new_int $data * $amnt;
	$kind == KIND_STR  and return new_str $data x $amnt;
	$kind == KIND_LIST or  die "cannot multiply $kind";

	my @list;
	@list = (@list, @$data) while $amnt--;
	return new_list @list;
};

# Divides the first argument by the second. Second cannot be zero.
register '/', 2, sub {
	new_int to_int(shift) / (to_int shift or die "cannot divide by zero")
};

# Modulos the first argument by the second. Second cannot be zero.
register '%', 2, sub {
	new_int to_int(shift) % (to_int shift or die "cannot modulo by zero")
};

# Exponentiates integers or `join`s a list by a string.
register '^', 2, sub {
	my ($kind, $data) = @{run shift};

	$kind == KIND_INT  and return new_int $data ** to_int shift;
	$kind == KIND_LIST and return new_str join to_str(shift), map { to_str $_ } @$data;

	die "cannot exponentiate $kind";
};

# Sees if the first argument is smaller than the second.
register '<', 2, sub {
	new_bool 0 > compare run(shift), run(shift)
};

# Sees if the first argument is larger than the second.
register '>', 2, sub {
	new_bool 0 < compare run(shift), run(shift)
};

# Sees if two arguments are equal.
register '?', 2, sub {
	new_bool are_eql run(shift), run(shift)
};

# If the executed first argument is falsey, it's returned. Otherwise the second
# is executed and returned.
register '&', 2, sub {
	my $value = run shift;
	to_bool($value) ? run shift : $value;
};

# If the executed first argument is truthy, it's returned. Otherwise the second
# is executed and returned.
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
	KN_NULL
};

# Executes the second/third argument depending on the truthiness of the first.
register 'I', 3, sub {
	my ($cond, $iftrue, $iffalse) = @_;
	run to_bool($cond) ? $iftrue : $iffalse
};

# Gets a sublist/substring of the first argument with the given range.
register 'G', 3, sub {
	my ($kind, $data) = @{run shift};
	my $idx = to_int shift;
	my $len = to_int shift;

	$kind == KIND_STR  and return new_str substr $data, $idx, $len;
	$kind == KIND_LIST and return new_list @{$data}[$idx..$idx + $len - 1];

	die "cannot get subcontainer of $kind";
};

# Replaces a new sublist/substring where the first argument's range is replaced
# with the fourth argument.
register 'S', 4, sub {
	my ($kind, $data) = @{run shift};
	my $idx  = to_int shift;
	my $len  = to_int shift;
	my $repl = run shift;

	$kind == KIND_STR and return new_str(
		substr($data, 0, $idx) . to_str($repl) . substr($data, $idx + $len)
	);

	$kind == KIND_LIST and return new_list(
		@{$data}[0..$idx-1], to_list($repl), @{$data}[$idx + $len..$#$data]
	);

	die "cannot set subcontainer of $kind";
};

####################################################################################################
#                                             Parsing                                              #
####################################################################################################

# Parse a variable out
sub parse {
	$_ = shift;

	# Strip comments and whitespace
	s/^(?:[\s():]|#\N*)+//;

	# Parse non-functions with the simple regex.
	s/^\d+//              and return new_int $&;
	s/^(["'])(.*?)\1//s   and return new_str $2;
	s/^[a-z_][a-z0-9_]*// and return new_var $&;
	s/^([TF])[A-Z_]*//    and return new_bool $1 eq 'T';
	s/^N[A-Z_]*//         and return KN_NULL;
	s/^@//                and return new_list;
	s/^([A-Z_]+|.)//      or  return; # If we can't parse a function, return nothing.

	# Get function name.
	my $name = substr $&, 0, 1;
	my ($arity, $func) = @{$functions{$name} or die "unknown token start '$name'"};

	# Parse Arguments
	my @args;
	foreach my $i (1..$arity) {
		push @args, parse($_) || die("missing argument $i for function '$name'");
	}

	# Creates the function
	new_func $func, @args
}

# Parse a program and execute it
sub play {
	my $program = parse shift or die "no program given";
	run $program
}

####################################################################################################
#                                  Command-Line Argument Handling                                  #
####################################################################################################

my $flag = shift || "";

my $expr;
if ($flag eq '-e') {
	$expr = shift;
} elsif ($flag eq '-f') {
	$expr = join "", <>; # Notably not <STDIN>
}

unless(defined($expr) && $#ARGV == -1) {
	print STDERR "usage: $0 (-e 'expr' | -f file)";
	exit 1;
}

play $expr;
