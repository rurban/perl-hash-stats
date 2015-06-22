#!/usr/bin/perl
# apply cost model to cachegrind results

# Usage:
# valgrind --tool=cachegrind ./miniperl -e'my %h = ("foo" => 1); $h{foo} for 0..100' \
#    2>&1 > log.hash
# perl cachegrind-cost.pl log.hash |sort -nk2 -t$'\t'

my $cost = 0;
LINE: while (<>) {
  unless (/^==\d+==/) {
    if ($cost) {
      print "\t$cost\n";
    }
    chomp;
    print;
    $cost = 0;
    next LINE;
  }
  s/^==\d+== //;
  my ($a,$b,$n) = split ' ';
  $n =~ s/,//g;

  if (/I\s+refs:/) {
    $cost += $n;
  } elsif (/[DI]1\s+misses:/) {
    $cost += $n + 10;
  } elsif (/(LIi|LLd)\s+misses:/) {
    $cost += $n + 200;
  }
}

if ($cost) {
  print "\t$cost\n";
}
