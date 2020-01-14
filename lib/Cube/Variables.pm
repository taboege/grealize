use Modern::Perl;
use bignum;

package Cube::Variables;

# Construct a Cube::Variables object, given the dimension of the cube.
sub new {
    my $self = bless { }, shift;
    my $n = $self->{dim} = shift;
    die "dimension must be >= 3" unless $n >= 3;

    $self->{vars} = _compute_vars($n);

    # We use 1..$n to print variables. This only works well in our
    # formatting if each symbol occupies one digit. This is not a
    # limitation most of the time because of combinatorial explosion.
    die "dimension is too high to use 1..9" unless $n <= 9;

    # Build caches for all methods on this object right now.
    #
    # The autoritative numbering of variables requires the
    # following pattern:
    #   (12|), (12|3), (12|4), (12|5),
    #   (12|34), (12|35), (12|45),
    #   (12|345),
    #   (13|), (13|2), ...
    # which is a bit hard to get with the binary counter
    # implementation of subsets in Algorithm::Combinatorics.
    #
    # DANGER: If the implementation of subsets is changed,
    # this will suddenly produce wrong axioms!
    use Algorithm::Combinatorics qw(subsets);

    $self->{faces}   = \my @faces;
    $self->{names}   = \my @names;
    $self->{numbers} = \my %numbers;

    $faces[0] = $names[0] = "(NaV)";
    my $v = 1;
    for my $i (1 .. $n) {
        for my $j (($i+1) .. $n) {
            my @M = grep { $_ != $i and $_ != $j } 1 .. $n;
            for my $k (0 .. @M) {
                for my $L (subsets([@M], $k)) {
                    my $face = [$i,$j,sort @$L];
                    my $name = _name($face);
                    $faces[$v] = $face;
                    $names[$v] = $name;
                    $numbers{$name} = $v;
                    $v++;
                }
            }
        }
    }

    $self
}

# Solve $vars == ($n choose 2) * 2 ** ($n - 2).
sub _compute_dimension {
    my $vars = shift;
    my $n = 2;

    while (1) {
        my $nvars = _compute_vars($n);
        return $n if $nvars == $vars;
        last if $nvars > $vars;
        $n++;
    }
    die "don't know dimension of $vars variables";
}

sub _compute_vars {
    my $n = shift;
    $n * ($n - 1) * 2 ** ($n - 3)
}

sub _name {
    my ($i, $j, @K) = @{+shift};
    "$i$j|" . join('', sort @K)
}

# Return all variable objects in the correct order.
# If an arrayref [$i, $j] is given, only objects with
# those initial elements are returned.
sub list {
    my $self = shift;
    my $ij = shift;
    my @list = @{$self->{faces}}[1 .. $self->{vars}];
    !defined($ij) ? @list : grep {
        $_->[0] == $ij->[0] && $_->[1] == $ij->[1]
    } @list
}

sub dual {
    use Array::Set qw(set_diff);

    my $self = shift;
    my $ijK = shift;
    my $Z = set_diff([1 .. $self->{dim}], $ijK);
    [$ijK->[0], $ijK->[1], sort @$Z]
}

# Convert between a 1-based variable number and flattened arrayref [i,j,K]
# and stringified name, according to the Authoritative Ordering.

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
