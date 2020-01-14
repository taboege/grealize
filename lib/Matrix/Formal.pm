package Matrix::Formal;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(symmetric_matrix minor pr apr);

use Modern::Perl;

use Math::Symbolic qw(:all);
use Math::Symbolic::MiscAlgebra qw(:all);
use Math::Polynomial::Multivariate;

# Make a generic symmetric nxn matrix with 1's on the diagonal.
sub symmetric_matrix {
    my $n = shift;
    my @A; my $cur = 'a';

    for my $i (1 .. $n) {
        for my $j ($i .. $n) {
            $A[$i-1]->[$j-1] = $A[$j-1]->[$i-1] =
                $i == $j ? '1' : $cur++;
        }
    }
    \@A
}

# We know that our minors are really polynomials in the entries of
# the matrix. Math::Symbolic might not construct them as a list of
# monomials with coefficients, so we have to do this here. E.g. we
# might have (x + y)^2, which is supposed to be x^2 + 2*x*y + y^2.
sub to_polynomial {
    # Not implementing multiplying out myself... Instead we convert
    # a Math::Symbolic that surely represents a polynomial recursively
    # into a Math::Polynomial::Multivariate. That one stringifies
    # to a neat list of monomials with coefficients, hence does the
    # multiplying out.
    use experimental qw(switch);
    my $poly = shift;
    for (ref($poly)) {
        when ('Math::Symbolic::Constant') {
            return Math::Polynomial::Multivariate->const($poly->value);
        }
        when ('Math::Symbolic::Variable') {
            return Math::Polynomial::Multivariate->var($poly->name);
        }
        when ('Math::Symbolic::Operator') {
            for ($poly->type) {
                when (B_SUM) {
                    return to_polynomial($poly->op1)
                         + to_polynomial($poly->op2)
                }
                when (B_DIFFERENCE) {
                    return to_polynomial($poly->op1)
                         - to_polynomial($poly->op2)
                }
                when (B_PRODUCT) {
                    return to_polynomial($poly->op1)
                         * to_polynomial($poly->op2)
                }
                when (B_DIVISION) {
                    return to_polynomial($poly->op1)
                         / to_polynomial($poly->op2)
                }
                when (U_MINUS) {
                    return - to_polynomial($poly->op1)
                }
                when (B_EXP) {
                    return to_polynomial($poly->op1)
                        ** $poly->op2->value
                }
                default {
                    die "don't know how to convert @{[ $poly->type ]} node";
                }
            }
        }
        default {
            die "don't know how to convert @{[ ref($poly) ]} node";
        }
    }
}


sub minor {
    my ($A, $rows, $cols) = @_;
    my @B;
    for my $i (@$rows) {
        my @row;
        for my $j (@$cols) {
            push @row, $A->[$i-1]->[$j-1];
        }
        push @B, \@row;
    }
    # XXX: det does not work if @B is empty. The determinant of
    # an empty submatrix is 1.
    # XXX: Do NOT use ->simplify(1) on the result of det. On the determinant
    # of a symmetric_matrix(3), this swallowed the constant term in my tests!
    to_polynomial (0+ @B ? det @B : parse_from_string('1'))
}

sub pr {
    my ($A, $I) = @_;
    minor $A, $I, $I
}

sub apr {
    my ($A, $ijK) = @_;
    my ($i, $j, @K) = @$ijK;
    minor $A, [$i, @K], [$j, @K]
}

1;
