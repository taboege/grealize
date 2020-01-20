use Modern::Perl;

# XXX: This only implements square matrices with polynomial entries.
# Squareness is an implicit assumption, as is that you only operate
# on matrices (sum, difference, product) when they have the same size.
package Matrix::Formal;

# Add a clone method
use parent 'Clone';

use overload (
    q[=]  => sub { shift->clone },
    q[+]  => \&add,
    q[-]  => \&sub,
    q[*]  => \&mul,
    q[""] => \&str,
);

use Math::Symbolic::MiscAlgebra;
use Math::Polynomial::Multivariate;

sub zero {
    my ($class, $n) = @_;

    my @A;
    for my $i (0 .. $n-1) {
        for my $j (0 .. $n-1) {
            $A[$i]->[$j] = Math::Polynomial::Multivariate->const(0);
        }
    }
    bless \@A, $class
}

sub identity {
    my ($class, $n) = @_;

    my $A = zero($class, $n);
    for my $i (0 .. $n-1) {
        $A->[$i]->[$i] = Math::Polynomial::Multivariate->const(1);
    }
    $A
}

# Make a generic symmetric nxn matrix with constant $diag on the
# diagonal, which is 1 by default.
sub generic_symmetric {
    my ($class, $n, $diag, $cur) = @_;
    $diag //= 1;
    $cur //= 'a';

    my @A;
    for my $i (0 .. $n-1) {
        for my $j ($i .. $n-1) {
            $A[$i]->[$j] = $A[$j]->[$i] = $i == $j ?
                    Math::Polynomial::Multivariate->const($diag) :
                    Math::Polynomial::Multivariate->var($cur++);
        }
    }
    bless \@A, $class
}

# Generic strictly upper triangular matrix. You can pass $diag to give
# it a constant diagonal.
sub generic_triangular {
    my ($class, $n, $diag, $cur) = @_;
    $diag //= 0;
    $cur //= 'a';

    my $A = zero($class, $n);
    for my $i (0 .. $n-1) {
        $A->[$i]->[$i] = Math::Polynomial::Multivariate->const($diag);
        for my $j ($i+1 .. $n-1) {
            $A->[$i]->[$j] = Math::Polynomial::Multivariate->var($cur++);
        }
    }
    $A
}

# Make a Lambda matrix for a structural equation model corresponding
# to the given DAG. The Lambda matrix is a strictly upper-triangular
# matrix with zeros on exactly those entries (i,j) that are non-edges
# in the underlying digraph. The corresponds to the (ij|N \ ij)-entry
# in the gaussoid being zero.
sub generic_sem {
    ...
}

sub view {
    use Scalar::Util qw(blessed);

    my ($A, $rows, $cols) = @_;
    my @B;
    for my $i (@$rows) {
        my @row;
        for my $j (@$cols) {
            push @row, $A->[$i-1]->[$j-1];
        }
        push @B, \@row;
    }
    bless \@B, blessed($A)
}

sub transpose {
    my $A = shift;
    my $B = $A->clone;
    my $n = 0+ @$A;
    for my $i (0 .. $n-1) {
        for my $j ($i+1 .. $n-1) {
            ($B->[$i]->[$j], $B->[$j]->[$i]) =
                ($B->[$j]->[$i], $B->[$i]->[$j]);
        }
    }
    $B
}

sub cofactor {
    my ($A, $i, $j) = @_;
    my $n = 0+ @$A;
    my $I = [grep { $_ != $i } 1 .. $n];
    my $J = [grep { $_ != $j } 1 .. $n];
    my $s = ($i + $j) % 2 ? -1 : 1;
    $s * $A->view($I, $J)->det
}

sub adj {
    my $A = shift;
    my $n = 0+ @$A;
    my @B;
    for my $i (1 .. $n) {
        my @row;
        for my $j (1 .. $n) {
            # (i,j) entry is (j,i)-cofactor!
            push @row, $A->cofactor($j, $i);
        }
        push @B, \@row;
    }
    bless \@B, blessed($A)
}

sub tr {
    my $A = shift;
    my $n = 0+ @$A;
    my $tr = 0;
    for my $i (0 .. $n-1) {
        $tr += $A->[$i]->[$i];
    }
    return $tr;
}

sub det {
    use Sub::Override;

    my $A = shift;
    # XXX: det does not work if @$A is empty. The determinant of an empty
    # submatrix is 1 by convention.
    return Math::Polynomial::Multivariate->const(1) unless @$A;

    # Some explanations are in order. We use Math::Symbolic::MiscAlgebra::det
    # to compute the determinant of a matrix. This is fairly general in that
    # it can theoretically use anything that has enough operators overloaded.
    # Still, it tries to turn everything into Math::Symbolic, which we inhibit
    # with the first override.
    my $ov = Sub::Override->new;
    $ov->replace("Math::Symbolic::parse_from_string" =>
        sub { shift }
    );
    # The second override fixes an issue with M::P::M::_add, the overload
    # for addition of multivariate polynomials. The det algorithm starts out
    # with an undef determinant variable which is passed to _add as an
    # operand. This produces a warning when _add uses that value to make
    # a new constant (which is the right thing). We silence that by making
    # it a real, defined 0 transparently.
    my $const = \&Math::Polynomial::Multivariate::const;
    $ov->replace("Math::Polynomial::Multivariate::const" =>
        sub { $const->($_[0], $_[1] // 0) }
    );

    Math::Symbolic::MiscAlgebra::det(@$A)
}

sub minor {
    my ($A, $rows, $cols) = @_;
    $A->view($rows, $cols)->det
}

sub pr {
    my ($A, $I) = @_;
    $A->minor($I, $I)
}

sub apr {
    my ($A, $ijK) = @_;
    my ($i, $j, @K) = @$ijK;
    $A->minor([$i, @K], [$j, @K])
}

sub add {
    my ($A, $B, $swap) = @_;

    my $C = $A->clone;
    my $n = 0+ @$C;
    for my $i (0 .. $n-1) {
        for my $j (0 .. $n-1) {
            $C->[$i]->[$j] += $B->[$i]->[$j];
        }
    }
    $C
}

sub sub {
    my ($A, $B, $swap) = @_;

    my $C = $A->clone;
    my $n = 0+ @$C;
    for my $i (0 .. $n-1) {
        for my $j (0 .. $n-1) {
            $C->[$i]->[$j] -= $B->[$i]->[$j];
        }
    }
    $C
}

sub mul {
    my ($A, $B, $swap) = @_;

    my $n = 0+ @$A;
    my $C = __PACKAGE__->zero($n);
    for my $i (0 .. $n-1) {
        for my $j (0 .. $n-1) {
            my $Cij = Math::Polynomial::Multivariate->const(0);
            for my $k (0 .. $n-1) {
                $Cij += $A->[$i]->[$k] * $B->[$k]->[$j];
            }
            $C->[$i]->[$j] = $Cij;
        }
    }
    $C
}

sub inv {
    my $A = shift;
    my $det = $A->det;

    # We could make this more general: any unit, i.e.
    #   $det->degree == 0 && $det->is_not_null
    # would work, but then we would have to coerce M::P::M into accepting
    # big rational coefficients and so on. My primary application always
    # has determinant one. Then the inverse is just the classical adjoint.
    die "Matrix with determinant $det != 1 cannot be inverted"
        unless $det == 1;

    $A->adj
}

sub str {
    use Text::Table;
    my $tt = Text::Table->new;
    $tt->load(@{+shift});
    join "\n", map { chomp and $_ } $tt->table
}

":wq"
