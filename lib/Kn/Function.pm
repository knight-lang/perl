package Kn::Function;

use strict;
use warnings;
no warnings qw/recursion/; # Knight does a lot of recursion

# All known functoins.
my %funcs;

# Fetches the function associated with the given value, or `undef` if no such function exists.
sub get {
	$funcs{$_[1]}
}

# Registers a new function with the given name, arity, and body.
sub register {
	my ($class, $name, $argc, $func) = @_;
	$name = substr $name, 0, 1 or die 'a name is required';
	$funcs{$name} = bless { argc => $argc, name => $name, func => $func }, $class
}

# The amount of arguments in the function
sub arity {
	shift->{argc}
}

# Executes the function with the given arguments.
sub run {
	my ($self, @args) = @_;
	$self->{func}->(@args)
}

# Gets a single line from stdin.
__PACKAGE__->register('P', 0, sub {
	$_ = scalar <STDIN> or return Kn::Null->new;
	s/\r*\n?$//;
	Kn::String->new($_)
});

# Gets a random number from `0 .. 0xffff_ffff`.
__PACKAGE__->register('R', 0, sub {
	Kn::Number->new(int rand 0xffff_ffff)
});

# Evaluates a string as Knight code.
__PACKAGE__->register('E', 1, sub {
	Kn->run("$_[0]")
});

# Simply returns its argument, unevaluated.
__PACKAGE__->register('B', 1, sub {
	shift
});

# Runs a previously unevaluated block of code.
__PACKAGE__->register('C', 1, sub {
	shift->run->run
});

# Executes the argument as a shell command, then returns the entire stdout.
__PACKAGE__->register('$', 1, sub {
	Kn::String->new(join '', `$_[0]`)
});

# Quits with the given exit code.
__PACKAGE__->register('Q', 1, sub {
	exit shift
});

# Returns the logical negation of the argument.
__PACKAGE__->register('!', 1, sub {
	Kn::Boolean->new(!shift)
});

# Gets the length of the given argument as a string.
__PACKAGE__->register('L', 1, sub {
	Kn::Number->new(scalar @{shift->run})
});

# Dumps a value's representation, then returns it.
__PACKAGE__->register('D', 1, sub {
	my $val = shift->run;
	print $val->dump;
	$val
});

# Returns a new list with a single element.
__PACKAGE__->register(',', 1, sub {
	Kn::List->new(shift->run)
});

# Gets the first element/char of a list/string
__PACKAGE__->register('[', 1, sub {
	shift->run->head
});

# Gets everything but the first element/char of a list/string
__PACKAGE__->register(']', 1, sub {
	shift->run->tail
});

# Outputs the given argument, which it then returns. If the argument ends with
# a `\`, it's removed and no trailing newline is printed. Otherwise, a newline
# is added to the end of the string.
__PACKAGE__->register('O', 1, sub {
	my $val = shift->run;
	my $str = "$val";

	$str =~ s/\\$// or $str .= "\n";

	print $str;
	Kn::Null->new
});

# Gets the chr/ord of the first argument, depending on its type.
__PACKAGE__->register('A', 1, sub {
	shift->run->ascii
});

# Negates its argument.
__PACKAGE__->register('~', 1, sub {
	Kn::Number->new(-int shift->run)
});

# Adds two values together, coercing the second to the first's type.
__PACKAGE__->register('+', 2, sub {
	shift->run->add(shift->run)
});

# Subtracts the second value from the first
__PACKAGE__->register('-', 2, sub {
	shift->run->sub(shift->run)
});

# Multiplies two values together.
__PACKAGE__->register('*', 2, sub {
	shift->run->mul(shift->run)
});

# Divides the first number by the second.
__PACKAGE__->register('/', 2, sub {
	shift->run->div(shift->run)
});

# Gets the modulo of "first number / second".
__PACKAGE__->register('%', 2, sub {
	shift->run->mod(shift->run)
});

# Raises the first argument to the power of the second.
__PACKAGE__->register('^', 2, sub {
	shift->run->pow(shift->run)
});

# Checks to see if two values are equal.
__PACKAGE__->register('?', 2, sub {
	Kn::Boolean->new(shift->run->is_equal(shift->run))
});

# Checks to see if the first value is less than the second
__PACKAGE__->register('<', 2, sub {
	Kn::Boolean->new(shift->run->compare(shift->run) < 0)
});

# Checks to see if the first value is greater than the second
__PACKAGE__->register('>', 2, sub {
	Kn::Boolean->new(shift->run->compare(shift->run) > 0)
});

# Simply executes the first argument, then executes and returns second.
__PACKAGE__->register(';', 2, sub {
	shift->run;
	shift->run
});

# Assigns the second argument to the first. Errors if the first argument isn't a variable.
__PACKAGE__->register('=', 2, sub {
	shift->assign(shift->run)
});

# Executes the second argument while the first one evaluates to true. Returns `NULL`.
__PACKAGE__->register('W', 2, sub {
	my ($cond, $body) = @_;
	$body->run while $cond;
	Kn::Null->new
});

# If the first argument is falsey, it's returned. Otherwise, the second argument is executed and
# returned.
__PACKAGE__->register('&', 2, sub {
	my $lhs = shift->run;
	$lhs ? shift->run : $lhs
});

# If the first argument is truthy, it's returned. Otherwise, the second argument is executed and
# returned.
__PACKAGE__->register('|', 2, sub {
	my $lhs = shift->run;
	$lhs ? $lhs : shift->run
});

# If the first argument is true, evaluates and runs the second argument. Otherwise, evaluates and
# runs the third.
__PACKAGE__->register('I', 3, sub {
	$_[shift ? 0 : 1]->run
});

# Gets a substring/sublist of the first argument, starting at the second argument, with a length of
# the third argument.
__PACKAGE__->register('G', 3, sub {
	shift->run->get(@_)
});

# Returns a new string/list where the first argument's substring/sublist starting at the second
# argument with length the third argument is replaced with the fourth.
__PACKAGE__->register('S', 4, sub {
	shift->run->set(@_)
});

1;
