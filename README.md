perl-hash-stats
===============

Counting the collisions with perl hash tables per function.
(linear chaining in a linked list, subject to collision attacks)

Average case (perl core testsuite)
----------------------------------

| Hash Function		| collisions| cycles/hash |
|:------------------|----------:|------------:|
| CRC32				| 1.066		|  29.78	  |
| DJB2.1			| 1.070		|  44.73   	  |
| CRC32.1			| 1.078		|  29.78	  |
| SUPERFAST			| 1.081		|  34.72 	  |
| SDBM.1			| 1.082		|  30.57   	  |
| ONE_AT_A_TIME_HARD| 1.092		|  83.75	  |
| SIPHASH			| 1.091		| 154.68	  |
| ONE_AT_A_TIME		| 1.098		|  43.62      |
| ONE_AT_A_TIME_OLD	| 1.100 	|  43.62   	  |
| MURMUR3			| 1.105		|  34.03 	  |
| DJB2				| 1.131		|  44.73   	  |
| SDBM				| 1.146		|  30.57   	  |
| CITY				|   ?		|  30.13      |


Less collisions are better, less cycles/hash is faster.
A hash table lookup consists of one constant hash function
(depending only on the length of the key) and then resolving
0-x collisions (in our avg case 0-8).

The perl5 testsuite has a key size of median = 20, and avg of 133.2.
The most commonly used key sizes are 4, 101 and 2, the most common
hash tables sizes are 7, 63 and 127.

A hash table size of 7 uses the last 3 bits of the hash function result,
63 uses only 6 bits of 32 and 127 uses 7 bits.

* collisions are the number of linked list iterations per hash table usage.
* cycles/hash is measured with [smhasher](https://github.com/rurban/smhasher)
for 10 byte keys. (see "Small key speed test")
* SDBM and DJBJ did not produce a workable miniperl. Needed to [patch](https://github.com/rurban/perl-hash-stats/blob/master/sdbm%2Bdjb2.patch) them.
* The .1 variants add the len to the seed to fight \0 attacks.

Hash table sizes
----------------

| size		|     count |
|:---------:|----------:|
|	0	    |      2403 |
|	1	    |       383 |
|	3	    |       434 |
|	7	    |  30816359 |
|	15	    |  19761019 |
|	31	    |  20566188 |
|	63	    |  30131283 |
|	127	    |  28054277 |
|	255	    |  15104276 |
|	511	    |   7146648 |
|	1023	|   3701004 |
|	2047	|   1015462 |
|	4095	|    217107 |
|	8191	|    284997 |
|	16383	|    237284 |
|	32767	|    169823 |

Note that perl ony supports int32 (32bit) sized tables, not 64bit arrays.
Larger keysets need to be tied to bigger key-value stores, such as
[LMDB_File](http://search.cpan.org/dist/LMDB_File/) or at least
AnyDBM_File, otherwise you'll get a hell lot of collisions.


Number of collisions with CRC32
------------------------------

| collisions|     count |
|:---------:|----------:|
|   	0	|  26176163 |
|   	1	| 100979326 |
|   	2	|  25745874 |
|   	3	|   4526405 |
|   	4	|    512177 |
|   	5	|     46749 |
|   	6	|      4015 |
|   	7	|       187 |
|   	8	|         8 |

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
where collisions just trigger hash table resizes.
DJB's DNS server has an explicit check for "hash flooding" attempts.
Some rare hash tables implementations use rb-trees.

perl5 should also use prime number sized hash tables to reduce
collisions in the averege case. For 32bit the primes can be stored in
a constant table as in glibc.

For city there currently exists a simple universal function to easily create collisions per seed.
Note that this exists for every hash function, just encode your hash SAT solver-friendly and look
at the generated model. It is even incredibly simple if you calculate only the needed last bits
dependent on the hash table size (8-15 bits).
So striking out city for such security claims does not hold.
The code is just not out yet, and the costs for some slower (cryptographically secure)
hash functions might be too high. But people already encoded SHA-2 into SMTLIB code to
attack bitcoin.

See [blogs.perl.org: statistics-for-perl-hash-tables](http://blogs.perl.org/users/rurban/2014/04/statistics-for-perl-hash-tables.html) for a more detailled description, and
[Emmanuel Goossaert's blog](http://codecapsule.com/2013/05/13/implementing-a-key-value-store-part-5-hash-table-implementations/) compares some hash table implementations and esp. collision handling for efficiency, not security.

See
---

* hash.stats for the distribution of the collisions
* hash.result.* for the table sizes
