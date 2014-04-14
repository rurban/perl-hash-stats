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

The perl5 testsuite has a key size of median = 20, and avg of 133.2. The most commonly used key sizes are 4, 101 and 2.

* collisions are the number of linked list iterations per hash table usage.
* cycles/hash is measured with [smhasher](https://github.com/rurban/smhasher)
for 10 byte keys. (see "Small key speed test")
* SDBM and DJBJ did not produce a workable miniperl. Needed to [patch](https://github.com/rurban/perl-hash-stats/blob/master/sdbm%2Bdjb2.patch) them. Seeing that a HASH=0, effectively creating a long list of linear collisions in HvARRAY[0], does not work iun current perl5, makes me feel bad. Note that seed + len is to prevent from the \0 attack.

See [statistics-for-perl-hash-tables](http://blogs.perl.org/users/rurban/2014/04/statistics-for-perl-hash-tables.html)

See
---

* hash.stats for the distribution of the collisions
* hash.result.* for the table sizes
