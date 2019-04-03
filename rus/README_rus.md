# Смарт-контракт Tournament-TR

Контракт написан на языке Solidity и предназначен для реализации на базе блокчейн-платформы Ethereum. Он содержит набор функций для формирования и распределения призового фонда игрового турнира. Вид игры в контракте не оговаривается. Турнир должен быть организован по следующему принципу: призовой фонд турнира формируется из фиксированных вступительных взносов игроков, единственный победитель получает долю призового фонда, задаваемую при создании контракта, оставшиеся средства забирает организатор турнира.

**Контракт содержит функции для:**
* контроля статусов турнира;
* переноса времени окончания приёма вступительных взносов;
* внесения и изъятия игроками своих вступительных взносов;
* выплаты приза победителю;
* получения остатка средств турнира его организатором после объявления победителя, за вычетом суммы приза победителю;
* возврата взносов игрокам в случае завершения турнира без объявления победителя.

## Состояния (статусы) турнира

**Турнир может находиться в одном из следующих состояний (статусов):**
* *NotTerminated* ⏤ не завершён (продолжается);
* *LackOfPlayers* ⏤ завершён из-за недостаточного количества игроков;
* *Cancelled* ⏤ отменён;
* *NoWinner* ⏤ завершён без объявления победителя;
* *Winner* ⏤ завершён в связи с объявлением победителя.

При создании контракта турниру присваивается статус *NotTerminated*, после чего турнир необратимо переходит, в зависимости от причины, в один из четырёх альтернативных статусов завершения.

Статус *LackOfPlayers* устанавливается в случае, если после завершения периода приёма вступительных взносов число игроков оказывается меньше изначально заданного минимального количества игроков. Указанную проверку выполняет вызываемая организатором функция `withdraw`.

Любой из статусов *Cancelled* и *NoWinner* устанавливается организатором посредством функции `terminate`. Данная функция может быть выполнена ещё до истечения времени приёма вступительных взносов, и в этом случае приём взносов прекращается досрочно.

Статус *Winner* устанавливается в ходе исполнения функции `announceWinner`, вызываемой организатором турнира для объявления победителя.

## О представлении времени в контракте

Время окончания приёма вступительных взносов (переменная `deadline`), а также свойство `now`, используемое в коде контракта в качестве значения текущего времени, имеют формат [Unix-времени](https://ru.wikipedia.org/wiki/Unix-%D0%B2%D1%80%D0%B5%D0%BC%D1%8F), в котором время представлено количеством секунд, прошедших с полуночи (00:00:00 UTC) 1 января 1970 года.

Следует отметить, что свойство `now` является не отражением текущего астрономического времени, а всего лишь псевдонимом свойства `block.timestamp` ⏤ отметки времени текущего блока. Поэтому "текущее" время определяется в контракте с некоторой долей неопределённости. В [описании языка Solidity](https://solidity.readthedocs.io/en/v0.5.6/units-and-global-variables.html#index-2) отмечается:
>The current block timestamp must be strictly larger than the timestamp of the last block, but the only guarantee is that it will be somewhere between the timestamps of two consecutive blocks in the canonical chain.

## Типовая схема исполнения контракта

Создатель контракта запускает выполнение конструктора контракта, в ходе которого инициализируются следующие параметры:
* адрес организатора турнира (переменная `organizer`);
* минимальное количество игроков (переменная `minNumOfPlayers`);
* размер вступительного взноса (переменная `entranceFee`);
* доля победителя в процентах от призового фонда (переменная `winnerShare`);
* время окончания приёма вступительных взносов (переменная `deadline`).

При этом в переменную `organizer` заносится адрес лица, запустившего конструктор, а остальные переменные инициализируются значениями соответствующих входных параметров конструктора. В дальнейшем время окончания приёма вступительных взносов может быть изменено организатором турнира только один раз, остальные переменные изменению не подлежат.

Ещё до начала приёма вступительных взносов организатор турнира формирует комплект кодовых таблиц, содержащих уникальные входные коды, и раздаёт их посредникам, привлекающим участников в турнир. Если организатор турнира привлекает участников самостоятельно, он, аналогично посредникам, использует одну из этих таблиц. Привлекая участника в турнир, посредник передаёт ему один из входных кодов, содержащихся в имеющейся у этого посредника кодовой таблице. Однажды переданный участнику код повторной передаче другому участнику не подлежит (хотя участник, получивший этот код, имеет право вводить его неоднократно при последующих входах в турнир).

Лица, желающие принять участие в турнире, совершают платёж на функцию `enter` в размере вступительного взноса (переменная `entranceFee`), при этом дополнительно вводят в функцию входной код, полученный от организатора турнира или от посредника. Вход в турнир может быть совершён только до момента окончания приёма вступительных взносов при условии, что турнир находится в статусе *NotTerminated* (организатор турнира может завершить турнир до истечения времени приёма взносов, если на то имеются основания). Заплатить на функцию `enter` могут также участники, ранее вышедшие из турнира, но желающие вновь войти в него. Лицо, сделавшее вступительный взнос, далее считается игроком. Кроме того, если это его первый вход в турнир, то данное лицо также заносится в список участников.

Участники, желающие выйти из турнира до его начала, вызывают функцию `unregister`. Выход может быть совершён только игроком и только до момента окончания приёма вступительных взносов при условии, что турнир находится в статусе *NotTerminated*. Функция переводит сумму вступительного взноса на адрес данного участника. При этом участник исключается из числа игроков, но остаётся в списке участников.

При необходимости организатор турнира может один раз перенести момент окончания приёма взносов ⏤ либо вперёд не более чем на 72 часа, либо назад с таким расчётом, чтобы от текущего момента времени до нового момента окончания приёма взносов был запас не менее 24 часов. Такой перенос возможен, если турнир ещё не завершён (имеет статус *NotTerminated*).

Если после истечения времени приёма вступительных взносов число игроков (переменная `playersCounter`) окажется меньше минимального количества игроков (переменная `minNumOfPlayers`), то при первом же вызове организатором функции `withdraw` турниру будет присвоен статус *LackOfPlayers* (если только турнир не был до этого завершён организатором посредством вызова функции `terminate`).

Если после истечения времени приёма вступительных взносов число игроков окажется не меньше минимального количества игроков, турнир считается начавшимся. Чтобы завершить турнир, организатор должен или объявить победителя турнира посредством вызова функции `announceWinner` (в результате чего турниру автоматически присваивается статус *Winner*), или объявить турнир завершённым без победителя, вызвав функцию `terminate` с явным присвоением турниру одного из статусов *Cancelled* или *NoWinner*. Выбор статуса определяет организатор турнира в зависимости от причины отсутствия победителя. Завершить турнир путём объявления победителя можно не ранее чем через 24 часа после истечения времени приёма вступительных взносов. В противовес этому, завершить турнир без победителя можно ещё до окончания приёма вступительных взносов.

С момента перехода турнира в статус *Winner* только победитель может забрать причитающийся ему приз, вызвав функцию `takePrize`, которая перечисляет сумму приза на адрес победителя. Если же турнир завершился без победителя (т.е. с одним из статусов *LackOfPlayers*, *Cancelled* или *NoWinner*), то с этого момента все участники могут забрать свои вступительные взносы посредством вызова функции `refund`.

После перехода турнира в статус *Winner* организатор может забрать доступный ему остаток средств на счёте контракта (переменная `availableFunds`) посредством функции `withdraw`. Доступный для снятия остаток средств равен балансу контракта (переменная `contractBalance`) при условии, что победитель забрал свой приз, в противном случае указанный остаток будет уменьшен на размер приза.

## Переменные контракта

**`organizer`** ⏤ адрес организатора турнира. Задаётся при исполнении конструктора контракта. В эту переменную заносится адрес создателя контракта ⏤ лица, запустившего исполнение конструктора.

**`winner`** ⏤ адрес победителя турнира. Задаётся организатором турнира по завершении игры в случае выявления победителя.

**`minNumOfPlayers`** ⏤ минимальное количество игроков. Если после окончания приёма вступительных взносов количество игроков (переменная `playersCounter`) окажется меньше значения переменной `minNumOfPlayers`, турнир автоматически получает статус *LackOfPlayers*. Значение `minNumOfPlayers` задаётся при исполнении конструктора контракта.

**`playersCounter`** ⏤ счётчик игроков. В число игроков включаются лица, которые до момента окончания приёма вступительных взносов сделали свой взнос и не забрали его обратно.

**`entrantsCounter`** ⏤ счётчик участников.

**`entranceFee`** ⏤ размер вступительного взноса в Wei (1 Ether = 10¹⁸ Wei). Задаётся при исполнении конструктора контракта.

**`prizeFund`** ⏤ размер призового фонда в Wei. Равен сумме всех вступительных взносов игроков.

**`winnerShare`** ⏤ доля победителя в процентах от призового фонда. Задаётся при исполнении конструктора контракта.

**`deadline`** ⏤ время окончания приёма вступительных взносов в формате Unix-времени. Первоначальное значение переменной `deadline` задаётся при исполнении конструктора контракта. Впоследствии оно может быть изменено, но только один раз.

**`contractBalance`** ⏤ баланс контракта.

**`availableFunds`** ⏤ остаток средств на счёте контракта, доступный организатору для снятия.

**`status`** ⏤ текущий статус турнира. Может принимать одно из следующих значений:
* *NotTerminated* ⏤ турнир не завершён (продолжается);
* *LackOfPlayers* ⏤ турнир завершён из-за недостаточного количества игроков;
* *Cancelled* ⏤ турнир отменён;
* *NoWinner* ⏤ турнир завершён без объявления победителя;
* *Winner* ⏤ турнир завершён в связи с объявлением победителя.

Начальный статус турнира ⏤ *NotTerminated*.

**`deadlineIsChanged`** ⏤ признак изменения времени окончания приёма взносов. Служит для фиксации факта изменения указанного времени (время окончания приёма взносов может быть изменено только один раз).

**`prizeIsPaid`** ⏤ признак выплаты приза победителю. Служит для фиксации факта выплаты приза, что позволяет пресекать попытки повторного получения приза.

**`entrantsList`** ⏤ динамический массив, содержащий список адресов участников турнира (в том числе вышедших).

**`entranceCodes`** ⏤ соответствие (mapping) <адрес участника> => <входной код участника>.

Входной код предназначен для выяснения, кем данный участник был привлечён к участию в турнире. До начала приёма вступительных взносов организатор турнира формирует комплект кодовых таблиц, содержащих уникальные входные коды, и раздаёт их посредникам, привлекающим участников в турнир. Если организатор турнира привлекает участников самостоятельно, он тоже использует одну из этих таблиц. Участник вводит входной код, полученный от организатора турнира или от посредника, при каждом входе в турнир. При этом участник может вводить как один и тот же код, так и разные коды (например, в случае, если к моменту повторного входа в турнир участник сменил посредника). Впоследствии по последнему из входных кодов, введённых данным участником, организатор турнира определяет, каким посредником тот был привлечён.

**`entranceCounters`** ⏤ соответствие <адрес участника> => <счётчик числа входов участника>.

Счётчик числа входов участника позволяет определить:
* сколько раз данный участник входил в турнир;
* находится ли этот участник в данный момент в турнире (т.е. является ли он игроком) или вышел из турнира;
* забрал ли игрок свой взнос, если турнир завершился без объявления победителя.

Достигается такая комплексная информативность тем, что счётчик имеет знак: если счётчик положительный ⏤ участник участвует в турнире (является игроком), если отрицательный ⏤ участник забрал взнос и вышел из турнира. Шаг изменения счётчика равен 10. При первом входе участника в турнир в счётчик числа входов этого участника заносится 10. Если после этого участник вышел из турнира, знак счётчика меняется на противоположный. Если затем участник опять зашёл, счётчик становится равным 20, и так далее. Короче говоря, при поочерёдных входах и выходах участника счётчик числа его входов будет меняться в следующей последовательности: 10, -10, 20, -20, 30, … Если после завершения турнира без объявления победителя игрок забирает свой взнос, счётчик числа его входов дополнительно увеличивается на 1.

**`whoseEntranceCode`** ⏤ соответствие <входной код участника> => <адрес участника>. Используется для быстрой проверки вводимого входного кода на уникальность среди имеющихся в контракте входных кодов игроков ⏤ новый входной код не должен присутствовать среди входных кодов, введённых другими игроками к моменту данной проверки (при этом допускается наличие этого кода среди входных кодов, введённых участниками, уже вышедшими из турнира). При выходе участника из турнира его входной код удаляется из соответствия, что освобождает этот код для нового ввода.

## События (events)

**`onCreation`** ⏤ вызывается при создании контракта. С данным событием передаются следующие параметры:
* минимальное количество игроков;
* размер вступительного взноса;
* доля победителя;
* время окончания приёма вступительных взносов.

**`onEtnrance`** ⏤ вызывается после каждого входа участника в турнир (см. описание функции `enter`). С данным событием передаются следующие параметры:
* адрес вошедшего участника;
* входнлй код, введенный данным участником;
* счётчик числа входов этого участника после данного входа.

**`onUnregistering`** ⏤ вызывается после каждого выхода участника из турнира (см. описание функции `unregister`). С данным событием передаются следующие параметры:
* адрес вышедшего участника;
* счётчик числа входов этого участника после данного выхода.

**`onDeadlineChange`** ⏤ вызывается после изменения времени окончания приёма вступительных взносов (см. описание функции `changeDeadline`). С данным событием передаётся новое значение указанного момента времени.

**`onWinnerAnnouncement`** ⏤ вызывается после занесения адреса победителя в переменную `winner` (см. описание функции `announceWinner`). С данным событием передаётся параметр адрес игрока, объявленного победителем.

**`onPrizePayment`** ⏤ вызывается после того, как победитель забрал свой приз (см. описание функции `takePrize`). С данным событием передаются следующие параметры:
* адрес игрока, забравшего приз;
* сумма приза.

**`onTermination`** ⏤ вызывается после присвоения турниру одного из статусов *LackOfPlayers*, *Cancelled* или *NoWinner*. Статус *LackOfPlayers* может присваиваться в функции `withdraw`, статусы *Cancelled* и *NoWinner* ⏤ в функции `terminate`. С данным событием передаётся новый статус турнира.

**`onRefund`** ⏤ вызывается после каждого изъятия кем-либо из участников своего взноса в случае завершения турнира без победителя (см. описание функции `refund`). С данным событием передаётся адрес игрока, забравшего свой взнос.

**`onWithdrawal`** ⏤ вызывается после каждого снятия суммы с баланса турнира организатором (см. описание функции `withdraw`). С данным событием передаётся снятая сумма.

## Функции контракта

### `enter`

**Назначение:**
* принимает в контракт вступительные взносы от лиц, желающих стать игроками (в том числе от участников, ранее вышедших из турнира).

**Входной параметр:**
* входной код, полученный участником от посредника или организатора турнира.

**Условия, позволяющие выполнить функцию:**
* войти в турнир можно только при его текущем статусе *NotTerminated*;
* взнос должен быть сделан до момента окончания приёма взносов;
* лицо, вызвавшее функцию, не должно быть игроком (т.е. этот человек либо первый раз входит в турнир, либо перед этим вышел из турнира);
* вносимая сумма должна быть точно равна размеру вступительного взноса;
* входной код должен быть 16-значным числом;
* входной код должен быть уникальным среди входных кодов игроков.

После успешного прохождения входных условий функция вычисляет новое значение счётчика числа входов данного участника по формуле:

    _entranceCounter = 10 - _entranceCounter

и сохраняет это значение. Если участник первый раз входит в турнир, то в дополнеие к этому его адрес заносится в список адресов участников, а счётчик участников увеличивается на 1. Далее адрес нового участника добавляется в соответствие `whoseEntranceCode` по ключу входного кода. После этого счётчик игроков (переменная `playersCounter`) увеличивается на 1, а призовой фонд (переменная `prizeFund`) ⏤ на размер вступительного взноса. Затем вызывается событие `onEtnrance`, публикующее адрес данного участника, введённый им входной код и новое значение счётчика числа его входов в турнир. В конце обновляется баланс контракта (переменная `contractBalance`).

### `unregister`

**Назначение:**
* отдаёт вступительные взносы игрокам, желающим покинуть турнир.

Входных параметров не имеет.

**Условия, позволяющие выполнить функцию:**
* выйти из турнира можно только при его текущем статусе *NotTerminated*;
* выход из турнира должен быть сделан до момента окончания приёма взносов;
* лицо, вызвавшее функцию, должно числиться игроком.

После успешного прохождения входных условий (что означает, что лицо, вызвавшее функцию, является игроком) функция инвертирует знак счётчика числа входов выходящего участника и обнуляет значение по ключу <входной код этого участника> в соответствии `whoseEntranceCode`. Далее счётчик игроков (переменная `playersCounter`) уменьшается на 1, а призовой фонд ⏤ на размер вступительного взноса. Затем вызывается событие `onUnregistering`, публикующее адрес данного участника и новое значение счётчика числа его входов в турнир. В конце функция переводит сумму взноса этому участнику и обновляет баланс контракта (переменная `contractBalance`).

### `changeDeadline`

**Назначение:**
* позволяет поменять время окончания приёма вступительных взносов.

**Входной параметр:**
* новое значение указанного момента времени.

**Условия, позволяющие выполнить функцию:**
* лицо, вызвавшее функцию, должно являться организатором турнира;
* изменить время окончания приёма взносов можно только при текущем статусе турнира *NotTerminated*;
* изменить время окончания приёма взносов можно только до истечения действующего периода приёма взносов;
* изменить время окончания приёма взносов можно только один раз (переменная `deadlineIsChanged` должна быть равна *false*);
* новое время окончания приёма взносов должно отличаться от действующего;
* время окончания приёма взносов может быть сдвинуто или вперёд не более чем на 72 часа, или назад с таким расчётом, чтобы от текущего времени до нового момента окончания приёма взносов был запас не менее 24 часов.

После успешного прохождения входных условий функция меняет значение переменной `deadline` на значение входного параметра, присваивает переменной `deadlineIsChanged` значение *true* и вызывает событие `onDeadlineChange`, публикующее новое значения времени окончания приёма вступительных взносов.

### `announceWinner`

**Назначение:**
* сообщает контракту адрес победителя, при этом переводит турнир в статус *Winner*.

**Входной параметр:**
* адрес победителя турнира.

**Условия, позволяющие выполнить функцию:**
* лицо, вызвавшее функцию, должно являться организатором турнира;
* объявить победителя можно только в текущем статусе турнира *NotTerminated*;
* победитель может быть объявлен не ранее чем через 24 часа после завершения приёма вступительных взносов;
* победитель может быть только из числа игроков.

После успешного прохождения входных условий функция обновляет остаток средств, доступный организатору для снятия (переменная `availableFunds`). Далее функция заносит в переменную `winner` значение входного параметра, а в переменную `status` ⏤ статус *Winner*, затем вызывает событие `onWinnerAnnouncement`, публикующее адрес победителя.

### `terminate`

**Назначение:**
* присваивает турниру один из статусов *Cancelled* или *NoWinner*.

**Входной параметр:**
* присваиваемый статус.

**Условия, позволяющие выполнить функцию:**
* лицо, вызвавшее функцию, должно являться организатором турнира;
* присвоить новый статус можно только в текущем статусе турнира *NotTerminated*;
* присвоить можно только статус *Cancelled* или *NoWinner*.

После успешного прохождения входных условий функция заносит в переменную `status` значение входного параметра, а затем вызывает событие `onTermination`, публикующее новый статус турнира.

### `takePrize`

**Назначение:**
* выплачивает победителю его долю призового фонда.

Входных параметров не имеет.

**Условия, позволяющие выполнить функцию:**
* забрать приз можно только при текущем статусе турнира *Winner*;
* забрать приз может только победитель;
* приз выплачивается только один раз (переменная `prizeIsPaid` должна быть равна *false*).

После успешного прохождения входных условий функция рассчитывает сумму приза победителю по формуле:

    _prize = prizeFund * winnerShare / 100

Затем функция устанавливает признак выплаты приза (переменная `prizeIsPaid`) в *true* и вызывает событие `onPrizePayment`, публикующее адрес победителя и сумму приза. После этого функция переводит сумму приза победителю и обновляет баланс контракта (переменная `contractBalance`).

### `refund`

**Назначение:**
* возвращает игрокам взносы, если турнир находится в статусе *LackOfPlayers*, *Cancelled* или *NoWinner*.

Входных параметров не имеет.

**Условия, позволяющие выполнить функцию:**
* забрать свои взносы могут только игроки турнира;
* забрать свои взносы могут только игроки, не сделавшие этого ранее (признак возврата взноса игрока, забирающего взнос, должен быть равен *false*);
* забрать свой взнос можно, только если турнир находится в статусе *LackOfPlayers*, *Cancelled* или *NoWinner*.

После успешного прохождения входных условий функция устанавливает признак возврата взноса этому игроку (увеличивает счётчик числа его входов на 1), затем вызывает событие `onRefund`, публикующее адрес игрока, забравшего свой взнос. После этого функция переводит сумму взноса игроку и обновляет баланс контракта (переменная `contractBalance`).

### `withdraw`

**Назначение:**
* устанавливает при соответствующих условиях статус турнира *LackOfPlayers* либо переводит организатору запрашиваемую сумму, если она > 0 и не превышает остатка средств, доступного для снятия.

**Входной параметр:**
* запрашиваемая сумма.

**Условие, позволяющее выполнить функцию:**
* лицо, вызвавшее функцию, должно являться организатором турнира.

После успешного прохождения входного условия функция, при выполнении соответствующих условий, присваивает турниру статус *LackOfPlayers*, вызывает событие `onTermination`, публикующее указанный статус, и завершается. Если же указанные условия не выполнились и при этом запрашиваемая сумма больше 0, но не превышает остатка средств, доступного организатору для снятия (переменная `availableFunds`), функция уменьшает доступный остаток на запрашиваемую сумму, вызывает событие `onWithdrawal`, публикующее указанную сумму, затем переводит запрашиваемую сумму организатору, после чего обновляет баланс контракта (переменная `contractBalance`).