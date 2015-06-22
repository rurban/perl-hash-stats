perl-hash-stats
===============

Counting the collisions with perl hash tables per function.
(linear chaining in a linked list, subject to collision attacks)

Average case (perl core testsuite)
----------------------------------

| Hash Function | collisions|  time[sec] | Quality | cyc/hash |
|:--------------|----------:|-----------:|---------|---------:|
| FNV1A	        | 0.862     |   535 sec  |   BAD   |  33.19  |
| OOAT_OLD      | 0.861     |   537 sec  |   BAD   |  50.83  |
| CRC32	        | 0.841     |   538 sec  | INSECURE|  31.27  |
| SUPERFAST     | 0.848     |   537 sec  |   BAD   |  27.75  |
| SDBM	        | 0.874     |   541 sec  |   BAD   |  29.23  |
| SPOOKY32      | 0.813     |   546 sec  |  GOOD   |  38.45  |
| MURMUR64A     | 0.855     |   546 sec  |   BAD   |  28.80  |
| MURMUR64B     | 0.857     |   546 sec  |   BAD   |  27.48  |
| OOAT_HARD     | 0.842     |   547 sec  |   BAD   |  61.03  |
| MURMUR3       | 0.883     |   547 sec  |  GOOD   |  29.54  |
| DJB2          | 0.898     |   547 sec  |   BAD   |  33.78  |
| METRO64       | 0.892     |   550 sec  |  GOOD   |  26.78  |
| OOAT          | 0.860     |   551 sec  |   BAD   |  ??     |
| SIPHASH       | 0.853     |   551 sec  |  GOOD   |  114.48 |
| METRO64CRC    | 0.872     |   559 sec  |  GOOD   |  23.27  |

Less collisions are better, less time is faster.
A hash table lookup consists of one constant hash function
(depending only on the length of the key) and then resolving
0-x collisions (in our avg case 0-10).

**Speed:** Note that hash table speed measured here is a combination of
code-size, less code - better icache, CPU (cyc/hash) and less
collisions (better quality, less work). But we only measured the
primitive linked list implementation yet, which has to chase linked
list pointers and looses the data cache, unlike with open-addressing.

**FNV1a** is the current leader. Even if it creates more collisions
than a good hash, and is not as fast in bulk as others, it is smaller
and faster when being used inlined in hash table functions. I'm
testing the [sanmayce](http://www.sanmayce.com/Fastest_Hash/) bigger
and unrolled variants now to confirm the theory.

**Spooky32** creates the least collisions by far and is the fastest of
the good hash functions here, but only works on 64 bit
machines. **Murmur3** interestingly creates a lot of collisions, even
more than the OOAT variants.

The individually fastest hash function, which should be used for
checksumming larger files, **METRO**, does not perform good as hash
table function at all. It has too much code and it is not optimized
to avoid collisions with ASCII text keys.

The short perl5 testsuite (op,base,perf) has a key size of median =
33, and avg of 83.  The most commonly used key sizes are 4, 101 and
2, the most common hash tables sizes are 7, 255 and 31.

A hash table size of 7 uses the last 3 bits of the hash function result,
63 uses only 6 bits of 32 and 127 uses 7 bits.

* collisions are the number of linked list iterations per hash table usage.
* quality and cycles/hash is measured with [smhasher](https://github.com/rurban/smhasher)

Hash table sizes
----------------

| size  |     count |
|:-----:|----------:|
|     0 |      2403 |
|     1 |       383 |
|     3 |       434 |
|     7 |  30816359 |
|    15 |  19761019 |
|    31 |  20566188 |
|    63 |  30131283 |
|   127 |  28054277 |
|   255 |  15104276 |
|   511 |   7146648 |
|  1023 |   3701004 |
|  2047 |   1015462 |
|  4095 |    217107 |
|  8191 |    284997 |
| 16383 |    237284 |
| 32767 |    169823 |

Note that perl ony supports int32 (32bit) sized tables, not 64bit arrays.
Larger keysets need to be tied to bigger key-value stores, such as
[LMDB_File](http://search.cpan.org/dist/LMDB_File/) or at least
AnyDBM_File, otherwise you'll get a hell lot of collisions.

It should be studied of leaving out one or two sizes and therefore the costly
rehashing is worthwile. Good candidates for this dataset to skip seem to be
15 and 63.

For double hashing perl5 need to use prime number sized hash tables to 
make the 2nd hash function work. For 32bit the primes can be stored
in a constant table as in glibc.


Number of collisions with CRC32
------------------------------
CRC32 is a good and fast hash function, on SSE4 intel processors or
armv7 and armv8 it costs just a few cycles, but unfortunately too trivial
to create collisions when allowing binary keys, the worst case.


| collisions|     count |
|:---------:|----------:|
|        0  |  26176163 |
|        1  | 100979326 |
|        2  |  25745874 |
|        3  |   4526405 |
|        4  |    512177 |
|        5  |     46749 |
|        6  |      4015 |
|        7  |       187 |
|        8  |         8 |

Note that 0 collisions can occur with an early return in the hash
table lookup function, such as with empty hash tables.
The number of collisions is independent of the hash table size or key length.
It depends on the fill factor, the quality of the hash function and the key.

This is the average case. Worst cases can be produced by guessing the random hash
seed from leakage of sorting order (unsorted keys in JSON, YAML, RSS interfaces, or such),
(_or even fooling with the ENV or process memory_), and then creating colliding keys, which
would lead to exponential time DOS attacks with linear time attack costs. [RT #22371](https://rt.perl.org/Public/Bug/Display.html?id=22371) and ["Denial of Service via Algorithmic Complexity Attacks", S Crosby, D Wallach, Rice 1993](http://www.rootsecure.net/content/downloads/pdf/dos_via_algorithmic_complexity_attack.pdf).
Long running perl processes with publicly exposed sorting order and input acceptance of hash keys
should really be avoided without proper countermeasures. PHP e.g. does MAX\_POST\_SIZE.
How to get the private random seed is e.g. described in ["REMOTE ALGORITHMIC COMPLEXITY ATTACKS AGAINST
RANDOMIZED HASH TABLES", N Bar-Yosef, A Wool - 2009 - Springer](https://www.eng.tau.ac.il/~yash/C2_039_Wool.pdf).

Perl and similar dynamic languages really need to improve their collision algorithm, and choose
a combination of fast and good enough hash function. None of this is currently implemented in
standard SW besides Kyoto DB, though Knuth proposed to use sorted buckets
["Ordered hash tables", O Amble, D Knuth 1973](http://comjnl.oxfordjournals.org/content/17/2/135.full.pdf).
Most technical papers accept degeneration into linear search for bucket collisions as is.
Notably e.g. even the Linux kernel [F. Weimer, “Algorithmic complexity attacks and the
linux networking code”, May 2003](http://www.enyo.de/fw/security/notes/linux-dst-cache-dos.html),
though glibc, gcc and libliberty and others switched to open addressing with double hashing recently,
where collisions just trigger hash table resizes, and the choice of the 2nd function will reduce
collisions dramatically.
DJB's DNS server has an explicit check for "hash flooding" attempts.
Some rare hash tables implementations use rb-trees.

For City there currently exists a simple universal C function to
easily create collisions per seed.  crc32 is exploitable even more
easily.  Note that this exists for every hash function, just encode
your hash SAT solver-friendly and look at the generated model. It is
even incredibly simple if you calculate only the needed last bits
dependent on the hash table size (8-15 bits).  So striking out city
for such security claims does not hold. The most secure hash function
can be attacked this way. Any practical attacker has enough time in
advance to create enough colliding keys dependent only on the random
seed, and can easily verify it by time measurements.  The code is just
not out yet, and the costs for some slower (cryptographically secure)
hash functions might be too high. But people already encoded SHA-2
into SMTLIB code to attack bitcoin, and high-level frameworks such as
frama-c, klee or z3 are becoming increasingly popular.

crc is recommended by [xcore Tip & Tricks: Hash Tables](http://xcore.github.io/doc_tips_and_tricks/hash-tables.html)
and also analysed by [Bob Jenkin](http://burtleburtle.net/bob/hash/examhash.html).

cachegrind cost model
---------------------

Instead of costly benchmarking, we can count the instructions via cachegrind.
Thanks to davem for this trick.

We create miniperl's for all our hash funcs. I've add a new `Configure -Dhash_func=$h` config variable for this, but a `-DPERL_HASH_FUNC_$h` is also enough.

    for m in miniperl-*; do
      echo $m;
      valgrind --tool=cachegrind ./$m -e'my %h=("foo"=>1);$h{foo} for 0..100' 2>&1 | \
        egrep 'rate|refs|misses';
    done

And we write a [simple script](https://github.com/rurban/perl-hash-stats/blob/master/cachegrind-cost.pl) to apply the cost functions for various
Lx cache misses. cachegrind can only do the first and last cache line,
so we count 10 insn for a L1 (_first line_) miss, and 200 insn for a
LL (_last line_) miss.

    $ ./cachegrind-cost.pl log.hash-speed |sort -nk2 -t$'\t'

| hash       |cost [insn]| notes        |
|------------|----------:|--------------|
| CRC32      | 12784453  | x86\_64 only, insecure |
| FNV1A      | 12795316  | bad |
| FNV1A_YT   | 12828301  | bad |
| SDBM       | 12839245  | bad |
| MURMUR64A	 | 12839299  |     |
| MURMUR64B	 | 12841372  |     |
| DJB2       | 12847972  | bad |
| METRO64CRC | 12848269  | x86\_64 only |
| METRO64    | 12848838  |     |
| SUPERFAST  | 12857381  | bad |
| OAAT_OLD   | 12869646  | bad |
| MURMUR3    | 12870102  |     |
| OOAT       | 12870735  | bad |
| SPOOKY32   | 12884726  |     |
| OOAT_HARD  | 12901549  | bad |
| SIPHASH    | 12915041  |     |


See also
--------

* See [blogs.perl.org: statistics-for-perl-hash-tables](http://blogs.perl.org/users/rurban/2014/04/statistics-for-perl-hash-tables.html) for a more detailled earlier description, and

* [Emmanuel Goossaert's blog](http://codecapsule.com/2013/05/13/implementing-a-key-value-store-part-5-hash-table-implementations/) compares some hash table implementations and esp. collision handling for efficiency, not security.

* See [smhasher](https://github.com/rurban/smhasher) for performance and quality tests
of most known hash functions.

* See [Perfect::Hash](https://github.com/rurban/Perfect-Hash) for benchmarks and
implementations of **perfect hashes**, i.e. fast lookup in readonly stringmaps.

* _hash.stats_ for the distribution of the collisions

* _hash.result.*_ for the table sizes
