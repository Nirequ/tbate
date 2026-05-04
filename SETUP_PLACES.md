## Пошаговая настройка Multiple Places для TBATE RPG

### Текущий статус
✅ Place 1 (Character Creation) - готов к тестированию
⏳ Place 2 (Main Game) - нужно создать

---

## Шаг 1: Публикация Place 1 (Character Creation)

1. Соберите проект:
```bash
rojo build -o "TBATE.rbxlx"
```

2. Откройте `TBATE.rbxlx` в Roblox Studio

3. Опубликуйте игру:
   - **File → Publish to Roblox**
   - Выберите **Create new game**
   - Название: `TBATE RPG`
   - Описание: `RPG Roguelike по мотивам The Beginning After The End`
   - Жанр: `RPG`
   - Нажмите **Create**

4. Запомните или скопируйте URL игры

---

## Шаг 2: Создание Place 2 (Main Game)

### Через веб-сайт:

1. Откройте [create.roblox.com](https://create.roblox.com/)

2. Найдите вашу игру "TBATE RPG"

3. Нажмите на игру → слева выберите **Places**

4. Нажмите **+ Add Place**

5. Заполните:
   - Name: `Main Game`
   - Description: `Основной игровой сервер`
   - Нажмите **Save**

6. Скопируйте Place ID:
   - Нажмите на три точки рядом с "Main Game"
   - Выберите **Copy Place ID**
   - Сохраните ID (например: `123456789`)

---

## Шаг 3: Обновление конфигурации

1. Откройте `src/shared/CharacterConfig.lua`

2. Замените строку:
```lua
CharacterConfig.MAIN_GAME_PLACE_ID = 0
```

На:
```lua
CharacterConfig.MAIN_GAME_PLACE_ID = 123456789  -- Ваш Place ID
```

3. Пересоберите и опубликуйте:
```bash
rojo build -o "TBATE.rbxlx"
```

4. Откройте в Studio и опубликуйте обновление:
   - **File → Publish to Roblox**
   - Выберите существующую игру "TBATE RPG"
   - Нажмите **Overwrite**

---

## Шаг 4: Настройка Main Game Place

### Создайте новый проект для Main Game:

1. Создайте папку:
```bash
mkdir C:\Users\Nirequ\Desktop\tbate-main-game
cd C:\Users\Nirequ\Desktop\tbate-main-game
```

2. Инициализируйте Rojo проект:
```bash
rojo init
```

3. Создайте базовую структуру для загрузки персонажей

4. Опубликуйте в Place 2:
   - Соберите проект
   - Откройте в Studio
   - **File → Publish to Roblox**
   - Выберите **TBATE RPG**
   - В списке Places выберите **Main Game**
   - Нажмите **Publish**

---

## Шаг 5: Настройка Game Settings

### Для обоих Places:

1. Откройте [create.roblox.com](https://create.roblox.com/)
2. Выберите игру → **Settings**

#### Security:
- ✅ Enable Studio Access to API Services
- ✅ Allow HTTP Requests

#### Access:
- Выберите **Public** или **Private** (для тестирования)

#### Monetization (для слотов 2 и 3):
1. Перейдите в **Monetization → Passes**
2. Создайте два Game Pass:
   - "Character Slot 2" - 100 Robux
   - "Character Slot 3" - 100 Robux
3. Скопируйте их ID

---

## Шаг 6: Тестирование телепортации

1. Опубликуйте оба Places
2. Зайдите в игру через сайт Roblox (не Studio)
3. Создайте персонажа
4. После подтверждения вы должны телепортироваться на Main Game Place

---

## Структура Universe

```
TBATE RPG (Universe ID: XXXXXXX)
│
├── Place 1: Character Creation (Place ID: 111111111)
│   └── Функция: Создание и выбор персонажа
│
└── Place 2: Main Game (Place ID: 222222222)
    └── Функция: Основной геймплей RPG
```

---

## Полезные ссылки

- Creator Dashboard: https://create.roblox.com/
- Документация TeleportService: https://create.roblox.com/docs/reference/engine/classes/TeleportService
- Документация DataStore: https://create.roblox.com/docs/cloud-services/data-stores

---

## Troubleshooting

### Ошибка: "cannot choose start places"
**Причина**: У игры только один Place
**Решение**: Создайте второй Place (см. Шаг 2)

### Ошибка: "Teleport failed"
**Причина**: Неверный Place ID или Places в разных Universe
**Решение**: Проверьте что оба Places принадлежат одной игре

### Персонаж не загружается в Main Game
**Причина**: DataStore не настроен в Main Game
**Решение**: Создайте скрипт загрузки персонажа в Main Game

---

Дата создания: 05.05.2026
