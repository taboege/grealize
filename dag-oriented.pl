#!/usr/bin/env perl

# Take a DAG and a listing of oriented gaussoids as input.
# Generate the gaussoid corresponding to the DAG, find all
# its orientations from the supplied file and then output
#
#   DAG ORIENTATION
#
# for each orientation. This can be fed through xargs into
# `grealize -t sem --`.

use Modern::Perl;

use Cube::Variables;
use Graph::Directed;

my $orient_file = pop @ARGV;
my $graph = Graph::Directed->new(@ARGV);

sub gaussoid {
    my $D = shift;
    my $vars = Cube::Variables->new(0+ $D->vertices);
    join '', map { $D->ci(@$_) ? "0" : "1" } $vars->list
}

sub orientations {
    my $G = shift;
    my $Gre = $G =~ s/1/[+-]/gr;
    $Gre = qr/$Gre/;
    open my $fh, '<', $orient_file;
    grep { m/$Gre/ } map { chomp and $_ } <$fh>
}

my $G = gaussoid $graph;
for my $O (orientations $G) {
    say join(' ', @ARGV), ' ', $O;
}
