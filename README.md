Smart contract Tournament-TR

The contract is written in the Solidity language and intended for implementation on Ethereum. It contains function set for collecting and distribution of prize fund of a game tournament. The type of a game does not matter. The tournament should be organized by the following principle: the prize fund is the sum of entrance fees of players, the one winner receives the fixed share of the prize fund, the rest of the funds is taken away by the tournament organizer.

The contract contains functions of:

    control of the tournament statuses;
    postponement of participants registration deadline;
    entering (re-entering) into the tournament;
    unregistering for the tournament with full refund;
    withdrawal of prize amount by the winner;
    withdrawal of balance of the tournament by its organizer after the winner announcement, minus the winner share;
    full refund to players if the tournament has been terminated without the winner announcement.

Statuses of the tournament

The tournament can have one of the following statuses:

    NotTerminated ⏤ is not complete (proceeds);
    LackOfPlayers ⏤ is terminated due to lack of players;
    Cancelled ⏤ is cancelled;
    NoWinner ⏤ is terminated without the winner announcement;
    Winner ⏤ is terminated due to the winner announcement.

After the contract creation the tournament obtain the status of NotTerminated and then a tournament irreversibly turns, depending on the reason, into one of four alternative termination statuses.

The status of LackOfPlayers is established if after registration deadline passed the number of players appears less than initially set minimum number of players. The specified check is carried out by the withdraw function caused by the organizer.

Any of the statuses of Cancelled and NoWinner is established by the organizer by means of the terminate function. This function can be executed even before the registration deadline, and in this case entering stops ahead of schedule.

The status of Winner is established during execution of the announceWinner function caused by the organizer for the winner announcement.

About representation of time in the contract

Registration deadline (entryEndTime variable) and also the now property used in the contract code as value of the current time have the Unix time format which is the number of seconds that have elapsed since 00:00:00, 1 January 1970, Coordinated Universal Time (UTC).

It should be noted that the now does not give current astronomical time. It is just alias of block.timestamp ⏤ timestamp of the current block. Therefore the "current" time is defined in the contract with some share of uncertainty. In the description of the Solidity language it is noted:

    The current block timestamp must be strictly larger than the timestamp of the last block, but the only guarantee is that it will be somewhere between the timestamps of two consecutive blocks in the canonical chain.

Typical scheme of the contract performance

The creator of the contract executes the contract constructor during which initializes the following parameters:

    address of the tournament organizer (organizer variable);
    minimum number of players (minNumOfPlayers variable);
    entrance fee (entryFee variable);
    the winner's percentage share of the prize fund (winnerShare variable);
    participants registration deadline (entryEndTime variable).


