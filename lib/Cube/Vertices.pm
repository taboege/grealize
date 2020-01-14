use Modern::Perl;
use bignum;

package Cube::Vertices;

# Construct a Cube::Vertices object, given the dimension of the cube.
sub new {
    my $self = bless { }, shift;
    my $n = $self->{dim} = shift;
    die "dimension must be >= 3" unless $n >= 3;

    $self->{vars} = 2 ** $n;

    # We use 1..$n to print variables. This only works well in our
    # formatting if each symbol occupies one digit. This is not a
    # limitation most of the time because of combinatorial explosion.
    die "dimension is too high to use 1..9" unless $n <= 9;

    # The autoritative numbering of variables requires the
    # following pattern:
    #   o,
    #   1, 2, 3, ...
    #   12, 13, ...
    #   123, ...
    # which is a bit hard to get with the binary counter
    # implementation of subsets in Algorithm::Combinatorics.
    #
    # DANGER: The current implementation assumes $n < 10 when
    # converting vertices to strings. That's good enough for
    # everything that can be computed in practice.
    use Algorithm::Combinatorics qw(subsets);

    $self->{vertices} = \my @vertices;
    $self->{names}    = \my @names;
    $self->{numbers}  = \my %numbers;

    $vertices[0] = $names[0] = "NaV";
    my $v = 1;
    for my $k (0 .. $n) {
        for my $I (subsets([1 .. $n], $k)) {
            my $vertex = [sort @$I]; # just to be sure
            my $name = _name($vertex);
            $vertices[$v] = $vertex;
            $names[$v] = $name;
            $numbers{$name} = $v;
            $v++;
        }
    }

    $self
}

sub _name {
    join '', sort @{+shift}
}

sub list {
    my $self = shift;
    my $I = shift;
    @{$self->{vertices}}[1 .. $self->{vars}];
}

# Convert between a 1-based variable number and arrayref $I and
# stringified name, according to the Authoritative Ordering.

sub unpack {
    my $self = shift;
    my $v = shift;
    $self->{vertices}->[$v] // die "lookup failed on $v";
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
