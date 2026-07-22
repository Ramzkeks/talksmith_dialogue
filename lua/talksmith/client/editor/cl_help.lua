local TS = Talksmith

local PAGES = {
    ru = {
        {
            head = "Что создаёт Talksmith",
            body = {
                { t = "Talksmith Studio создаёт интерактивные разговоры с Actor. Каждый диалог хранит граф реплик, логику, внешний вид и поведение своего Actor." },
                { t = "Узел — реплика Actor. В нём есть один или несколько ответов игрока; каждый ответ завершает разговор либо ведёт в следующий узел." },
                { t = "Порядок выполнения таков: действия входа в узел → показ реплики и доступных ответов → действия выбранного ответа → переход или завершение." },
                { t = "Слева находится библиотека диалогов, в центре — граф, справа — редактор выбранного узла, сверху — сохранение и инструменты, снизу — навигация и диагностика." },
                { t = "Один ID диалога владеет одной конфигурацией и одним размещённым Actor. Повторное размещение этого диалога заменяет прежнего Actor." },
            },
        },
        {
            head = "Библиотека диалогов",
            body = {
                { t = "Нажмите «Создать» и задайте уникальный ID: только a-z, 0-9, _ и -. Новый документ сразу содержит стартовую реплику и один завершающий ответ." },
                { t = "Поиск фильтрует документы по названию и ID. Нажмите строку, чтобы открыть диалог; кнопка обновления заново запрашивает список с сервера." },
                { t = "Нажмите ПКМ по диалогу: открыть, переименовать, дублировать, экспортировать или удалить. Удаление и переименование требуют соответствующего серверного права." },
                { t = "Жёлтая точка у активного диалога означает несохранённые изменения. При попытке открыть другой документ или закрыть Studio появится запрос на их отмену." },
                { t = "Название, автор, время изменения и ревизия хранятся в документе; технический ID используется связями, Actor, импортом и API." },
            },
        },
        {
            head = "Импорт и экспорт",
            body = {
                { t = "Кнопка экспорта у строки диалога получает актуальную сохранённую версию с сервера и записывает JSON в data/talksmith/exports/<id>.json на вашем клиенте." },
                { t = "В окне экспорта можно скопировать полный JSON или серверный Lua-фрагмент размещения Actor. Координаты в Lua-фрагменте нужно заменить своими." },
                { t = "«Импорт пресета» принимает полный JSON. Можно указать новый ID; импорт сбрасывает ревизию, проверяет схему и открывает документ как несохранённый." },
                { t = "Импорт ничего не публикует автоматически: сначала проверьте граф, Actor, условия, действия и интеграции, затем нажмите «Сохранить»." },
                { t = "Неизвестная схема, неверный ID, отсутствующие ссылки и некорректные параметры блокируют импорт или сохранение: импорт показывает причину сразу, а открытый документ — в диагностике." },
            },
        },
        {
            head = "Встроенные пресеты",
            body = {
                { t = "Кнопка «Пресеты» на верхней панели открывает встроенную библиотеку проверенных JSON-примеров. Каталог автоматически показывает только русские или только английские версии — согласно языку интерфейса." },
                { t = "«Стандартные» демонстрируют встроенные условия, действия, флаги, случайность, события и DarkRP. «Интеграционные» посвящены отдельным поддерживаемым дополнениям и показывают их текущее состояние на сервере." },
                { t = "Нажмите «Добавить»: пример появится слева как черновик пресета с жёлтой точкой. Его можно открыть, менять и удалить через ПКМ; он хранится локально до конца текущей игровой сессии." },
                { t = "Черновик не создаёт серверный документ сам по себе. Проверьте зависимости и граф, затем нажмите «Сохранить»: сервер снова проверит схему, интеграции, действия и ваши права, после чего черновик станет обычным диалогом." },
                { t = "Если такой ID уже занят, Talksmith безопасно добавляет числовой суффикс. Можно добавлять один пресет несколько раз и адаптировать копии независимо." },
            },
        },
        {
            head = "Узлы и старт разговора",
            body = {
                { t = "«Узел» на верхней панели добавляет реплику в центр вида. ПКМ по пустому холсту добавляет узел точно в выбранном месте." },
                { t = "Карточка показывает понятное имя, реплику и ответы. Для имени сначала используется авторская заметка, затем текст реплики, затем технический ID узла." },
                { t = "Зелёная метка START отмечает обычную начальную реплику. Назначьте другой старт кнопкой с флагом в инспекторе или через ПКМ по узлу." },
                { t = "Стартовый узел нельзя удалить, пока стартом не назначен другой. При удалении узлов входящие обычные и случайные переходы очищаются безопасно." },
                { t = "Выберите карточку: справа откроются вкладки «Реплика», «Ответы» и «Дополнительно»." },
            },
        },
        {
            head = "Выделение и навигация по холсту",
            body = {
                { t = "ЛКМ выбирает узел. Ctrl+ЛКМ добавляет узлы к выделению, а повторный Ctrl-клик по основному узлу убирает его; рамка по пустому месту выбирает группу, Ctrl+рамка добавляет к ней." },
                { t = "Перетащите любой выбранный узел — вся выделенная группа движется вместе. Привязка и размер сетки настраиваются на странице «Настройки → Редактор»." },
                { t = "Средняя кнопка двигает холст. Колесо масштабирует относительно курсора. Кнопки снизу меняют масштаб и возвращают к стартовому узлу." },
                { t = "F центрирует вид на основном выбранном узле. Ctrl+A выбирает все узлы; ПКМ открывает контекстное меню узла, порта или пустого холста." },
                { t = "Снизу показаны количество узлов и связей, текущий масштаб и счётчики ошибок/предупреждений." },
            },
        },
        {
            head = "Ответы и обычные переходы",
            body = {
                { t = "Во вкладке «Ответы» добавляйте варианты, меняйте их порядок, дублируйте и удаляйте. Нажмите строку ответа, чтобы открыть его текст, маршрут, жест и логику." },
                { t = "У каждого ответа на карточке есть порт. Протяните его ЛКМ к узлу: синий круг и линия означают переход; красный квадрат означает завершение." },
                { t = "Переход можно задать и списком «Куда ведёт ответ». Выбор «завершить диалог» очищает цель." },
                { t = "Если отпустить линию на пустом холсте, меню предложит завершить ответ, создать там новый уже связанный узел или отменить действие." },
                { t = "ПКМ по порту разрывает маршрут. Ответы показываются игроку в заданном порядке; сервер ограничивает их допустимое количество." },
            },
        },
        {
            head = "Случайные начала и переходы",
            body = {
                { t = "В «Actor и сцена → Настройки Actor → Поведение» можно отметить несколько стартовых узлов. При каждом новом разговоре сервер равновероятно выбирает один из них вместо обычного START." },
                { t = "В редакторе ответа включите «Случайный переход» и отметьте возможные узлы. После действий ответа сервер случайно выберет одну существующую цель." },
                { t = "Пока случайный переход включён, обычный список цели недоступен. Если список случайных целей пуст, снова используется обычный переход или завершение." },
                { t = "Случайные старты и цели учитываются при поиске достижимых узлов, удалении, копировании, импорте и проверке документа." },
                { t = "Предпросмотр тоже выбирает случайные начала и маршруты, поэтому пройдите его несколько раз для проверки всех веток." },
            },
        },
        {
            head = "Содержимое узла",
            body = {
                { t = "«Реплика»: основной текст Actor. «Ответы»: список вариантов игрока. «Дополнительно»: оформление узла, медиа и действия при входе." },
                { t = "Цвет и авторская заметка помогают организовать сложный граф и не показываются игроку. Заметка становится заголовком карточки, но не меняет ID." },
                { t = "Жест узла проигрывается при показе реплики; жест ответа — после успешного выполнения действий выбранного ответа. Браузер показывает последовательности модели Actor." },
                { t = "Звук реплики принимает разрешённый локальный путь либо прямую HTTP/HTTPS-ссылку на .mp3. Удалённый .mp3 со всех публичных DNS-хостов разрешён по умолчанию." },
                { t = "Локальные звуки и модели проходят серверные списки разрешений. Недопустимые значения становятся ошибками документа, а не исполняются." },
            },
        },
        {
            head = "Условия видимости",
            body = {
                { t = "Условия задаются у ответа и решают, увидит ли его игрок. Все условия списка должны выполниться; если доступных ответов не осталось, разговор закрывается." },
                { t = "Сервер проверяет условия при показе и повторно при выборе, чтобы устаревшие деньги, предметы или права нельзя было использовать. Случайный шанс сохраняет результат до клика." },
                { t = "Встроенные условия проверяют флаги, наличие/отсутствие оружия, команду, здоровье, случайный шанс и статус администратора." },
                { t = "При наличии DarkRP добавляются профессия, баланс и принадлежность к Civil Protection. Активные интеграции добавляют свои предметы, валюту, погоду, персонажей, уровни, права и Wire-входы." },
                { t = "Раскройте блок «Условия», нажмите «Добавить условие», выберите тип и заполните обязательные поля со звёздочкой. Значок ◆ на карточке отмечает условную ветку." },
            },
        },
        {
            head = "Действия и порядок выполнения",
            body = {
                { t = "Действия узла выполняются по порядку до показа реплики. Действия ответа выполняются по порядку после повторной проверки условий и до жеста, перехода или завершения." },
                { t = "Встроенные действия ставят/снимают флаг, выдают/забирают разрешённое оружие, лечат, дают броню, проигрывают звук, меняют команду, вызывают разрешённое событие, закрывают или открывают другой диалог." },
                { t = "DarkRP добавляет смену профессии, выдачу и списание денег. Интеграции добавляют безопасные операции с инвентарём, валютой, уровнями, персонажами и Wiremod." },
                { t = "Действия могут быть асинхронными; сервер ждёт результат и не начинает следующий шаг раньше времени. Ошибка останавливает цепочку и безопасно закрывает/отклоняет разговор." },
                { t = "Экономические, инвентарные, карьерные, прогрессирующие, событийные, Wire- и опасные действия имеют отдельные права публикации. Значок ● отмечает узел с действиями." },
            },
        },
        {
            head = "Динамические переменные в тексте",
            body = {
                { t = "Активные интеграции могут подставлять данные текущего игрока и мира прямо в реплики Actor и ответы. Разрешение выполняется на сервере отдельно для каждой сессии." },
                { t = "Без аргумента: {stormfox2.weather}, {darkrp_leveling.level}, {advanced_character_creator.name}." },
                { t = "С аргументом после двоеточия: {inventory.item_count:item_healthkit}. Так можно показать количество конкретного предмета." },
                { t = "Доступные переменные зависят от установленных и включённых интеграций: персонаж, профессия, фракция, погода, температура, время, очки, опыт, свободное место и другие." },
                { t = "Неизвестная или временно недоступная переменная остаётся видимым {заполнителем}; локальный предпросмотр тоже не подменяет серверные значения." },
            },
        },
        {
            head = "Интеграции и провайдеры",
            body = {
                { t = "Откройте «Настройки → Интеграции». Ручные интеграции изначально выключены: сначала установите требуемый аддон, затем включите его. Автоматические интеграции, если доступны, переключателя не имеют." },
                { t = "В комплекте: PointShop 1; Finventory; GWS Inventory; Barney Inventory 2.0; DarkRP Leveling; DarkRP Multi Character; Advanced Character Creator; StormFox 2; ULib; ULX; sAdmin; Wiremod." },
                { t = "Универсальные операции Inventory и Currency работают через провайдер. Auto выбирает доступный провайдер, но при нескольких подходящих провайдерах редактор требует явный выбор." },
                { t = "Выключенная или отсутствующая интеграция не удаляет сохранённые ссылки из диалога: они помечаются недоступными и снова оживают после восстановления интеграции." },
                { t = "Страница показывает статус, категории, количество действий, условий, переменных и провайдеров. Менять состояние может только группа с правом управления интеграциями." },
            },
        },
        {
            head = "Инвентарь, валюта и прогресс",
            body = {
                { t = "Универсальный Inventory проверяет предмет/свободное место, выдаёт и забирает количество предметов, открывает инвентарь и подставляет число предметов. Currency проверяет баланс, добавляет и списывает валюту." },
                { t = "PointShop 1: очки, владение и экипировка предмета, выдача/изъятие предметов и открытие магазина; в тексте доступно текущее число очков." },
                { t = "Finventory: наличие предмета, вместимость, политика запрещённых предметов и заполненность; выдача, изъятие и открытие инвентаря." },
                { t = "GWS Inventory: предметы, свободное место, разрешения, оружие и боеприпасы; Barney Inventory 2.0: предметы, свободный вес, разрешения и боеприпасы." },
                { t = "Обе интеграции умеют безопасно выдавать/забирать поддерживаемые предметы и боеприпасы и открывать свой инвентарь; GWS также управляет оружием." },
                { t = "DarkRP Leveling: минимальный/максимальный уровень, опыт и возможность повышения; добавление/списание XP, добавление/установка уровней и переменные level, xp, max_xp." },
            },
        },
        {
            head = "Персонажи, мир и администрирование",
            body = {
                { t = "DarkRP Multi Character проверяет наличие выбранного персонажа, его имя, индекс и профессию. Если у нескольких записей одинаковое имя, проверка индекса безопасно возвращает false." },
                { t = "Advanced Character Creator проверяет активного персонажа, имя, ID, профессию и фракцию и предоставляет переменные имени, фамилии, ID, профессии и фракции. Смена/удаление персонажа закрывает активный разговор." },
                { t = "StormFox 2 проверяет день, ночь, дождь, снег, туман, тип погоды и границы температуры; переменные отдают погоду, температуру, время и интенсивность." },
                { t = "ULib проверяет UCL-доступ и группу; ULX — доступ к команде и право редактировать Talksmith; sAdmin — право, группу и доступ к Studio." },
                { t = "ULX, sAdmin и CAMI-совместимые админ-моды могут стать серверной системой прав Talksmith. Ultimate Logs не является логикой диалога: он только включает защищённый журнал на странице «Сервер»." },
            },
        },
        {
            head = "Wiremod",
            body = {
                { t = "Включённая интеграция Wiremod добавляет Actor входы Enabled, Locked, ForceClose и ExternalValue1–8." },
                { t = "Выходы Actor: Busy, Player, DialogueStarted, NodeChanged, OptionChosen, DialogueEnded и CustomOutput1–8." },
                { t = "DialogueStarted и DialogueEnded — однокадровые импульсы; NodeChanged передаёт ID узла, OptionChosen — номер видимого ответа." },
                { t = "Условия Wiremod сравнивают и проверяют внешние входы. Действия устанавливают/импульсно меняют выход, отправляют строку или передают выбранный ответ." },
                { t = "Настройка и публикация Wire-действий защищены отдельным правом. Отключение интеграции убирает Wire-интерфейс с Actor безопасно." },
            },
        },
        {
            head = "Имя и внешний вид Actor",
            body = {
                { t = "Откройте «Actor и сцена → Настройки Actor». Вкладка «Основное» задаёт имя, подзаголовок и модель; модель можно выбрать в браузере или скопировать с объекта под прицелом." },
                { t = "Вкладка «Внешность» настраивает скин, высоту подписи и доступные bodygroup модели. Интерактивный просмотр вращается ЛКМ, приближается колесом и сбрасывается двойным кликом." },
                { t = "Здесь же задаются одна idle-анимация либо список случайных idle-анимаций и визуальная тема игрового диалога." },
                { t = "Выбор модели перестраивает допустимые скины, части и анимации. Сервер дополнительно проверяет модель по allowed_models." },
                { t = "После сохранения документа его имя, модель, тема, анимации и внешний вид автоматически применяются к уже размещённому Actor, если у него нет явного Lua-переопределения модели." },
            },
        },
        {
            head = "Поведение Actor и подача диалога",
            body = {
                { t = "Во вкладке «Поведение» выбираются случайные стартовые узлы, режим «один собеседник за раз» и дистанция разговора от 64 до 512 единиц." },
                { t = "При включённом ограничении занятый Actor показывает статус busy и не принимает второго игрока. Без него один Actor может вести независимые сессии с несколькими игроками." },
                { t = "Глобальная страница «Настройки → Диалоги» меняет скорость печати текста для всех тем и независимо управляет именем, описанием и подсказкой [E] над доступными Actor." },
                { t = "Тема, имя, подзаголовок и дистанция принадлежат конкретному диалогу; скорость текста и видимость элементов над Actor — серверные настройки всего аддона." },
                { t = "Сервер также требует допустимую дистанцию и прямую видимость при начале и на протяжении разговора." },
            },
        },
        {
            head = "Размещение и сцена",
            body = {
                { t = "«Разместить Actor перед собой» создаёт Actor выбранного диалога. Для одного ID существует только один Actor, поэтому новое размещение атомарно заменяет прежнее." },
                { t = "«Обновить Actor под прицелом» привязывает выбранный диалог и его настройки к существующему Talksmith Actor." },
                { t = "«Копировать позицию и модель под прицелом» создаёт Actor на месте подходящей сущности; «Удалить Actor под прицелом» удаляет Talksmith Actor." },
                { t = "Actor можно двигать физганом при наличии права; после отпускания он снова фиксируется. Гравипушка и урон для Actor заблокированы." },
                { t = "«Сохранить/загрузить расстановку» работает с картой отдельно. Автосохранение размещений настраивается глобально; Lua-размещения живут отдельно и не дублируются в файле карты." },
            },
        },
        {
            head = "Предпросмотр и диагностика",
            body = {
                { t = "«Предпросмотр» запускает текущий несохранённый граф в настоящем интерфейсе диалога и учитывает тему, случайные старты/переходы и порядок ответов." },
                { t = "Предпросмотр безопасен: действия становятся уведомлениями и не выполняются, серверные условия не фильтруют ответы, а ответы с условиями отмечаются флагом." },
                { t = "Динамические серверные переменные в предпросмотре не разрешаются. Проверяйте условия, переменные, удалённые зависимости и реальные действия на тестовом Actor." },
                { t = "Счётчик снизу открывает список проблем. Нажатие проблемы узла центрирует его; красные ошибки блокируют предпросмотр и сохранение, жёлтые предупреждения, например недостижимый узел, не блокируют." },
                { t = "Проверка охватывает структуру, цели, старт, разрешённые медиа/модели, параметры, лимиты, бюджет действий, интеграции и достижимость." },
            },
        },
        {
            head = "Сохранение, ревизии и резервные копии",
            body = {
                { t = "«Сохранить» или Ctrl+S проверяет документ и публикует новую серверную ревизию. Успешное сохранение убирает жёлтую точку и обновляет связанного Actor." },
                { t = "Если другой администратор уже сохранил новую ревизию, выберите: загрузить его версию или сохранить свою работу под новым ID как копию." },
                { t = "На странице «Настройки → Сервер» задаётся число предыдущих версий каждого диалога; 0 отключает резервные копии." },
                { t = "Там же раздел «Разрешённое оружие» управляет классами для выдачи и изъятия. Изменённый вручную Lua-список имеет приоритет и становится доступным только для просмотра." },
                { t = "Там же включается автосохранение Actor и, при установленном Ultimate Logs, уровень серверного журнала Talksmith: выключен, только ошибки или ошибки и события." },
                { t = "Отмена/возврат хранит до 100 снимков текущей сессии Studio. Серверные резервные копии и Ctrl+Z — разные механизмы." },
            },
        },
        {
            head = "Настройки Talksmith",
            body = {
                { t = "«Редактор»: размер сетки, привязка узлов, подтверждение удаления и язык. Эти параметры сохраняются только на текущем клиенте." },
                { t = "«Диалоги»: глобальная скорость печати с живым примером и отдельные переключатели имени, описания и подсказки взаимодействия над Actor. Нужны серверные права на настройки." },
                { t = "«Сервер»: автосохранение Actor, количество резервных копий и Ultimate Logs. Недоступные функции остаются заблокированными с объяснением." },
                { t = "«Права»: индивидуальные Talksmith-superadmin и минимальные группы для операций. Страница появляется при поддерживаемой административной системе." },
                { t = "Индивидуальный список и остальные серверные параметры сохраняются в data/talksmith/settings.json." },
                { t = "«Интеграции»: серверный каталог дополнений и их состояние. Пользователь без права изменения может просматривать доступные возможности в режиме чтения." },
            },
        },
        {
            head = "Права и безопасная публикация",
            body = {
                { t = "Talksmith разделяет права на открытие Studio, создание, редактирование, удаление, публикацию, управление Actor, настройками, интеграциями и диагностикой." },
                { t = "Отдельно назначаются права на опасные, экономические, инвентарные, прогрессирующие, карьерные, событийные и Wire-действия." },
                { t = "При ULX, sAdmin или CAMI-совместимом админ-моде superadmin выбирает минимальную группу; наследование проверяется сервером при каждой чувствительной операции." },
                { t = "Индивидуальные Talksmith-superadmin получают все права аддона параллельно с группами, но их настоящая группа и права вне Talksmith не меняются." },
                { t = "Без административной системы групповые настройки недоступны; native superadmin и индивидуальный список продолжают работать." },
                { t = "Клиент выбирает только уже проверенный видимый ответ: условия, суммы, ID действий, лимиты, белые списки и права всегда проверяет сервер." },
            },
        },
        {
            head = "Как разговор работает для игрока",
            body = {
                { t = "Подойдите к доступному Actor в пределах его дистанции и прямой видимости и нажмите E. Над Actor могут отображаться его имя, описание и подсказка [E]." },
                { t = "Сервер выполняет действия входа, фильтрует ответы условиями и подставляет переменные. Игрок выбирает ответ мышью либо клавишами 1–6; длинный список прокручивается колесом." },
                { t = "После выбора сервер снова проверяет условия, выполняет действия, жест и переход. Завершающий ответ, действие Close dialogue или Esc закрывают окно." },
                { t = "Действие Open dialogue безопасно переключает сессию на другой существующий документ. Условия и флаги позволяют строить покупки и необратимые ветки." },
                { t = "Разговор также закрывается при потере дистанции/видимости, отсутствии доступных ответов, изменении документа, бездействии или превышении длительности сессии." },
            },
        },
        {
            head = "Горячие клавиши",
            body = {
                { t = "Сочетания работают, когда фокус находится на холсте. Контекстные меню дублируют основные команды мышью." },
                { t = "Ctrl+S — сохранить      Ctrl+Z / Ctrl+Y — отменить / вернуть", key = true },
                { t = "Ctrl+C / Ctrl+V / Ctrl+D — копировать / вставить / дублировать узлы", key = true },
                { t = "Del — удалить      Ctrl+A — выбрать всё      Ctrl+ЛКМ — изменить выделение", key = true },
                { t = "F — центрировать выбранное      Колесо — масштаб      СКМ — двигать холст", key = true },
                { t = "В обучении: ← / → или Space — страницы. В разговоре: 1–6 — ответ, Esc — выйти.", key = true },
            },
        },
        {
            head = "Попробуйте прямо сейчас",
            body = {
                { t = "Добавьте готовый русскоязычный пример «Оружейная и allowlist» в библиотеку диалогов одним нажатием." },
                { t = "Пример появится слева с жёлтой меткой «Черновик пресета». Он не сохраняется и не публикуется автоматически: откройте его, изучите граф и нажмите «Сохранить», когда будете готовы." },
                { t = "В новой кнопке «Пресеты» между «Настройки» и «Обучение» находится полный каталог стандартных и интеграционных примеров на выбранном языке интерфейса." },
            },
            action = { label = "Опробовать диалог" },
        },
    },
    en = {
        {
            head = "What Talksmith builds",
            body = {
                { t = "Talksmith Studio builds interactive conversations with Actors. Each dialogue stores a line graph, logic, appearance, and behaviour for its Actor." },
                { t = "A node is one Actor line. It contains one or more player responses; each response ends the conversation or leads to another node." },
                { t = "Execution order is: node-entry actions → line and available responses → selected-response actions → transition or finish." },
                { t = "The library is on the left, graph in the centre, selected-node editor on the right, save and tools at the top, navigation and diagnostics at the bottom." },
                { t = "One dialogue ID owns one configuration and one placed Actor. Placing the same dialogue again replaces its previous Actor." },
            },
        },
        {
            head = "Dialogue library",
            body = {
                { t = 'Press "New" and enter a unique ID using only a-z, 0-9, _ and -. A new document contains a start line and one final response.' },
                { t = "Search filters documents by title and ID. Click a row to open it; Refresh requests the latest list from the server." },
                { t = "Right-click a dialogue to open, rename, duplicate, export, or delete it. Rename and delete require the matching server privilege." },
                { t = "A yellow dot beside the active dialogue means there are unsaved changes. Opening another document or closing Studio asks before discarding them." },
                { t = "Title, author, modified time, and revision live in the document; the technical ID is used by links, Actors, imports, and the API." },
            },
        },
        {
            head = "Import and export",
            body = {
                { t = "The export button on a dialogue row fetches the current saved server version and writes JSON to data/talksmith/exports/<id>.json on your client." },
                { t = "The export window can copy the complete JSON or a server-side Lua Actor spawn snippet. Replace the coordinates in the Lua snippet with your own." },
                { t = '"Import preset" accepts complete JSON. You may override its ID; import resets the revision, validates the schema, and opens it as unsaved.' },
                { t = 'Import never publishes automatically: review the graph, Actor, conditions, actions, and integrations, then press "Save".' },
                { t = "An unknown schema, invalid ID, missing reference, or invalid parameter blocks import or saving: import reports it immediately, and an open document shows it in diagnostics." },
            },
        },
        {
            head = "Built-in presets",
            body = {
                { t = 'The "Presets" button on the top bar opens a bundled library of validated JSON examples. The catalog automatically shows only Russian or only English versions, following the interface language.' },
                { t = '"Standard" demonstrates built-in conditions, actions, flags, randomness, events, and DarkRP. "Integrations" targets individual supported addons and shows their current server status.' },
                { t = 'Press "Add" and the example appears on the left as a preset draft with a yellow dot. You may open, edit, or remove it from the right-click menu; it stays local for the current game session.' },
                { t = 'A draft does not create a server document by itself. Review its dependencies and graph, then press "Save": the server revalidates the schema, integrations, actions, and your permissions before it becomes a regular dialogue.' },
                { t = "If its ID is already in use, Talksmith safely adds a numeric suffix. You can add the same preset more than once and adapt each copy independently." },
            },
        },
        {
            head = "Nodes and conversation start",
            body = {
                { t = '"Node" on the top bar adds a line at the centre of the view. Right-click empty canvas space to add one at that exact position.' },
                { t = "A card shows a friendly name, Actor line, and responses. Its name uses the author note first, then the line text, then the technical node ID." },
                { t = "The green START chip marks the normal opening line. Assign another start with the flag button in the inspector or by right-clicking a node." },
                { t = "The start node cannot be deleted until another node becomes the start. Deleting nodes safely clears incoming normal and random transitions." },
                { t = 'Select a card to open the "Line", "Responses", and "More" tabs on the right.' },
            },
        },
        {
            head = "Canvas selection and navigation",
            body = {
                { t = "LMB selects a node. Ctrl+LMB adds nodes, and Ctrl-clicking the primary node again removes it; an empty-space box selects a group, while Ctrl+box adds to it." },
                { t = 'Drag any selected node to move the entire selection. Grid size and snapping are configured under "Settings → Editor".' },
                { t = "Middle mouse pans. The wheel zooms around the pointer. Bottom controls change zoom and return to the start node." },
                { t = "F centres the primary selected node. Ctrl+A selects every node; RMB opens the context menu for a node, port, or empty canvas." },
                { t = "The status bar shows node and link totals, current zoom, and error/warning counts." },
            },
        },
        {
            head = "Responses and normal transitions",
            body = {
                { t = 'Use the "Responses" tab to add, reorder, duplicate, and delete choices. Click a response row to edit its text, route, gesture, and logic.' },
                { t = "Each response has a port on its card. Drag it with LMB to a node: a blue circle and line mean a transition; a red square means the response is final." },
                { t = 'You can also choose a destination from "Where this response goes". Selecting "end dialogue" clears the target.' },
                { t = "Drop a connection on empty space to choose between ending it, creating a new connected node there, or cancelling." },
                { t = "Right-click a port to break its route. Responses appear to players in their stored order; the server enforces their allowed count." },
            },
        },
        {
            head = "Random starts and transitions",
            body = {
                { t = 'Under "Actor & scene → Actor settings → Behaviour", select multiple start nodes. The server picks one uniformly for each new conversation instead of normal START.' },
                { t = 'Enable "Random transition" while editing a response and tick its possible nodes. After response actions, the server randomly chooses one existing target.' },
                { t = "The normal target list is disabled while random routing is active. If the random target list becomes empty, the normal target or final state is used again." },
                { t = "Random starts and targets are included in reachability checks, deletion, copying, importing, and document validation." },
                { t = "Preview also chooses random starts and routes, so run it several times to inspect every branch." },
            },
        },
        {
            head = "Node content",
            body = {
                { t = '"Line" is the Actor text. "Responses" is the player-choice list. "More" contains node presentation, media, and on-enter actions.' },
                { t = "Colour and author note organise a complex graph and are not shown to players. The note becomes the card title but never changes the node ID." },
                { t = "A node gesture plays when its line is shown; a response gesture plays after that response's actions succeed. The browser lists sequences for the Actor model." },
                { t = "Line sound accepts an allowed local path or a direct HTTP/HTTPS .mp3 URL. Remote .mp3 files from all public DNS hosts are allowed by default." },
                { t = "Local sounds and models pass server allowlists. Disallowed values become document errors instead of being executed." },
            },
        },
        {
            head = "Visibility conditions",
            body = {
                { t = "Conditions belong to a response and decide whether a player sees it. Every condition in its list must pass; the conversation closes if no response remains." },
                { t = "The server checks conditions when showing responses and again on selection, preventing stale money, items, or permissions from being reused. Random chance keeps its result until click." },
                { t = "Core conditions check flags, weapon possession/absence, team, health, random chance, and administrator status." },
                { t = "DarkRP adds job, balance, and Civil Protection checks. Active integrations add items, currency, weather, characters, levels, access rights, and Wire inputs." },
                { t = 'Expand "Conditions", press "Add condition", choose a type, and fill fields marked with *. A ◆ badge on the card marks a conditional branch.' },
            },
        },
        {
            head = "Actions and execution order",
            body = {
                { t = "Node actions run in list order before its line appears. Response actions run in list order after conditions are rechecked and before its gesture, route, or finish." },
                { t = "Core actions set/clear flags, give/take allowed weapons, heal, give armour, play sound, change team, emit an allowed event, close, or open another dialogue." },
                { t = "DarkRP adds job changes and money grants/deductions. Integrations add safe inventory, currency, progression, character, and Wiremod operations." },
                { t = "Actions may be asynchronous; the server waits for completion before the next step. A failure stops the chain and safely closes or rejects the conversation." },
                { t = "Economy, inventory, jobs, progression, events, Wire, and dangerous actions have separate publishing privileges. A ● badge marks a node containing actions." },
            },
        },
        {
            head = "Dynamic text variables",
            body = {
                { t = "Active integrations can insert current player and world data into Actor lines and response text. Resolution happens on the server for each session." },
                { t = "Without an argument: {stormfox2.weather}, {darkrp_leveling.level}, {advanced_character_creator.name}." },
                { t = "With an argument after a colon: {inventory.item_count:item_healthkit}. This can display the count for one specific item." },
                { t = "Available variables follow installed and enabled integrations: character, job, faction, weather, temperature, time, points, XP, free capacity, and more." },
                { t = "An unknown or temporarily unavailable variable stays visible as a {placeholder}; local Preview does not replace server values either." },
            },
        },
        {
            head = "Integrations and providers",
            body = {
                { t = 'Open "Settings → Integrations". Manual integrations start disabled: install the required addon, then enable it. Automatic integrations, when present, have no switch.' },
                { t = "Bundled support: PointShop 1; Finventory; GWS Inventory; Barney Inventory 2.0; DarkRP Leveling; DarkRP Multi Character; Advanced Character Creator; StormFox 2; ULib; ULX; sAdmin; Wiremod." },
                { t = "Generic Inventory and Currency operations use a provider. Auto selects an available provider, but the editor requires an explicit choice when several providers qualify." },
                { t = "Disabling or losing an integration does not erase its saved dialogue references: they are marked unavailable and become live again when the integration returns." },
                { t = "The page shows status, category, and action, condition, variable, and provider counts. Only a group with integration-management permission can change state." },
            },
        },
        {
            head = "Inventory, currency, and progression",
            body = {
                { t = "Generic Inventory checks an item/free space, gives or takes item amounts, opens inventory, and inserts item count. Currency checks balance and adds or takes currency." },
                { t = "PointShop 1: points, item ownership/equipment, item grants/removal, and opening the shop; current points are available as a text variable." },
                { t = "Finventory: item ownership, capacity, illegal-item policy, and full state; giving, taking, and opening its inventory." },
                { t = "GWS Inventory: items, free space, policy, weapons, and ammo; Barney Inventory 2.0: items, free weight, policy, and ammo." },
                { t = "Both safely give/take supported items and ammo and open their inventory; GWS also manages weapons." },
                { t = "DarkRP Leveling: minimum/maximum level, XP, and ability to level; add/take XP, add/set levels, plus level, xp, and max_xp variables." },
            },
        },
        {
            head = "Characters, world, and administration",
            body = {
                { t = "DarkRP Multi Character checks that a character is selected, then its name, index, and job. If several records share the same name, the index check safely returns false." },
                { t = "Advanced Character Creator checks active character, name, ID, job, and faction and supplies name, surname, ID, job, and faction variables. Switching/removing the character closes an active conversation." },
                { t = "StormFox 2 checks day, night, rain, snow, fog, weather type, and temperature ranges; variables return weather, temperature, time, and intensity." },
                { t = "ULib checks UCL access and group; ULX checks command access and Talksmith editing; sAdmin checks permission, group, and Studio access." },
                { t = 'ULX, sAdmin, and CAMI-compatible admin mods can back Talksmith server permissions. Ultimate Logs is not dialogue logic; it only enables protected logging on the "Server" page.' },
            },
        },
        {
            head = "Wiremod",
            body = {
                { t = "The enabled Wiremod integration adds Actor inputs Enabled, Locked, ForceClose, and ExternalValue1–8." },
                { t = "Actor outputs are Busy, Player, DialogueStarted, NodeChanged, OptionChosen, DialogueEnded, and CustomOutput1–8." },
                { t = "DialogueStarted and DialogueEnded are one-tick pulses; NodeChanged carries the node ID, and OptionChosen carries the visible response number." },
                { t = "Wiremod conditions compare and test external inputs. Actions set or pulse an output, send a string, or pass the selected response." },
                { t = "Configuring and publishing Wire actions has its own privilege. Disabling the integration safely removes the Wire interface from Actors." },
            },
        },
        {
            head = "Actor identity and appearance",
            body = {
                { t = 'Open "Actor & scene → Actor settings". "General" sets name, subtitle, and model; choose a model in the browser or copy one from the aimed entity.' },
                { t = '"Appearance" controls skin, name height, and available model bodygroups. Rotate the preview with LMB, zoom with the wheel, and double-click to reset.' },
                { t = "The same page sets one idle sequence or a pool of random idle sequences, plus the in-game dialogue theme." },
                { t = "Changing model rebuilds valid skins, parts, and animations. The server additionally checks it against allowed_models." },
                { t = "Saving automatically applies name, model, theme, animations, and appearance to the placed Actor unless its model has an explicit Lua override." },
            },
        },
        {
            head = "Actor behaviour and presentation",
            body = {
                { t = 'The "Behaviour" tab configures random start nodes, "one talker at a time", and conversation distance from 64 to 512 units.' },
                { t = "With the limit enabled, a busy Actor displays busy and refuses a second player. Without it, one Actor can host independent sessions for multiple players." },
                { t = 'The global "Settings → Dialogues" page changes typing speed for every theme and independently controls the Actor name, description, and [E] prompt.' },
                { t = "Theme, name, subtitle, and distance belong to one dialogue; typing speed and overhead-element visibility are server-wide settings." },
                { t = "The server also requires valid distance and direct line of sight when starting and throughout a conversation." },
            },
        },
        {
            head = "Placement and scene",
            body = {
                { t = '"Place Actor in front of you" spawns the selected dialogue. Only one Actor can own an ID, so a new placement atomically replaces the old one.' },
                { t = '"Update aimed Actor" binds the selected dialogue and its settings to an existing Talksmith Actor.' },
                { t = '"Copy aimed position and model" creates an Actor at a suitable entity; "Remove aimed Actor" removes a Talksmith Actor.' },
                { t = "Users with permission can move an Actor with the physgun; it freezes again on drop. Gravgun pickup and damage are blocked." },
                { t = '"Save/Load layout" is per map. Global settings control placement autosave; Lua-configured spawns remain separate and are not duplicated into the map file.' },
            },
        },
        {
            head = "Preview and diagnostics",
            body = {
                { t = '"Preview" runs the current unsaved graph in the real dialogue UI and honours theme, random starts/routes, and response order.' },
                { t = "Preview is safe: actions become notifications and do not execute, server conditions do not filter responses, and conditional responses receive a flag." },
                { t = "Dynamic server variables are not resolved in Preview. Test conditions, variables, remote dependencies, and real actions on a test Actor." },
                { t = "The bottom counter opens Problems. Clicking a node problem centres it; red errors block Preview and Save, while yellow warnings such as an unreachable node do not." },
                { t = "Validation covers structure, targets, start, allowed media/models, parameters, limits, action budget, integrations, and reachability." },
            },
        },
        {
            head = "Saving, revisions, and backups",
            body = {
                { t = '"Save" or Ctrl+S validates and publishes a new server revision. Success clears the yellow dot and refreshes the linked Actor.' },
                { t = "If another administrator has already saved a newer revision, choose to load their version or preserve yours under a new ID as a copy." },
                { t = '"Settings → Server" controls how many older versions are kept for each dialogue; 0 disables backups.' },
                { t = "\"Settings → Server → Allowed weapons\" manages classes used by give and take actions. A manually changed Lua list takes priority and becomes read-only in the menu." },
                { t = "The same page controls Actor autosave and, with Ultimate Logs installed, Talksmith logging: off, errors only, or errors and events." },
                { t = "Undo/redo stores up to 100 snapshots for the current Studio session. Server backups and Ctrl+Z are separate systems." },
            },
        },
        {
            head = "Talksmith settings",
            body = {
                { t = '"Editor": grid size, node snapping, delete confirmation, and language. These settings are stored only on the current client.' },
                { t = '"Dialogues": global typing speed with a live sample and separate Actor name, description, and interaction-prompt switches. Server-settings permission is required.' },
                { t = '"Server": Actor autosave, backup count, and Ultimate Logs. Unavailable features remain locked with an explanation.' },
                { t = '"Permissions": individual Talksmith superadmins and minimum groups for operations. This page appears with a supported administration system.' },
                { t = "The individual list and other server settings are stored in data/talksmith/settings.json." },
                { t = '"Integrations": server addon catalog and status. Users without change permission may still inspect available capabilities in read-only mode.' },
            },
        },
        {
            head = "Permissions and safe publishing",
            body = {
                { t = "Talksmith separates privileges for opening Studio, creating, editing, deleting, publishing, Actor management, settings, integrations, and diagnostics." },
                { t = "Dangerous, economy, inventory, progression, job, event, and Wire actions each have an additional publishing privilege." },
                { t = "With ULX, sAdmin, or a CAMI-compatible admin mod, a superadmin chooses minimum groups; inheritance is evaluated on the server for every sensitive operation." },
                { t = "Individual Talksmith superadmins receive every addon permission alongside groups, without changing their real group or permissions outside Talksmith." },
                { t = "Without an administration system, group settings are unavailable; native superadmins and the individual list continue to work." },
                { t = "The client selects only a validated visible response: conditions, amounts, action IDs, budgets, allowlists, and privileges are always enforced by the server." },
            },
        },
        {
            head = "The player conversation",
            body = {
                { t = "Approach an available Actor within its distance and line of sight and press E. Its name, description, and [E] prompt can appear overhead." },
                { t = "The server runs entry actions, filters responses, and resolves variables. Choose with the mouse or keys 1–6; scroll long content with the wheel." },
                { t = "After selection, the server rechecks conditions, then runs actions, gesture, and route. A final response, Close dialogue action, or Esc closes the window." },
                { t = "Open dialogue safely switches the session to another existing document. Conditions and flags support purchases and persistent branches." },
                { t = "A conversation also closes on lost distance/sight, no available responses, document change, idle timeout, or maximum session duration." },
            },
        },
        {
            head = "Keyboard reference",
            body = {
                { t = "Canvas shortcuts work while the canvas has focus. Context menus provide the same core operations with the mouse." },
                { t = "Ctrl+S — save      Ctrl+Z / Ctrl+Y — undo / redo", key = true },
                { t = "Ctrl+C / Ctrl+V / Ctrl+D — copy / paste / duplicate nodes", key = true },
                { t = "Del — delete      Ctrl+A — select all      Ctrl+LMB — modify selection", key = true },
                { t = "F — centre selection      Wheel — zoom      MMB — pan canvas", key = true },
                { t = "Tutorial: ← / → or Space — pages. Conversation: 1–6 — response, Esc — leave.", key = true },
            },
        },
        {
            head = "Try it right now",
            body = {
                { t = 'Add the ready-made English "Armory and allowlist" example to your dialogue library with one click.' },
                { t = 'It appears on the left with a yellow "Preset draft" marker. Nothing is saved or published automatically: open it, explore the graph, and press "Save" when you are ready.' },
                { t = 'The new "Presets" button between "Settings" and "Tutorial" contains the complete catalog of standard and integration examples in your selected interface language.' },
            },
            action = { label = "Try this dialogue" },
        },
    },
}

local function pages()
    return PAGES[TS.Config.language] or PAGES.en
end

local CATEGORIES = {
    ru = {
        { title = "Знакомство", first = 1, last = 4 },
        { title = "Редактор диалогов", first = 5, last = 12 },
        { title = "Интеграции", first = 13, last = 16 },
        { title = "Actor и сцена", first = 17, last = 19 },
        { title = "Проверка и публикация", first = 20, last = 23 },
        { title = "Игра и справка", first = 24, last = 26 },
    },
    en = {
        { title = "Getting started", first = 1, last = 4 },
        { title = "Dialogue editor", first = 5, last = 12 },
        { title = "Integrations", first = 13, last = 16 },
        { title = "Actor and scene", first = 17, last = 19 },
        { title = "Testing and publishing", first = 20, last = 23 },
        { title = "Player and reference", first = 24, last = 26 },
    },
}

local function categories()
    return CATEGORIES[TS.Config.language] or CATEGORIES.en
end

local function fitNavigationText(text, font, maxWidth)
    text = tostring(text or "")
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then
        return text
    end

    local suffix = "…"
    local count = utf8 and utf8.len and utf8.len(text) or #text
    if not count then
        return text
    end
    for last = count, 1, -1 do
        local value = utf8 and utf8.sub and utf8.sub(text, 1, last) or string.sub(text, 1, last)
        if surface.GetTextSize(value .. suffix) <= maxWidth then
            return value .. suffix
        end
    end
    return suffix
end

function TS.Editor.OpenHelp()
    if IsValid(TS.Editor.HelpFrame) then
        TS.Editor.HelpFrame:MakePopup()
        return
    end
    local T = TS.Editor.Theme
    local list = pages()
    local page = 1
    local showPage

    local scr = vgui.Create("EditablePanel")
    TS.Editor.HelpFrame = scr
    TS.Editor.HelpOpen = true
    scr:SetSize(ScrW(), ScrH())
    scr:SetPos(0, 0)
    scr:MakePopup()
    scr.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 170)
        surface.DrawRect(0, 0, w, h)
    end

    local cw = math.min(math.Clamp(ScrW() * 0.82, 760, 1200), math.max(ScrW() - 24, 320))
    local ch = math.min(math.Clamp(ScrH() * 0.78, 520, 800), math.max(ScrH() - 24, 320))
    local card = scr:Add("DPanel")
    card:SetSize(cw, ch)
    card:Center()
    card.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, T.bar)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = card:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(56)
    header:DockPadding(24, 0, 12, 0)
    header.Paint = function(_, w, h)
        draw.SimpleText(TS.L("help_title"), "Talksmith_E_HelpTitle", 24, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, h - 1, w, h - 1)
    end
    local x = header:Add("DButton")
    x:Dock(RIGHT)
    x:SetWide(40)
    x:DockMargin(0, 10, 0, 10)
    TS.Editor.StyleButton(x, { label = "✕" })
    x.DoClick = function()
        scr:Remove()
    end

    local footer = card:Add("DPanel")
    footer:Dock(BOTTOM)
    footer:SetTall(58)
    footer:DockPadding(24, 12, 24, 12)
    footer.Paint = function(_, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, 0, w, 0)
        draw.SimpleText(
            string.format("%02d / %02d", page, #list),
            "Talksmith_E_Mono",
            w / 2,
            h / 2,
            T.muted,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    local main = card:Add("DPanel")
    main:Dock(FILL)
    main.Paint = function() end

    local navigation = main:Add("DPanel")
    navigation:Dock(LEFT)
    navigation:SetWide(math.Clamp(cw * 0.27, 190, 292))
    navigation.Paint = function(_, w, h)
        surface.SetDrawColor(T.side)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(w - 1, 0, w - 1, h)
    end

    local navScroll = navigation:Add("DScrollPanel")
    navScroll:Dock(FILL)
    navScroll:DockMargin(12, 12, 8, 12)
    local navBar = navScroll:GetVBar()
    navBar:SetWide(3)
    navBar:SetHideButtons(true)
    navBar.Paint = function() end
    navBar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end

    local body = main:Add("DScrollPanel")
    body:Dock(FILL)
    body:DockMargin(24, 16, 18, 12)
    local vb = body:GetVBar()
    vb:SetWide(4)
    vb:SetHideButtons(true)
    vb.Paint = function() end
    vb.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end

    local navButtons = {}
    for categoryIndex, category in ipairs(categories()) do
        local categoryLabel = navScroll:Add("DLabel")
        categoryLabel:Dock(TOP)
        categoryLabel:DockMargin(8, categoryIndex > 1 and 14 or 0, 8, 5)
        categoryLabel:SetTall(20)
        categoryLabel:SetFont("Talksmith_E_Tiny")
        categoryLabel:SetTextColor(T.dim)
        categoryLabel:SetText(category.title)

        for index = category.first, math.min(category.last, #list) do
            local pageIndex = index
            local button = navScroll:Add("DButton")
            navButtons[pageIndex] = button
            button:Dock(TOP)
            button:DockMargin(0, 0, 4, 3)
            button:SetTall(34)
            button:SetText("")
            button.Paint = function(s, w, h)
                local active = page == pageIndex
                if active or s:IsHovered() then
                    draw.RoundedBox(4, 0, 0, w, h, active and T.accentSoft or T.hover)
                end
                if active then
                    surface.SetDrawColor(T.blue)
                    surface.DrawRect(0, 5, 2, h - 10)
                end
                draw.SimpleText(
                    string.format("%02d", pageIndex),
                    "Talksmith_E_Mono",
                    10,
                    h / 2,
                    active and T.blue or T.dim,
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
                draw.SimpleText(
                    fitNavigationText(list[pageIndex].head, "Talksmith_E_Small", math.max(w - 52, 20)),
                    "Talksmith_E_Small",
                    42,
                    h / 2,
                    active and T.text or T.muted,
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
            end
            button.DoClick = function()
                showPage(pageIndex)
            end
        end
    end

    local prev = footer:Add("DButton")
    prev:Dock(LEFT)
    prev:SetWide(120)
    TS.Editor.StyleButton(prev, { label = TS.L("help_prev"), icon = "caret-left" })

    local nextb = footer:Add("DButton")
    nextb:Dock(RIGHT)
    nextb:SetWide(140)
    TS.Editor.StyleButton(nextb, { label = TS.L("help_next"), accent = true, iconRight = "caret-right" })

    showPage = function(i)
        page = math.Clamp(i, 1, #list)
        body:Clear()
        local p = list[page]

        local head = body:Add("DLabel")
        head:Dock(TOP)
        head:DockMargin(0, 0, 0, 14)
        head:SetFont("Talksmith_E_HelpHead")
        head:SetTextColor(T.blue)
        head:SetText((page) .. ".  " .. p.head)
        head:SizeToContentsY()

        for _, ln in ipairs(p.body) do
            local l = body:Add("DLabel")
            l:Dock(TOP)
            l:DockMargin(0, 0, 0, 10)
            l:SetWrap(true)
            l:SetAutoStretchVertical(true)
            if ln.key then
                l:SetFont("Talksmith_E_HelpKey")
                l:SetTextColor(T.muted)
                l:SetText(ln.t)
            else
                l:SetFont("Talksmith_E_HelpBody")
                l:SetTextColor(T.text)
                l:SetText("•   " .. ln.t)
            end
        end

        if p.action then
            local action = body:Add("DButton")
            action:Dock(TOP)
            action:DockMargin(0, 10, 0, 4)
            action:SetTall(42)
            TS.Editor.StyleButton(action, {
                label = p.action.label,
                accent = true,
                quiet = false,
                icon = "play",
            })
            action.DoClick = function(button)
                button:SetDisabled(true)
                TS.Editor.RequestExample(TS.Examples.TrialID, function(ok)
                    if ok and IsValid(scr) then
                        scr:Remove()
                    elseif IsValid(button) then
                        button:SetDisabled(false)
                    end
                end)
            end
        end

        prev:SetDisabled(page <= 1)
        nextb:SetStyleLabel(page >= #list and TS.L("help_done") or TS.L("help_next"))
        body:GetVBar():SetScroll(0)
        body:InvalidateLayout(true)

        local activeButton = navButtons[page]
        if IsValid(activeButton) then
            timer.Simple(0, function()
                if IsValid(navScroll) and IsValid(activeButton) then
                    navScroll:ScrollToChild(activeButton)
                end
            end)
        end
    end

    prev.DoClick = function()
        showPage(page - 1)
    end
    nextb.DoClick = function()
        if page >= #list then
            scr:Remove()
        else
            showPage(page + 1)
        end
    end

    scr.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            scr:Remove()
        end
    end
    scr.OnKeyCodePressed = function(_, key)
        if key == KEY_LEFT then
            showPage(page - 1)
        elseif key == KEY_RIGHT or key == KEY_SPACE then
            showPage(page + 1)
        end
    end
    scr.OnRemove = function()
        TS.Editor.HelpOpen = false
        if TS.Editor.HelpFrame == scr then
            TS.Editor.HelpFrame = nil
        end
    end

    showPage(1)
end
