perl-hash-stats
===============

Counting the collisions with perl hash tables per function.
(linear chaining in a linked list, subject to collision attacks)

Average case (perl core testsuite)
----------------------------------

| Hash Function		| collisions| cycles/hash |
|:------------------|----------:|------------:|
| CRC32				| 1.078		| 29.78		  |
| SUPERFAST			| 1.081		| 34.72 	  |
| ONE_AT_A_TIME_HARD| 1.092		| 83.75		  |
| SIPHASH			| 1.091		| 154.68	  |
| ONE_AT_A_TIME		| 1.098		| 43.62       |
| ONE_AT_A_TIME_OLD	| 1.100 	| 43.62   	  |
| MURMUR3			| 1.105		| 34.03 	  |
| DJB2				| 1.131		| 44.73   	  |
| SDBM				| 1.146		| 30.57   	  |
| CITY				|   ?		| 30.13	      |


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
* SDBM and DJBJ did not produce a workable miniperl. Needed to [patch](https://github.com/rurban/perl-hash-stats/blob/master/sdbm%2Bdjb2.patch) them. Seeing that a HASH=0, effectively creating a long list of linear collisions in HvARRAY[0], does not work in current perl5, makes me feel bad. Note that seed + len is to prevent from the \0 attack.

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
|   	0	|  26895000 |
|   	1	|  98179685 |
|   	2	|  25832401 |
|   	3	|   5582369 |
|   	4	|    660175 |
|   	5	|     53429 |
|   	6	|      5726 |
|   	7	|       157 |
|   	8	|         5 |

Note that 0 collisions can occur with an early return in the hash
table lookup function, such as with empty hash tables.
The number of collisions is independent of the hash table size or key length.
It depends on the fill factor, the quality of the hash function and the key.

This is the average case. Worst cases can be produced by guessing the random hash
seed from leakage of sorting order (unsorted keys in JSON, YAML, RSS interfaces, or such),
(_or even fooling with the ENV or process memory_), and then creating colliding keys, which
would lead to exponential time DOS attacks with linear time attack costs. [RT #22371](https://rt.perl.org/Public/Bug/Display.html?id=22371)
Long running perl processes with publicly exposed sorting order and input acceptance of hash keys
should really be avoided without proper countermeasures. PHP e.g. does MAX\_POST\_SIZE.
Perl and similar dynamic languages really need to improve their collision algorithm, and choose
a combination of fast and good enough hash function. None of this is currently implemented.

See [blogs.perl.org: statistics-for-perl-hash-tables](http://blogs.perl.org/users/rurban/2014/04/statistics-for-perl-hash-tables.html) for a more detailled description.

See
---

* hash.stats for the distribution of the collisions
* hash.result.* for the table sizes
