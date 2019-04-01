pragma solidity ^0.5.0 <0.6.0;

contract Tournament-TR {

    address public organizer; // Адрес организатора турнира
    address public winner; // Адрес победителя турнира
    uint public minNumOfPlayers; // Минимальное количество игроков
    uint public playersCounter; // Счётчик игроков
    uint public entrantsCounter; // Счётчик участников (в том числе вышедших)
    uint public entryFee; // Вступительный взнос в Wei (1 Ether = 10^18 Wei)
    uint public prizeFund; // Призовой фонд в Wei
    uint public winnerShare; // Доля победителя (в процентах от призового фонда)
    uint public entryEndTime; // Время окончания приёма взносов (Unix time)
    uint public contractBalance; // Баланс контракта
    uint public availableFunds; // Сумма, доступная организатору для снятия
    // Перечень возможных статусов завершения турнира:
    // турнир не завершён (продолжается); недостаточно игроков; турнир отменён;
    // турнир завершён без объявления победителя; победитель объявлен.
    enum statuses {NotTerminated, LackOfPlayers, Cancelled, NoWinner, Winner}
    // Текущий статус турнира (начальный статус: NotTerminated)
    statuses public status;
    // Признак изменения времени окончания приёма взносов
    bool public entryEndTimeIsChanged;
    bool public prizeIsPaid; // Признак выплаты приза

    // Список адресов участников турнира (в том числе вышедших)
    address[] public entrantsList;
    // Соответствие <адрес участника> => <входной код участника>
    mapping (address => uint) public entrantEntryCode;
    // Соответствие <адрес участника> => <счётчик числа входов участника>
    mapping (address => int) public entrantEntriesCounter;
    // Соответствие <входной код участника> => <адрес участника>
    mapping (uint => address) public whoseEntryCode;

    // Событие создания контракта
    event onCreation(
        uint minNumOfPlayers, uint entryFee, uint winnerShare, uint entryEndTime
    );
    // Событие входа в турнир
    event onEnter(address entrantAddress, uint entryCode, int entriesCounter);
    // Событие выхода из турнира
    event onLeaving(address entrantAddress, int entriesCounter);
    // Событие изменения времени окончания приёма взносов
    event onEntryEndTimeChange(uint newEntryEndTime);
    // Событие объявления победителя
    event onWinnerAnnounce(address winnerAddress);
    // Событие выплаты приза победителю
    event onPrizePayment(address winnerAddress, uint amount);
    // Событие завершения турнира с одним из статусов завершения:
    // LackOfPlayers, Cancelled или NoWinner
    event onTermination(statuses status);
    // Событие возврата взноса игроку при завершении турнира без победителя
    event onMoneyBack(address playerAddress);
    // Событие снятия суммы с баланса турнира организатором
    event onWithdraw(uint amount);


    constructor (
        uint _minNumOfPlayers,
        uint _entryFee,
        uint _winnerShare,
        uint _entryEndTime
    ) public {
        organizer = msg.sender; // Организатор турнира = создатель контракта
        minNumOfPlayers = _minNumOfPlayers;
        entryFee = _entryFee;
        winnerShare = _winnerShare;
        entryEndTime = _entryEndTime;
        // Возбуждаем событие создания контракта
        emit onCreation(_minNumOfPlayers, _entryFee, _winnerShare, _entryEndTime);
    }

    // Модификатор для функций, выполнять которые уполномочен только организатор
    modifier byOrganizerOnly() {
        require(
            msg.sender == organizer,
            "Only organizer is authorized to perform this function"
        );
        _;
    }

    // Модификатор отката функции, если турнир в одном из статусов завершения
    modifier checkTermination() {
        // Текущий статус турнира
        statuses _status = status;
        // Откатываем функцию, если текущий статус турнира - LackOfPlayers
        if (_status == statuses.LackOfPlayers) {
            revert("The tournament has been terminated due to lack of players");
        }
        // Откатываем функцию, если текущий статус турнира - Cancelled или NoWinner
        if (_status == statuses.Cancelled ||
            _status == statuses.NoWinner) {
            revert("The tournament has been terminated by the organizer");
        }
        // Откатываем функцию, если текущий статус турнира - Winner
        if (_status == statuses.Winner) {
            revert("The tournament has been finished with winner announcement");
        }
        _;
    }

    /// enter принимает вступительные взносы от желающих стать игроками
    function enter(uint _entryCode)
        public
        payable
        checkTermination
    {
        // Счётчик числа входов лица, вызвавшего функцию
        int _entriesCounter = entrantEntriesCounter[msg.sender];
        // Размер вступительного взноса
        uint _amount = entryFee;

        // Если до этого функция не откатилась по одному из статусов завершения,
        // то войти в турнир можно только до истечения времени приёма взносов
        require(
            now < entryEndTime,
            "Time to enter the tournament has passed"
        );
        // Участник не может повторно войти в турнир, уже числясь игроком
        require(
            _entriesCounter <= 0,
            "You are already in the list of players"
        );
        // Вносимая сумма должна быть точно равна размеру вступительного взноса
        require(
            msg.value == _amount,
            "The amount you deposit is not equal to the required entry fee"
        );
        // Введённый входной код должен быть 16-значным числом
        require(
            _entryCode >= 1000000000000000 && _entryCode <= 9999999999999999,
            "The entry code must be a 16-digit number"
        );
        // Введённый входной код должен быть уникальным среди входных кодов игроков
        require(
            whoseEntryCode[_entryCode] == address(0),
            "The code you entered is already used"
        );

        // Продвигаем вперёд счётчик числа его входов
        _entriesCounter = 10 - _entriesCounter;
        // Сохраняем новое значение счётчика числа входов
        entrantEntriesCounter[msg.sender] = _entriesCounter;
        // Сохраняем новый входной код
        entrantEntryCode[msg.sender] = _entryCode;
        // Фиксируем, что входной код введён данным участником
        whoseEntryCode[_entryCode] = msg.sender;
        // Если данный участник первый раз вошёл в турнир
        if (_entriesCounter == 10) {
            entrantsCounter++; // Инкрементируем счётчик участников
            // Добавляем адрес нового участника в конец списка адресов участников
            entrantsList.push(msg.sender);
        }
        playersCounter++; // Инкрементируем счётчик числа игроков
        // Увеличиваем призовой фонд на величину вступительного взноса
        prizeFund += _amount;
        // Возбуждаем событие входа в турнир
        emit onEnter(msg.sender, _entryCode, _entriesCounter);
        contractBalance = address(this).balance; // Обновляем баланс контракта
    }

    /// leave отдаёт вступительные взносы игрокам, желающим покинуть турнир
    function leave()
        public
        checkTermination
    {
        // Счётчик числа входов лица, вызвавшего функцию
        int _entriesCounter = entrantEntriesCounter[msg.sender];
        // Размер вступительного взноса
        uint _amount = entryFee;

        // Если до этого функция не откатилась по одному из статусов завершения,
        // то выйти из турнира можно только до истечения времени приёма взносов
        require(
            now < entryEndTime,
            "Time to leave the tournament has passed"
        );
        // Выйти из турнира может только игрок
        require(
            _entriesCounter > 0,
            "You are not in the list of players"
        );

        // Это лицо является игроком, поэтому
        // инвертируем счётчик числа его входов
        _entriesCounter = -_entriesCounter;
        // Сохраняем новое значение счётчика числа входов
        entrantEntriesCounter[msg.sender] = _entriesCounter;
        // Фиксируем, что входной код, ранее введённый данным участником,
        // освободился для повторного ввода
        whoseEntryCode[entrantEntryCode[msg.sender]] = address(0);
        playersCounter--; // Декрементируем счётчик числа игроков
        // Уменьшаем призовой фонд на величину вступительного взноса
        prizeFund -= _amount;
        // Возбуждаем событие выхода из турнира
        emit onLeaving(msg.sender, _entriesCounter);
        msg.sender.transfer(_amount); // Возвращаем взнос участнику
        contractBalance = address(this).balance; // Обновляем баланс контракта
    }

    /// changeEntryEndTime меняет время окончания приёма взносов
    function changeEntryEndTime(uint _newEntryEndTime)
        public
        byOrganizerOnly
        checkTermination
    {
        // Первоначальное время окончания приёма взносов
        uint _oldEntryEndTime = entryEndTime;

        // Если до этого функция не откатилась по одному из статусов завершения,
        // то изменить время приёма взносов можно только до его истечения
        require(
            now < _oldEntryEndTime,
            "Time to change the entry end time has passed"
        );
        // Время окончания приёма взносов можно изменить только один раз
        require(
            !entryEndTimeIsChanged,
            "Entry end time has already been changed"
        );
        // Новое время окончания приёма взносов должно отличаться от нынешнего
        require(
            _newEntryEndTime != _oldEntryEndTime,
            "New entry end time is equal to the current one"
        );
        // Время окончания приёма взносов может быть сдвинуто:
        // или вперёд не более чем на 72 часа,
        // или назад с таким расчётом, чтобы от текущего времени до нового
        // момента окончания приёма взносов был запас не менее 24 часов
        require(
            (_newEntryEndTime > _oldEntryEndTime &&
            _newEntryEndTime <= _oldEntryEndTime + 72 hours) ||
            (_newEntryEndTime < _oldEntryEndTime &&
            _newEntryEndTime >= now + 24 hours),
            "New entry end time is out of allowable limits"
        );

        entryEndTime = _newEntryEndTime;
        entryEndTimeIsChanged = true;
        // Возбуждаем событие изменения времени окончания приёма взносов
        emit onEntryEndTimeChange(_newEntryEndTime);
    }

    /// announceWinner сообщает контракту адрес победителя,
    /// при этом присваивает турниру статус Winner
    function announceWinner(address payable _winner)
        public
        byOrganizerOnly
        checkTermination
    {
        // Победитель может быть объявлен не ранее чем через 24 ч
        // после завершения приёма взносов
        require(
            now >= entryEndTime + 24 hours,
            "The winner is announcing too early"
        );
        // Победитель может быть только из числа игроков
        require(
            entrantEntriesCounter[_winner] > 0,
            "The winner is not in the list of players"
        );

        // Доступный остаток равен балансу контракта, уменьшенному на размер приза.
        // Деление на 100 производится с отбрасыванием дробной части результата
        availableFunds = address(this).balance - prizeFund * winnerShare / 100;
        // Сохраняем адрес победителя и новый статус турнира
        winner = _winner;
        status = statuses.Winner;
        // Возбуждаем событие объявления победителя
        emit onWinnerAnnounce(_winner);
    }

    /// terminate присваивает турниру статус Cancelled или NoWinner
    function terminate(statuses newStatus)
        public
        byOrganizerOnly
        checkTermination
    {
        // Для прекращения турнира посредством функции terminateTournament
        // можно использовать только статусы Cancelled и NoWinner
        require(
            newStatus == statuses.Cancelled ||
            newStatus == statuses.NoWinner,
            "Invalid termination status"
        );
        
        status = newStatus;
        // Возбуждаем событие завершения турнира с новым статусом
        emit onTermination(newStatus);
    }

    /// takePrize выплачивает победителю его долю призового фонда
    function takePrize()
        public
    {
        uint _prize = prizeFund * winnerShare / 100; // Приз победителя.
        // Деление на 100 производится с отбрасыванием дробной части результата

        // Забрать приз можно только при текущем статусе турнира Winner
        require(
            status == statuses.Winner,
            "The winner has not been announced"
        );
        // Забрать приз может только победитель
        require(
            msg.sender == winner,
            "You are not the winner of this tournament"
        );
        // Приз выплачивается только один раз
        require(
            !prizeIsPaid,
            "You have already taken your prize"
        );

        prizeIsPaid = true; // Устанавливаем признак выплаты приза
        // Возбуждаем событие выплаты приза победителю
        emit onPrizePayment(msg.sender, _prize);
        msg.sender.transfer(_prize); // Переводим приз победителю
        contractBalance = address(this).balance; // Обновляем баланс контракта
    }

    /// takeMoneyBack возвращает игрокам взносы, если турнир находится
    /// в одном из статусов LackOfPlayers, Cancelled или NoWinner
    function takeMoneyBack()
        public
    {
        // Счётчик числа входов лица, вызвавшего функцию
        int _entriesCounter = entrantEntriesCounter[msg.sender];
        statuses _status = status; // Текущий статус турнира
        uint _amount = entryFee; // Возвращаемая сумма
        
        // Забрать свои взносы могут только игроки
        require(
            _entriesCounter > 0,
            "You are not a player of this tournament"
        );
        // Забрать свои взносы могут только игроки, не сделавшие этого ранее
        require(
            _entriesCounter % 10 == 0,
            "You have already taken your money"
        );
        // Забрать свой взнос можно, только если турнир находится
        // в одном из статусов LackOfPlayers, Cancelled или NoWinner
        require(
            _status == statuses.LackOfPlayers ||
            _status == statuses.Cancelled ||
            _status == statuses.NoWinner,
            "You can take your money back only if the tournament terminated with no winner"
        );
        // Устанавливаем признак возврата взноса игроку
        _entriesCounter++;
        // Сохраняем новое значение счётчика числа входов
        entrantEntriesCounter[msg.sender] = _entriesCounter;
        // Возбуждаем событие возврата взноса игроку
        emit onMoneyBack(msg.sender);
        msg.sender.transfer(_amount); // Переводим взнос игроку
        contractBalance = address(this).balance; // Обновляем баланс контракта
    }

    /// withdraw устанавливает при соответствующих условиях статус турнира
    /// LackOfPlayers, а также переводит организатору запрашиваемую сумму,
    /// если она > 0 и не превышает остатка, доступного для снятия
    function withdraw(uint amount)
        public
        byOrganizerOnly 
    {
        statuses _status = status; // Текущий статус турнира
        // Остаток средств на счёте контракта, доступный организатору для снятия
        uint _availableFunds = availableFunds;

        // Если время приёма взносов прошло, статус турнира - NotTerminated
        // и при этом число игроков меньше минимального количества игроков
        if (now >= entryEndTime &&
            _status == statuses.NotTerminated &&
            playersCounter < minNumOfPlayers) {
            // Устанавливаем статус LackOfPlayers
            _status = statuses.LackOfPlayers;
            // Сохраняем новый статус турнира
            status = _status;
            // Возбуждаем событие завершения турнира
            emit onTermination(_status);
            return();
        }
        if (amount > 0 && amount <= _availableFunds) {
            // Уменьшаем доступный остаток на переводимую сумму
            _availableFunds -= amount;
            // Возбуждаем событие снятия суммы с баланса турнира организатором
            emit onWithdraw(amount);
            msg.sender.transfer(amount); // Переводим сумму организатору
            contractBalance = address(this).balance; // Обновляем баланс контракта
            availableFunds = _availableFunds; // Обновляем доступный остаток
        }
    }

}
