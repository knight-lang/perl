use constant foo => [1, 2];

$_ = "Abc";
s/A/$&$&/;
print;
# print foo == foo;

__END__
$x = [1,2,3,];
my ($a, *b) = @$x;
# my $a = 3, $b;
# print $a;
__END__
sub mypush (+@) {
    my $aref = shift;
    die "Not an array or arrayref" unless ref $aref eq 'ARRAY';
    push @$aref, @_;
}

mypush (1, 2), 2;
exit;

sub foo(&$$) { 1 }

sub bar($$&) { 1 }

foo { 3 } 1, 2;
bar 1, 2, sub { 3 };

__END__
# use Benchmark qw/cmpthese/;
# use constant INT_TYPE1 => 0;
# use constant STR_TYPE1 => 1;
# use constant INT_TYPE2 => 'i';
# use constant STR_TYPE2 => 's';

# cmpthese 1e8, {
# 	int => 'INT_TYPE1 == STR_TYPE1; INT_TYPE1 == INT_TYPE1',
# 	str => 'INT_TYPE2 eq STR_TYPE2; INT_TYPE2 eq INT_TYPE2'
# }
# # cmpthese 1e7, {
# #   ary => sub{ $x=[1, 2]; $x->[0]; $x->[1]; },
# #   hsh => sub{ $x={kind=>0, data=>1}; $x->{kind}; $x->{data}; },
# #   bls => sub{ $q=2; $y = bless \$q; ${$y}; }
# # }

# __END__
#!/usr/bin/env perl
use warnings;
use strict;
no warnings 'recursion';
use Carp qw/cluck/;

use constant INT_TYPE => 0;
use constant STR_TYPE => 1;
use constant LIST_TYPE => 2;
use constant BOOL_TYPE => 3;
use constant NULL_TYPE => 4;
use constant VAR_TYPE => 5;
use constant AST_TYPE => 6;

our $NULL =  {kind => NULL_TYPE};
our $TRUE =  {kind => BOOL_TYPE, data => 1};
our $FALSE = {kind => BOOL_TYPE, data => 0};
our %VARS;

sub newint($) { {kind => INT_TYPE, data => int(shift) } }
sub newstr($) { {kind => STR_TYPE, data => shift } }
sub newlist { {kind => LIST_TYPE, data => [@_] } }
sub newbool { shift ? $TRUE : $FALSE }

sub to_int($) {
	my $value = shift;
	my $data = $value->{data};
	my $kind = $value->{kind};

	int($kind == LIST_TYPE ? @$data : $data)
}

sub to_str($) {
	my $value = shift;
	my $data = $value->{data};
	my $kind = $value->{kind};

	return $data if $kind <= STR_TYPE;
	return join "\n", @$data if $kind == LIST_TYPE;
	return '' if $value == $NULL;
	$value == $TRUE ? 'true' : 'false'
}

sub to_bool($) {
	my $value = shift;
	my $data = $value->{data};
	my $kind = $value->{kind};

	return $data eq '' if $kind == STR_TYPE;
	return scalar @$data if $kind == LIST_TYPE;
	$data
}

$\="\n";

__END__
sub newvar  { $VARS{$_[0]} ||= {kind => 'var', name => $_[0], data => 0} }
sub newnum  { {kind => 'num',  data => int(shift)} }
sub newstr  { unless(defined $_[0]){
	cluck;;
	exit 1
	}; {kind => 'str',  data => shift} }
sub newbool { $_[0] ? $TRUE : $FALSE }

# my $bool = "Bool"; eval "package $bool; "
# my $class = "Anon"; eval "package $class; sub hi {}"; my $obj = bless {}, $class; something like this

sub run {
	my $val = shift;

	if ($val->{kind} eq 'var') {
		$val->{data} or die "uninitialized variale '$val->{name}'"
	} elsif ($val->{kind} eq 'func') {
		$val->{func}->(@{$val->{args}})
	} else {
		$val
	}
}

sub tonum {
	my $val = shift;

	if ($val->{kind} eq 'var' || $val->{kind} eq 'func') {
		tonum(run $val)
	} else {
		int $val->{data}
	}
}

sub tostr {
	my $val = shift;

	return $val->{data} if $val->{kind} eq 'str' || $val->{kind} eq 'num';
	return 'null' if $val == $NULL;
	return 'true' if $val == $TRUE;
	return 'false' if $val == $FALSE;
	tostr(run $val)
}

sub tobool {
	my $val = shift;

	if ($val->{kind} eq 'var' || $val->{kind} eq 'func') {
		tobool(run $val)
	} elsif ($val->{kind} eq 'str') {
		$val->{data} ne '' # so we dont get `0` is falsey
	} else {
		$val->{data}
	}
}

sub dumpval {
	my $val = shift;

	if ($val->{kind} eq 'str') {
		print $val->{data}
	} elsif ($val->{kind} eq 'num') {
		print $val->{data};
	} elsif ($val eq $NULL) {
		print 'null';
	} elsif  {
		print $val == $TRUE ? 'true' : 'false';
	}
}

sub parse;

my %functions = (
	 P  => [0, sub { newstr scalar <>; }],
	 R  => [0, sub { newnum int rand 0xffff_ffff }],

	 E  => [1, sub { run parse tostr shift }],
	 B  => [1, sub { shift }],
	 C  => [1, sub { run run shift }],
	'`' => [1, sub { my $str = tostr shift; newstr scalar `$str` }],
	 Q  => [1, sub { exit tonum shift }],
	'!' => [1, sub { newbool !tobool shift }],
	 L  => [1, sub { newnum length tostr shift }],
	 D  => [1, sub { my $val = run shift; dumpval $val; print "\n"; $val }],
	 O  => [1, sub {
	 	my $str = tostr shift;
	 	print(substr($str, -1) eq '\\' ? substr($str, 0, -1) : "$str\n");
	 	$NULL
	 }],

	'+' => [2, sub {
		my $lhs = run shift;

		if ($lhs->{kind} eq 'str') {
			newstr $lhs->{data} . tostr(shift);
		} else {
			newnum tonum($lhs) + tonum(shift);
		}
	}],
	'-' => [2, sub { newnum tonum(shift) - tonum(shift) }],
	'*' => [2, sub {
		my $lhs = run shift;
		if ($lhs->{kind} eq 'str') {
			newstr $lhs->{data} x tonum(shift);
		} else {
			newnum tonum($lhs) * tonum(shift);
		}
	}],
	'/' => [2, sub { newnum tonum(shift) / tonum(shift) }],
	'%' => [2, sub { newnum tonum(shift) % tonum(shift) }],
	'^' => [2, sub { newnum tonum(shift) ** tonum(shift) }],
	'<' => [2, sub {
		my $lhs = run shift;

		if ($lhs->{kind} eq 'str') {
			newbool $lhs->{data} lt tostr(shift);
		} elsif ($lhs->{kind} eq 'num') {
			newbool $lhs->{data} < tonum(shift);
		} else {
			newbool tobool(shift) && $lhs == $FALSE;
		}
	}],
	'>' => [2, sub {
		my $lhs = run shift;

		if ($lhs->{kind} eq 'str') {
			newbool $lhs->{data} gt tostr(shift);
		} elsif ($lhs->{kind} eq 'num') {
			newbool $lhs->{data} > tonum(shift);
		} else {
			newbool !tobool(shift) && $lhs == $TRUE;
		}
	}],
	'?' => [2, sub {
		my $lhs = run shift;
		my $rhs = run shift;

		return $FALSE if $lhs->{kind} ne $rhs->{kind};

		if ($lhs->{kind} eq 'str') {
			newbool $lhs->{data} eq $rhs->{data};
		} elsif ($lhs->{kind} eq 'num') {
			newbool $lhs->{data} == $rhs->{data};
		} else {
			newbool $lhs == $rhs;
		}
	}],
	'&' => [2, sub { my $lhs = run shift; tobool($lhs) ? run(shift) : $lhs }],
	'|' => [2, sub { my $lhs = run shift; tobool($lhs) ? $lhs : run(shift) }],
	';' => [2, sub { run shift; run shift }],
	'=' => [2, sub { $_[0]->{data} = run $_[1] }],
	'W' => [2, sub { run $_[1] while tobool $_[0]; $NULL }],

	'I' => [3, sub { run $_[!tobool shift] }],
	'G' => [3, sub { newstr substr tostr(shift), tonum(shift), tonum(shift) }],
	'S' => [4, sub {
		my $str = tostr shift;
		my $idx = tonum shift;
		my $len = tonum shift;
		my $repl = tostr shift;

		newstr substr($str, 0, $idx) . $repl . substr($str, $idx + $len);
	}]
);
sub parse {
	$_ = shift;
	s/^(?:[\s{}()\[\]:]|#\N*)+//;

	s/^\d+// and return newnum $&;
	s/^(["'])(.*?)\1//s and return newstr $2;
	s/^[a-z_][a-z0-9_]*// and return newvar $&;
	s/^([TF])[A-Z_]*// and return newbool($1 eq 'T');
	s/^N[A-Z_]*// and return $NULL;

	s/^([A-Z]+|.)// or return;
	my $name = substr $1, 0, 1;
	my ($arity, $func) = @{$functions{$name} or die "unknown token start '$name'"};
	my @args;

	for (my $i = 0; $i < $arity; $i++) {
		my $arg = parse($_) or die "missing argument $i for function '$name'";

		push @args, $arg;
	}

	{ kind => 'func', func => $func, args => \@args }
}

my $flag = shift;

die "usage: $0 (-e 'expr' | -f file)" unless !$#ARGV && ($flag eq '-e' || $flag eq '-f');

my $expr = parse($flag eq '-e' ? shift : join '', <>) or die 'nothing to parse?';
run $expr;

# run parse <<EOS
# ; = fib BLOCK
# 	; = a 0
# 	; = b 1
# 	; WHILE n
# 		; = b + a = tmp b
# 		; = a tmp
# 		: = n - n 1
# 	: a
# ; = n 10
# : OUTPUT +++ 'fib(' n ')=' CALL fib
# EOS
