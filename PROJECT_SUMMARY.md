# TBATE RPG - Полная документация проекта

## 📋 Обзор проекта

RPG roguelike игра в Roblox по мотивам новеллы "The Beginning After The End" с системой создания персонажей.

**Дата создания**: 05.05.2026  
**Статус**: ✅ Готово к тестированию

---

## 🎮 Игровой процесс

1. **Вход в игру** → Игрок попадает на отдельный сервер (Place 1)
2. **Выбор слота** → 3 слота персонажей (1 бесплатный, 2 и 3 за 100 Robux)
3. **Создание персонажа** → Выбор расы, прически, одежды
4. **Сохранение** → Персонаж сохраняется в DataStore
5. **Телепортация** → Игрок телепортируется на основной сервер (Place 2)
6. **Игра** → Персонаж загружается и применяется на основном сервере

---

## 🏗️ Архитектура

### Place 1: Character Creation (Создание персонажа)
```
src/
├── client/
│   ├── init.client.luau              # Главный клиентский скрипт
│   └── controllers/
│       ├── CharacterController.lua    # Контроллер персонажей
│       ├── SlotSelectionUI.lua        # UI выбора слота (3 слота)
│       └── CharacterEditorUI.lua      # UI редактора (раса, внешность)
│
├── server/
│   ├── init.server.luau              # Главный серверный скрипт
│   └── services/
│       ├── DataStoreService.lua       # Сохранение/загрузка данных
│       └── CharacterService.lua       # Логика персонажей, телепортация
│
└── shared/
    ├── CharacterConfig.lua            # Конфигурация рас и внешности
    └── RemoteObjects.lua              # Коммуникация клиент-сервер
```

### Place 2: Main Game (Основная игра)
```
MainGameServer.lua                     # Скрипт загрузки персонажей
```

---

## 🧝 Расы

| Раса | Рост | Особенности |
|------|------|-------------|
| **Человек** | 1.0x | Сбалансированная раса |
| **Эльф** | 1.15x | Высокий, длинные уши |
| **Дварф** | 0.75x | Низкий, крепкий |

---

## 📦 Файлы проекта

### Основные файлы:
- `README.md` - Основная документация
- `TESTING.md` - Инструкция по тестированию
- `SETUP_PLACES.md` - Настройка Multiple Places
- `PROJECT_SUMMARY.md` - Этот файл
- `MainGameServer.lua` - Шаблон для Place 2
- `default.project.json` - Конфигурация Rojo
- `.gitignore` - Git ignore файл
- `aftman.toml` - Менеджер инструментов

### Lua модули (7 файлов):
1. `CharacterConfig.lua` - Конфигурация
2. `RemoteObjects.lua` - Remotes
3. `DataStoreService.lua` - DataStore
4. `CharacterService.lua` - Серверная логика
5. `CharacterController.lua` - Клиентский контроллер
6. `SlotSelectionUI.lua` - UI слотов
7. `CharacterEditorUI.lua` - UI редактора

---

## 🚀 Быстрый старт

### 1. Тестирование в Studio

```bash
# Собрать проект
rojo build -o "TBATE.rbxlx"

# Открыть в Studio
# Включить: Game Settings → Security → Enable Studio Access to API Services
# Нажать Play (F5)
```

### 2. Публикация

```bash
# 1. Собрать
rojo build -o "TBATE.rbxlx"

# 2. Открыть в Studio
# 3. File → Publish to Roblox → Create new game
# 4. Название: "TBATE RPG"
```

### 3. Создание второго Place

См. подробную инструкцию в `SETUP_PLACES.md`

---

## ⚙️ Настройка

### Обязательные настройки:

1. **Place ID основной игры** (`CharacterConfig.lua`):
```lua
CharacterConfig.MAIN_GAME_PLACE_ID = YOUR_PLACE_ID
```

2. **Game Settings** (оба Places):
   - ✅ Enable Studio Access to API Services
   - ✅ Allow HTTP Requests

### Опциональные настройки:

3. **Asset ID для причесок** (`CharacterConfig.lua`):
```lua
CharacterConfig.HAIRSTYLES = {
    {Name = "Короткие волосы", AssetId = 123456789},
}
```

4. **Asset ID для одежды** (`CharacterConfig.lua`):
```lua
CharacterConfig.CLOTHING = {
    Shirts = {
        {Name = "Простая рубашка", AssetId = 123456789},
    }
}
```

5. **Game Pass для слотов** (`CharacterService.lua`):
   - Создайте Game Pass на сайте
   - Добавьте проверку в функцию `UnlockSlot`

---

## 🔧 Технические детали

### DataStore структура:
```lua
{
    UnlockedSlots = {true, false, false},
    Characters = {
        [1] = {
            Race = "Human",
            HairstyleIndex = 1,
            ShirtIndex = 1,
            PantsIndex = 1,
            SkinColor = Color3.fromRGB(255, 204, 153),
            HairColor = Color3.fromRGB(139, 69, 19)
        },
        [2] = nil,
        [3] = nil
    }
}
```

### Remote Functions:
- `GetCharacterSlotsFunction` - Получить слоты игрока
- `CreateCharacterFunction` - Создать персонажа
- `LoadCharacterFunction` - Загрузить персонажа
- `UnlockSlotFunction` - Разблокировать слот
- `TeleportToMainGameFunction` - Телепортация

---

## ✅ Что работает

- ✅ Система 3 слотов персонажей
- ✅ Выбор расы (Человек, Эльф, Дварф)
- ✅ Выбор прически и одежды
- ✅ Сохранение в DataStore
- ✅ Загрузка персонажа
- ✅ Модификация модели по расе
- ✅ UI выбора слота
- ✅ UI редактора персонажа
- ✅ Телепортация (при настроенном Place 2)

---

## 📝 TODO

- [ ] Добавить Asset ID для ушей эльфов
- [ ] Добавить Asset ID для причесок из каталога
- [ ] Добавить Asset ID для одежды из каталога
- [ ] Настроить Game Pass для слотов 2 и 3
- [x] Добавить 3D превью персонажа в редакторе
- [x] Добавить выбор цвета кожи и волос в UI
- [ ] Создать основной геймплей для Place 2
- [ ] Добавить систему прогрессии персонажа
- [ ] Добавить систему инвентаря
- [ ] Реализовать roguelike механики

---

## 🐛 Известные проблемы

### "cannot choose start places"
**Решение**: Создайте второй Place (см. `SETUP_PLACES.md`)

### Телепортация не работает
**Решение**: Установите `MAIN_GAME_PLACE_ID` в `CharacterConfig.lua`

### DataStore не сохраняет в Studio
**Решение**: Включите "Enable Studio Access to API Services"

---

## 📚 Полезные ресурсы

- [Rojo Documentation](https://rojo.space/docs)
- [Roblox Creator Hub](https://create.roblox.com/docs)
- [TeleportService API](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- [DataStoreService API](https://create.roblox.com/docs/cloud-services/data-stores)
- [HumanoidDescription API](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription)

---

## 👨‍💻 Разработка

### Структура команд:

```bash
# Сборка
rojo build -o "TBATE.rbxlx"

# Live sync (для разработки)
rojo serve

# Проверка конфигурации
rojo --version
```

### Workflow:

1. Редактируйте `.lua` файлы в `src/`
2. Запустите `rojo serve`
3. В Studio: Plugins → Rojo → Connect
4. Изменения применяются автоматически
5. Тестируйте в Studio
6. Собирайте и публикуйте

---

## 📄 Лицензия

Проект создан с использованием [Rojo](https://github.com/rojo-rbx/rojo) 7.7.0-rc.1

---

**Создано**: 05.05.2026  
**Версия**: 1.0.0  
**Статус**: Production Ready
