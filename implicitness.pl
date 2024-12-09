#!/usr/bin/perl

use warnings;
use strict;
no warnings 'recursion';

# Types in this implementation are handled via hashes: The `kind` value is one
# of the following constants, and the `data` value corresponds to the data of
# that type. Only the `FUNC_KIND` functions differently---instead of a `data`
# field, it has both `func` and `args` fields.

####################################################################################################
#                                          Value Creation                                          #
####################################################################################################

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
	$known_variables{$_[0]} ||= { kind => VAR_KIND, data => undef }
}

####################################################################################################
#                                            Utilities                                             #
####################################################################################################

# Returns the data and kind of its argument
sub explode(_) {
	@{shift()}{'kind','data'}
}

sub run(_);
sub run_if_needed {
	$_ = shift;
	VAR_KIND <= $_->{kind} ? run : $_;
}

####################################################################################################
#                                            Conversion                                            #
####################################################################################################

# Converts its argument to an integer.
sub to_int(_);
sub to_int(_) {
	my ($kind, $data) = explode run_if_needed shift;

	$kind == LIST_KIND and return int @$data;
	# Normal perl string->int conversion doesn't follow the knight spec.
	$kind == STR_KIND  and return ($data =~ /^\s*([-+]?\d+)/) ? $1 : 0;

	int $data
}

# Converts its argument to a string.
sub to_str(_);
sub to_str(_) {
	my ($kind, $data) = explode run_if_needed shift;

	$kind <= STR_KIND  and return $data;
	$kind == LIST_KIND and return join "\n", map{to_str($_)} @$data;
	$kind == NULL_KIND and return '';

	$data ? 'true' : 'false'
}

# Converts its argument to a boolean.
sub to_bool(_);
sub to_bool(_) {
	my ($kind, $data) = explode run_if_needed shift;

	$kind == STR_KIND  and return '' ne $data;
	$kind == LIST_KIND and return scalar @$data;

	$data
}

# Converts its argument to a list.
sub to_list(_);
sub to_list(_) {
	my ($kind, $data) = explode run_if_needed shift;

	$kind == LIST_KIND and return @$data;
	$kind == STR_KIND  and return map {new_str $_} split(//, $data);
	$kind == INT_KIND  and return map {new_int($data < 0 ? -$_ : $_)} split //, abs $data;

	$data ? $TRUE : ()
}

####################################################################################################
#                                     Interacting With Values                                      #
####################################################################################################

# Gets a string representation of its argument.
sub repr(_);
sub repr(_) {
	my ($kind, $data) = explode shift;

	$kind == INT_KIND  and return $data;
	$kind == BOOL_KIND and return $data ? 'true' : 'false';
	$kind == NULL_KIND and return 'null';
	$kind == LIST_KIND and return '[' . join(', ', map {repr($_)} @$data) . ']';
	$kind != STR_KIND  and return '<other>';

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
	$lhs->{kind} != $rhs->{kind} and return 0; # Kinds aren't the same

	my ($lkind, $ldata) = explode $lhs;
	$lkind == INT_KIND  and return $ldata == $rhs->{data};
	$lkind == STR_KIND  and return $ldata eq $rhs->{data};
	$lkind != LIST_KIND and return 0; # All other kinds aren't equal

	my @l = @$ldata;
	my @r = @{$rhs->{data}};
	return 0 unless $#l == $#r;
	are_eql($l[$_], $r[$_]) or return 0 for 0..$#l;
	1
}

# Compares two values. Essentially `<=>`/`cmp` for values.
sub compare {
	my ($lhs, $rhs) = @_;
	my ($lkind, $ldata) = explode $lhs;

	$lkind == INT_KIND  and return $ldata <=> to_int $rhs;
	$lkind == STR_KIND  and return $ldata cmp to_str $rhs;
	$lkind == BOOL_KIND and return $ldata <=> !!to_bool $rhs;
	$lkind != LIST_KIND and die "cannot compare $lkind";

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
sub run(_) {
	my $value = shift;
	my ($kind, $data) = explode $value;

	$kind < VAR_KIND  and return $value;
	$kind == VAR_KIND and return $data;

	# Manual tail-call recursion lmao
	@_ = @{$value->{args}};
	goto $value->{func}
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
	$kind == INT_KIND and return new_str chr $data;
	$kind == STR_KIND and return new_int ord $data;
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

	$kind == STR_KIND  and return new_str substr $data, 0, 1;
	$kind == LIST_KIND and return $data->[0];

	die "cannot get head of $kind"
};

# Gets everything _but_ first element/character of its argument.
register ']', 1, sub {
	my ($kind, $data) = explode run shift;

	$kind == STR_KIND  and return new_str substr $data, 1;
	$kind == LIST_KIND and return new_list @{$data}[1..$#$data];

	die "cannot get tail of $kind";
};

# Adds/concatenates its arguments together.
register '+', 2, sub {
	my ($kind, $data) = explode run shift;

	$kind == INT_KIND  and return new_int $data + to_int shift;
	$kind == STR_KIND  and return new_str $data . to_str shift;
	$kind == LIST_KIND and return new_list @$data, to_list shift;

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

	$kind == INT_KIND  and return new_int $data * $amnt;
	$kind == STR_KIND  and return new_str $data x $amnt;
	$kind != LIST_KIND and die "cannot multiply $kind";

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

	$kind == INT_KIND  and return new_int $data ** to_int shift;
	$kind == LIST_KIND and return new_str join to_str(shift), map{to_str $_} @$data;

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
	$variable->{kind} == VAR_KIND or die "can't assign to $variable->{kind}";
	$variable->{data} = run $value
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
	run(to_bool($cond) ? $iftrue : $iffalse)
};

# Gets a sublist/substring of the first argument with the given range.
register 'G', 3, sub {
	my ($kind, $data) = explode run shift;
	my $idx = to_int shift;
	my $len = to_int shift;

	$kind == STR_KIND  and return new_str substr $data, $idx, $len;
	$kind == LIST_KIND and return new_list @{$data}[$idx..$idx + $len - 1];

	die "cannot get subcontainer of $kind";
};

# Replaces a new sublist/substring where the first argument's range is replaced
# with the fourth argument.
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
	{ kind => FUNC_KIND, func => $func, args => \@args }
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
