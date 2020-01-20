#!/bin/bash

ofile=${@:$#:1}
if [[ ! -f "$ofile" ]]
  then echo "Orientations file '$ofile' does not exist" >&2
  exit 1
fi

dag=${@:1:$(($#-1))}
vars=$(perl -E 'say join ", ", map { "a$_" } @ARGV' $dag)

./dag-oriented.pl $dag "$ofile" |
while read args
  do echo '(*' $args '*)'
  echo $args | xargs -L1 \
    ./grealize -t sem -- |
    sed 's/$/;/'
  echo 'FindInstance[S, {' "$vars" '}, Reals]'
  echo
done
