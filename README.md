# Knight: Perl Edition
A Perl implementation of Knight 2.0.1

See [the main page](https://github.com/knight-lang/knight-lang) for more details.

## TODO: ./knight -e 'D ; = v 123 +@ B v'

# Running
This requires a minimum of Perl v5.34. It might work on versions below v5.34, but I haven't tested them. You can execute it via `./knight -e 'OUTPUT "Hello, world"'`

## Older Version
I've also made a perlmodule version in `lib` and `bin`

I originally thought it'd be fun to have some fancy overloading nonsense for everything, but since that breaks the spirit of some of the operators (eg `<` is intended for numerical comparisons, `.` is for string concatenation, etc), I decided to opt for simply overloading the conversion operators: `""`, `0+`, and `bool`.

