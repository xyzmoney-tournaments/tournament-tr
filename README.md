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

Before the registration starts, the organizer generates a set of tables with unique entrance codes and then distributes these tables among agents that invite participants. If the organizer invites participants directly, he or she uses one of the tables, like the agents. By inviting a participant, an agent provides him or her with one of the available entrance codes. The code given to a participant cannot be re-given to another one, but the participant has the right to use it again while re-entering into the tournament.

To enter the tournament, a participant calls `enter` function, specifying the entrance fee amount (`entranceFee` variable) and the entrance code received from the organizer or from an agent. One can enter into the tournament only while the registration deadline not passed, as long as the tournament has the status of *NotTerminated* (the organizer can terminate the tournament before the deadline if there are grounds for that). Also the participants who has been unregistered for the tournament, can re-enter into it. The person who entered is considered further a player. Besides, if there is his or her first enter into the tournament, then the address of this person is also added into the list of entrants.

To unregister for the tournament, an entrant calls `unregister` function. The unregistering can be performed only by a player and only while the registration deadline not passed, as long as the tournament has the status of *NotTerminated*. The function transfers the entrance fee amount to the address of this participant. At the same time the participant is eliminated players, but remains in the list of entrants.

If necessary the organizer can reassign the registration deadline by shifting it either forward no more than to 72 hours, or backward so there are not less than 24 hours between present time and the new deadline. Such reassignment is possible if the tournament is not terminated yet.

If after the registration deadline passed the number of players (variable `playersCounter`) appears less minimum number of players (variable `minNumOfPlayers`), then the next call of `withdraw` function gives the tournament the status of *LackOfPlayers* (if the tournament was not terminated before by `terminate` function). Both the functions call only by the organizer.

If after the registration deadline passed the number of players appears not less minimum number of players, the tournament is considered begun. To terminate the tournament, the organizer should either announce the winner by calling of `announceWinner` function (therefore the tournament is automatically given the status of *Winner*), or to terminate the tournament with no winner announced by calling `terminate` function with explicit assignment to the tournament of one of the statuses of *Cancelled* or *NoWinner*. The choice of the status is maid by the organizer depending on the reason of the winner absence. It is possible to terminate the tournament by the winner announcement not earlier than in 24 hours after the registration deadline passed. As opposed to it, it is possible to terminate the tournament with no winner announced even before the deadline.

From the moment the tournament got the status of *Winner* only the winner can take away the prize by calling `takePrize` function which transfers the prize amount to the winner address. If the tournament has been terminated with no winner announced (i.e. with one of the statuses of *LackOfPlayers*, *Cancelled* or *NoWinner*), then all players can refund by calling of `takeMoneyBack` function.

