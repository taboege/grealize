use Modern::Perl;

package Graph::Undirected;

# Add a clone method
use parent 'Clone';

# Takes an array of character pairs "12", "21", "1a", etc. which represent
# edges 1 - 2, 2 - 1, 1 - a. Edges are undirected, i.e. "12" and "21" are
# the same. Each vertex is represented by one character for easy CLI typing.
# Isolated vertices can just be named, like "1" or "3", so they don't form
# an edge.
#
# Returns an undirected graph which is a hash that associates to each vertex
# a hash representation of its adjacency list: each adjacent vertex as a key
# will have a truthy value. Non-adjacent vertices will not be set at all.
sub new {
    my $self = bless {}, shift;
    for (@_) {
        my ($i, $j) = split //;
        # Isolated vertices are ok, just add them to the list of vertices.
        if ($j eq "") {
            $self->{$i} = {};
            next;
        }
        $self->{$i}->{$j} = 1;
        $self->{$j}->{$i} = 1;
    }
    $self
}

# Return an array of all vertices
sub vertices {
    keys %{+shift}
}

# Remove the given vertices and all incident edges.
sub drop {
    my $self = shift;
    for my $i (@_) {
        for my $j (keys %{$self->{$i}}) {
            delete $self->{$j}->{$i};
        }
        delete $self->{$i};
    }
    $self
}

# Given any number of vertices, returns whether they are all in the same
# connected component, i.e. mutually reachable in the graph.
sub reachable {
    my $self = shift->clone;
    my %search = map { $_ => 1 } @_;

    # Explore the connected component of some vertex using Breadth first
    # search, then cross out what was found in %search.
    my @q = my ($i) = keys %search;
    my %seen = ($i => 1);
    while (@q) {
        my $i = shift @q;
        for my $j (keys %{$self->{$i}}) {
            push @q, $j unless $seen{$j}++;
        }
    }

    delete @search{keys %seen};
    not %search
}

sub dump {
    my $self = shift;
    my @edges;
    for my $i (sort keys %$self) {
        for my $j (sort keys %{$self->{$i}}) {
            next unless $i <= $j;
            push @edges, "$i$j";
        }
    }
   "[" . join(' ', @edges) . "]";
}

# Given ($i, $j, @K) as arguments, determine whether $i and $j are
# separated by @K, i.e. whether every path between $i and $j hits
# some vertex in @K.
#
# See Digraph->ci for a paper where d-separation is done quicker.
# There should be a way to improve the running time when the entire
# CI structure is to be computed.
sub ci {
    my $clone = shift->clone;
    my ($i, $j, @K) = @_;
    not $clone->drop(@K)->reachable($i, $j)
}

":wq"
