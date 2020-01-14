use Modern::Perl;
use bignum;

package Cube::Faces;

use Algorithm::Combinatorics qw(subsets);
use Array::Set qw(set_diff);
use ntheory qw(binomial);

# Construct a Cube::Faces object, given cube and minor dimensions.
# We obtain Cube::Variables from this by choosing k=2.
sub new {
    my $self = bless { }, shift;
    my $n = $self->{dim} = shift;
    my $k = $self->{sub} = shift;
    die "dimension must be >= 3" unless $n >= 3;
    die "minor dimension must be >= 3" unless $k >= 3;
    die "minor dimension too large" unless $k <= $n;

    $self->{vars} = _compute_vars($n, $k);

    # We use 1..$n to print variables. This only works well in our
    # formatting if each symbol occupies one digit. This is not a
    # limitation most of the time because of combinatorial explosion.
    die "dimension is too high to use 1..9" unless $n <= 9;

    # Build caches for all methods on this object right now.
    $self->{faces}   = \my @faces;
    $self->{names}   = \my @names;
    $self->{numbers} = \my %numbers;

    $faces[0] = $names[0] = "(NaV)";
    my $v = 1;
    my $N = [1 .. $n];
    for my $I (subsets $N, $k) {
        my $M = set_diff($N, $I);
        for my $l (0 .. @$M) {
            for my $L (subsets($M, $l)) {
                my $face = [[sort @$I], [sort @$L]];
                my $name = _name($face);
                $faces[$v] = $face;
                $names[$v] = $name;
                $numbers{$name} = $v;
                $v++;
            }
        }
    }

    $self
}

sub _compute_vars {
    my ($n, $k) = @_;
    binomial($n, $k) * 2 ** ($n - $k)
}

sub _name {
    my ($I, $L) = @{+shift};
    join('', sort @$I) . "|" . join('', sort @$L)
}

sub list {
    my $self = shift;
    @{$self->{faces}}[1 .. $self->{vars}]
}

# Convert between a 1-based variable number and arrayref [$I, $L]
# and stringified name.

sub unpack {
    my $self = shift;
    my $v = shift;
    $self->{faces}->[$v] // die "lookup failed on $v";
}

sub pack {
    my $self = shift;
    my $name = _name(shift);
    $self->{numbers}->{$name} // die "lookup failed on $name";
}

sub name {
    my $self = shift;
    my $v = shift;
    $self->{names}->[$v] // die "lookup failed on $v";
}

":wq"
