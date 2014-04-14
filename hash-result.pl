#!/usr/bin/perl -an
# test -DH hash collisions

# Usage:
#   apply -DH patch at https://github.com/rurban/perl/commit/b975d736cfe40a9cf51ec0a44aaba0322fd04347
#   define PERL_HASH_FUNC_ONE_AT_A_TIME in config.h
# make test 2> log.hash.ONE_AT_A_TIME
#   kill perl hanging at cpan/Test-Simple/t/utf8.t and ext/PerlIO-encoding/t/nolooping.t
# ./hash-result.pl log.hash.ONE_AT_A_TIME | tee hash.result.ONE_AT_A_TIME

# skip non-conformant lines
# STDERR might get garbled by tests and we dont try to fix around this
# we will not print to a special filehandle just for -DH

next unless ($F[0] =~ /^\d+$/
             and $F[1] =~ /^\d+$/
             and $F[2] =~ /^\d+$/
             and (@F == 3 or (@F == 4 and $F[3] !~ /^\d+$/)));

$F{0}{$F[0]}++;
$F{1}{$F[1]}++;
$F{2}{$F[2]}++;
$F{3}{$F[3]}++ if $F[3];
$n++;

END{
  my %i = (
    0 => 'keys',
    1 => 'size',
    2 => 'coll',
    3 => 'op',
    );
  my ($median_cnt, $n_2, $median) = (0, $n >> 1, 0);
  for $i (0..3) {
    print "$i $i{$i}:\n";
    for $k (sort {$a<=>$b} keys $F{$i}) {
      print "\t",$k,"\t",$F{$i}{$k},"x\n";
      if ($i == 0) {
        if ($median_cnt < $n_2) {
          $median_cnt += $F{0}{$k};
        } elsif (!$median) {
          $median = $k;
        }
      }
    }
    print "\n";
  }
  my $cost = 0;
  for my $k (sort {$a<=>$b} keys $F{2}) {
    $cost += $F{2}{$k} * $k;
  }
  print "collision cost: $cost / # lines: $n\n";
  print sprintf("ratio: %0.03f\n", $cost / $n);

  my $keys = 0;
  $keys += $_ * $F{0}{$_} for keys $F{0};
  print sprintf("key size: avg = %0.03f, median = %d\n", $keys / $n, $median);
}
