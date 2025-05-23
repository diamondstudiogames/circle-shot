# Создание события

В этом руководстве описан процесс создания события.

## Основная инструкция

1. Создайте папку `game/events/<имя события>`. Название папки события должно быть написано в *snake_case*.
2. Унаследуйтесь от сцены `game/events/common/event.tscn` и сохраните новую сцену в `game/events/<имя события>/<имя события>.tscn`.
3. Расширьте скрипт корневого узла и сохраните его в `game/events/<имя события>/<имя события>.gd`. Отредактируйте шаблон скрипта, вписав имя Вашего события в нужном регистре (будь то *PascalCase* или *snake_case*). Более подробно программирование события будет описано позже.
4. Расширьте скрипт узла `UI`, дайте ему имя класса `<имя нового события в PascalCase>UI` и сохраните его в `game/events/<имя события>/<имя события>_ui.gd`. Более подробно программирование интерфейса события будет описано позже.
5. Унаследуйтесь от сцены `game/events/common/base_map.tscn` и сохраните новую сцену в `game/events/<имя события>/base_map.tscn`. Это базовая карта для всех карт этого события. В ней стоит расположить то, что может меняться между картами (например, точки появления игроков, аптечек и прочего). Сформируйте границы карты при помощи дочерних узлов `Borders` и обозначьте их с помощью линеек в редакторе.
6. Поменяйте текст в узле `UI/Intro/Title` на имя события, в узле `UI/Intro/Title/Description` - на описание события, а в узле `UI/Intro/Text` - на ещё одно описание.
6. Нарисуйте обложку события в разрешении 784 на 160. Сохраните её как `game/events/<имя события>/image.png`.
7. Создайте ресурс типа `EventData` с именем `<имя события>.tres` в папке Вашего события. Заполните название и краткое описание. В поле `Scene Path` перетащите сцену Вашего события, а в `Image Path` - `image.png`. Также отредактируйте (если нужно) `Min Players`, `Max Players` и `Players Divider`. Подробности смотрите в документации к этим свойствам.
8. Откройте `game/core/items_db.tres` и в свойство `Events` добавьте `*.tres` файл нового события.
9. Готово! Теперь событие доступно для выбора в игре. Однако, сперва нужно создать хотя бы одну карту - см. `creating_maps.md`.

## Программирование события

- В скрипте события нужно **как минимум** переопределить 2 метода - `_get_spawn_point` и `_make_teams`. Чтобы понять, что нужно в них сделать, документация внутри движка - к Вашим услугам.
- Если вы хотите настроить постоянные характеристики игрока (например, максимальное здоровье), то унаследуйтесь от `game/player/player.tscn`, поменяйте что нужно, сохраните новую сцену в папку Вашего события и добавьте её (перед этим можно удалить сцену по умолчанию, если она Вам не нужна) в массив `Player Scenes` на узле события. Затем Вы можете к ней обращаться в `_get_player_scene` (если Вы не перезаписали сцену по умолчанию, иначе этот метод и без переопределения вернёт нужную сцену).
    - Таким же способом можно добавлять логику к игроку, специфичную для данного события, расширяя скрипт в унаследованной сцене.
- Также доступно ещё множество методов для переопределения. Все они описаны в документации.
- Если событие создаёт какие-то объекты (например, аптечки), то рекомендуется их добавлять как дочерние узлу `Other`. Не забудьте настроить `OtherSpawner`, указав пути к сценам этих объектов в `Auto Spawn List`.
- Настоятельно рекомендуется добавить обработку отключения игроков (через `_player_disconnected`).
    - В командных режимах в случае отключения всех игроков противоположной команды побеждает та команда, в которой остались игроки, НЕЗАВИСИМО от счёта.
- За половину секунды до конца события (или раунда) нужно вызвать метод `cleanup`.
- Между объявлением результатов и окончания события должно пройти 7 секунд. Очистка игроков, снарядов и прочего - за половину секунды до окончания события.

## Программирование интерфейса события

В первую очередь, в сцене события добавьте нужные узлы интерфейса в качестве дочерних узла `UI/Main` или `UI/Main/PlayerUI/Controller`. Затем уже в скрипте интерфейса события напишите нужные методы, будь то RPC или обычные. После этого из скрипта своего события вызывайте их по необходимости.

Также при рисовании элементов интерфейса не забывайте про [`drawing.md`](./drawing.md).
