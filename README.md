# Smart contract Tournament-TR

The contract is written in the Solidity language and intended for implementation on Ethereum. It contains function set for collecting and distribution of prize fund of a game tournament. The type of a game does not matter. The tournament should be organized as follows: the prize fund is the sum of fixed entrance fees of players, the one winner receives the predefined share of the prize fund, the rest of the funds is taken away by the tournament organizer.

**The contract contains functions of:**

* control of the tournament statuses;
* entering (re-entering) into the tournament;
* unregistering for the tournament with full refund;
* postponement of entrants registration deadline;
* withdrawal of prize amount by the winner;
* withdrawal of balance of the tournament by its organizer after the winner announcement, minus the winner share;
* full refund to players in case the tournament has been terminated with no winner announced.

## Statuses of the tournament

**The tournament can have one of the following statuses:**

* *NotTerminated* ⏤ is not complete (proceeds);
* *LackOfPlayers* ⏤ is terminated due to lack of players;
* *Cancelled* ⏤ is cancelled;
* *NoWinner* ⏤ is terminated with no winner announced;
* *Winner* ⏤ is terminated due to the winner announcement.

During the contract creation the tournament is assigned the status of *NotTerminated*. When one of the reasons for termination further appears, the tournament is going irreversibly to the corresponding one of four alternative statuses of termination.

The status of *LackOfPlayers* is assigned when after registration deadline passed the number of players appears less than predefined minimum number of players. The due check is performed while executed `withdraw` function called by the organizer.

Any of the statuses of *Cancelled* and *NoWinner* is assigned by the organizer by means of `terminate` function. The function can be executed even before the registration deadline passed, with immediate effect of entering (re-entering) and unregistering stop.

The status of *Winner* is assigned during execution of `announceWinner` function called by the organizer in order to announce winner.

## About time representation in the contract

Registration deadline (entryEndTime variable) and also `now` property used in the contract code as value of the current time have the [Unix time](https://en.wikipedia.org/wiki/Unix_time) format which is the number of seconds that have elapsed since 00:00:00, 1 January 1970, Coordinated Universal Time (UTC).

It should be noted that `now` does not give current astronomical time. It is just alias of `block.timestamp` ⏤ the current block timestamp. Therefore the "current" time is defined in the contract with some share of uncertainty. In the description of the [Solidity language](https://solidity.readthedocs.io/en/v0.5.6/units-and-global-variables.html#index-2) it is noted:

>The current block timestamp must be strictly larger than the timestamp of the last block, but the only guarantee is that it will be somewhere between the timestamps of two consecutive blocks in the canonical chain.

## Typical scheme of the contract implementation

The creator of the contract executes the contract constructor which initializes the following parameters:

* address of the tournament organizer (`organizer` variable);
* minimum number of players (`minNumOfPlayers` variable);
* entrance fee (`entranceFee` variable);
* the winner's percentage share of the prize fund (`winnerShare` variable);
* participants registration deadline (`deadline` variable).

Herewith `organizer` variable is initialized by the address of the constructor's caller, and other variables are initialized by values of the same-name input parameters. Subsequently, registration deadline can be changed by the organizer only once, other variables are not subject to change.

Before the registration starts, the organizer generates a set of tables with unique entrance codes and then distributes these tables among the agents that invite participants. If the organizer invites participants directly, he or she uses one of the tables, like agents. By inviting a participant, the agent provides him or her with one of the available entrance codes. The code given to the participant cannot be re-given to another one, but the participant who received the code has the right to use it again while re-entering into the tournament.

