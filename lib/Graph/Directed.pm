use Modern::Perl;

package Graph::Directed;

# Add a clone method
use parent 'Clone';

# Takes an array of character pairs "12", "21", "1a", etc. which represent
# directed edges 1 -> 2, 2 -> 1, 1 -> a. Each vertex is represented by one
# character for easy CLI typing. Isolated vertices can just be named, like
# "1" or "3", so they don't form an edge.
#
# Returns a digraph which is a hash that associates to each vertex a pair
# of hashes, for the incoming and the outgoing edges. Each hash stores a
# truthy value for the other vertex of that edge. Non-adjacent vertices
# are not set at all. This is wasteful but convenient.
sub new {
    my $self = bless {}, shift;
    for (@_) {
        my ($i, $j) = split //;
        # Isolated vertices are ok, just add them to the list of vertices.
        if ($j eq "") {
            $self->{$i} //= { out => {}, in => {} };
            next;
        }
        $self->{$i}->{out}->{$j} = 1;
        $self->{$j}->{in}->{$i}  = 1;
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
        for my $j (keys %{$self->{$i}->{out}}) {
            delete $self->{$j}->{in}->{$i};
        }
        for my $j (keys %{$self->{$i}->{in}}) {
            delete $self->{$j}->{out}->{$i};
        }
        delete $self->{$i};
    }
    $self
}

# Get all sources of the digraph.
sub sources {
    my $self = shift;
    grep { not %{$self->{$_}->{in}} } keys %$self;
}

# Get all sinks of the digraph.
sub sinks {
    my $self = shift;
    grep { not %{$self->{$_}->{out}} } keys %$self;
}

# Return whether a digraph is acyclic, for short a DAG.
sub acyclic {
    # Make a clone. The algorithm modifies the graph.
    my $clone = shift->clone;
    # Perform topological sort.
    my @q = $clone->sources;
    while (@q) {
        my $i = shift @q;
        $clone->drop($i);
        @q = $clone->sources;
        # TODO: $self->some_source would be less wasteful.
        # For true O(V+E) one would need to inline ->drop
        # and do the new sources computation in there.
    }

    not %$clone
}

# Return the transpose digraph, i.e. the one with all arrows flipped.
sub transpose {
    my $clone = shift->clone;
    for my $i (keys %$clone) {
        ($clone->{$i}->{in}, $clone->{$i}->{out}) =
            ($clone->{$i}->{out}, $clone->{$i}->{in});
    }
    $clone
}

# To a DAG and a triple ($i, $j, @K), return the (undirected) moral
# version of the ancestral graph wrt $i, $j and @K.
sub moralize {
    my $self = shift;
    my @edges; # undirected edges to return

    # First determine the ancestral graph.
    my %seen = map { $_ => 1 } (my @q = @_);
    while (@q) {
        my $i = shift @q;
        for my $j (keys %{$self->{$i}->{in}}) {
            push @edges, "$i$j";
            push @q, $j unless $seen{$j}++;
        }
    }

    # Moralization is marrying parents.
    for my $k (keys %seen) {
        for my $i (keys %{$self->{$k}->{in}}) {
            next unless $seen{$i};
            for my $j (keys %{$self->{$k}->{in}}) {
                next unless $seen{$j};
                next if $i eq $j;
                push @edges, "$i$j";
            }
        }
        # Preserve all vertices, even the isolated ones.
        push @edges, $k;
    }

    # Make an undirected graph.
    use Graph::Undirected;
    Graph::Undirected->new(@edges)
}

sub dump {
    my $self = shift;
    my @edges;
    for my $i (sort keys %$self) {
        for my $j (sort keys %{$self->{$i}->{out}}) {
            push @edges, "$i$j";
        }
    }
   "[" . join(' ', @edges) . "]";
}

# In a DAG, given ($i, $j, @K) as arguments, determine whether $i and $j
# are d-separated by @K. The implementation uses moralization.
#
# It might be worthwhile to check out https://arxiv.org/pdf/1304.1505.pdf
# when we want to compute the entire CI structure at once.
sub ci {
    my $self = shift;
    my ($i, $j, @K) = @_;
    my $mor = $self->moralize($i, $j, @K);
    $mor->ci($i, $j, @K)
}

":wq"
