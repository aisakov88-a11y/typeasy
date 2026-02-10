# Typeasy

Voice-to-text приложение для macOS с AI-powered обработкой текста.

## Возможности

- **Голосовой ввод** — нажмите Cmd+Shift+D, наговорите текст
- **Локальное распознавание** — WhisperKit (large-v3-turbo) с поддержкой русского и английского
- **AI обработка** — LM Studio + LLM исправляет пунктуацию и удаляет слова-паразиты
- **Мгновенная вставка** — текст вставляется в активное поле ввода
- **Кастомизация промпта** — редактируйте инструкции для LLM в настройках

## Требования

- macOS 14.0 (Sonoma) или новее
- Apple Silicon (M1/M2/M3)
- 16GB RAM
- LM Studio для LLM обработки
- Python 3 (для загрузки WhisperKit модели)
- ~1.5GB свободного места для моделей

## Установка зависимостей

### 1. Установите LM Studio

Скачайте и установите [LM Studio](https://lmstudio.ai/)

```bash
# Или через Homebrew
brew install --cask lm-studio
```

### 2. Скачайте LLM модель в LM Studio

1. Откройте LM Studio
2. Найдите и скачайте модель (например, Qwen 2.5 7B или Gemma 3 4B)
3. Запустите локальный сервер (кнопка "Start Server" в настройках)

### 3. Скачайте WhisperKit модель

**Рекомендуем начать с Base модели** (быстрая и точная):

```bash
cd ~/typeasy
./download-whisper-model.sh base
```

**Доступные модели:**

| Модель | Размер | Скорость | Точность | Когда использовать |
|--------|--------|----------|----------|-------------------|
| `tiny` | ~40MB | Очень быстро (~1-2s) | Базовая | Максимальная скорость |
| `base` | ~140MB | Быстро (~2-3s) | Хорошая | **Рекомендуется** |
| `small` | ~466MB | Средне (~3-5s) | Отличная | Нужна точность |
| `large-v3-turbo` | ~954MB | Медленно (~5-10s) | Лучшая | Максимальная точность |

Скачать конкретную модель:
```bash
./download-whisper-model.sh small      # Точная модель
./download-whisper-model.sh large-v3-turbo  # Самая точная
```

Вы можете переключать модели в Settings → Models после установки.

## Сборка

### 1. Перейдите в директорию проекта

```bash
cd ~/typeasy
```

### 2. Соберите через командную строку

```bash
swift build -c release
```

### 3. Или откройте в Xcode

```bash
open Package.swift
```

Затем нажмите Cmd+R для запуска.

## Первый запуск

1. **Скачайте WhisperKit модель:**
   ```bash
   cd ~/typeasy
   ./download-whisper-model.sh
   ```

2. **Запустите LM Studio и включите сервер:**
   - Откройте LM Studio
   - Загрузите модель (например, Qwen 2.5 7B)
   - Перейдите в "Local Server" → "Start Server"

3. **Запустите Typeasy:**
   ```bash
   open Typeasy.app
   ```

4. **Дайте разрешения:**
   - **Microphone** - диалог появится при первой записи
   - **Accessibility** - откройте System Settings → Privacy & Security → Accessibility, добавьте Typeasy

   Или автоматически откройте настройки:
   ```bash
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
   ```

## Использование

1. **Проверьте статус** — кликните на иконку микрофона в menu bar → должно показывать "Ready"
2. **Начните запись** — нажмите **Cmd+Shift+D**
3. **Говорите** — на русском или английском языке
4. **Остановите запись** — нажмите **Cmd+Shift+D** ещё раз
5. **Текст вставится автоматически** — в активное поле ввода

## Настройки

Откройте Settings через меню приложения:

- **General** — включение LLM обработки, выбор языка
- **Prompt** — редактор промпта для LLM
- **Replacements** — словарь пользовательских замен текста
- **Models** — выбор модели WhisperKit (tiny/base/small/large), статус LM Studio
- **Permissions** — статус разрешений

## Кастомизация промпта

По умолчанию используется промпт с расширенной коррекцией ошибок транскрибации:

```
Fix the following transcribed text from speech recognition (Whisper):

TRANSCRIPTION ERROR CORRECTION:
- The text may contain speech recognition errors, especially for technical terms
- Use context to infer the correct technical term when transcription is wrong
- Common Whisper transcription errors for technical terms:
  * "кодекс" → "Codex"
  * "копайлот" → "CoPilot"
  * "клод код" → "Claude Code"
  * "гитхаб" → "GitHub"
  * "джава скрипт" → "JavaScript"
  * "тайпскрипт" → "TypeScript"
  * "пайтон" → "Python"
  * "докер" → "Docker"
  * "кубернетес" → "Kubernetes"
  * "апи" → "API"
  * "реакт" → "React"
  * "вью" → "Vue"
  * (и многие другие...)
- If a Russian word sounds like a technical term, infer the correct English term from context

TEXT CLEANUP:
- Correct punctuation and capitalization
- Remove filler words (um, uh, like / эм, ну, типа, короче)
- Keep the original meaning and tone

LANGUAGE RULES:
- IMPORTANT: Keep the same language as the input text
- Technical terms should be in their original language with correct capitalization

OUTPUT:
- Output ONLY the corrected text, no explanations

Text: [transcription]
```

`[transcription]` заменяется на распознанный текст.

### Работа с техническими терминами и исправление ошибок транскрибации

**Проблема:** Whisper часто неправильно распознаёт технические термины, продукты и имена на английском, особенно в русской речи.

**Решение:** LLM автоматически исправляет ошибки транскрибации, используя контекст и обширный словарь технических терминов.

#### Примеры автоматического исправления:

**Продукты и инструменты:**
- "клод код" / "клод code" → "Claude Code"
- "копайлот" / "ко пилот" → "CoPilot"
- "кодекс" / "код экс" → "Codex"
- "гитхаб" / "гит хаб" → "GitHub"
- "гит лаб" → "GitLab"
- "ущерба" / "редаш" → "Redash"
- "табло" / "таблоу" → "Tableau"
- "метабейс" → "Metabase"
- "слак" → "Slack"
- "джира" → "Jira"
- "нотион" / "ноушен" → "Notion"
- "фигма" → "Figma"

**Языки программирования:**
- "джава скрипт" / "ява скрипт" → "JavaScript"
- "тайпскрипт" / "тип скрипт" → "TypeScript"
- "пайтон" → "Python"
- "джава" → "Java"
- "котлин" → "Kotlin"
- "свифт" → "Swift"
- "го" / "голанг" → "Go"
- "раст" → "Rust"

**Фреймворки и технологии:**
- "докер" → "Docker"
- "кубернетес" / "куб ернетес" → "Kubernetes"
- "реакт" → "React"
- "вью" → "Vue"
- "ангуляр" → "Angular"
- "нод" / "нода" → "Node"
- "экспресс" → "Express"
- "джанго" → "Django"

**UI/UX термины:**
- "оба борта" / "деш борд" / "дэшборд" → "дашборд" (или "dashboard")
- "модал" / "модалка" → "модал" (или "modal")
- "дропдаун" → "дропдаун" (или "dropdown")
- "попап" → "попап" (или "popup")

**API и базы данных:**
- "апи" / "АПИ" → "API"
- "рест апи" → "REST API"
- "граф кьюэл" → "GraphQL"
- "джейсон" / "жейсон" → "JSON"
- "эн пи эм" → "npm"
- "постгрес" → "PostgreSQL"
- "монго" → "MongoDB"
- "редис" → "Redis"

#### Как это работает:

**Пример 1 - Простые замены:**
1. **Вы говорите:** "я деплою приложение в докер на кубернетес"
2. **Whisper транскрибирует:** "я деплою приложение в докер на кубернетес"
3. **LLM исправляет:** "Я деплою приложение в Docker на Kubernetes"

**Пример 2 - Исправление бессмысленных фраз:**
1. **Вы говорите:** "добавь график на дэшборд в Redash"
2. **Whisper неправильно слышит:** "добавьте график на оба борта ущерба"
3. **LLM понимает контекст и исправляет:** "Добавьте график на дашборд в Redash"

**Пример 3 - Множественные термины:**
1. **Вы говорите:** "нужно настроить API для реакт приложения в постгрес"
2. **Whisper транскрибирует:** "нужно настроить апи для реакт приложения в постгрес"
3. **LLM исправляет:** "Нужно настроить API для React приложения в PostgreSQL"

LLM использует контекст предложения, чтобы понять, что "оба борта ущерба" в техническом контексте - это скорее всего "дашборд в Redash".

#### Когда использовать словарь замен:

Если термин слишком специфичный или LLM не распознает его автоматически, добавьте замену в Settings → Replacements:

| Что распознаёт Whisper | Что нужно | Как добавить |
|-------------------------|-----------|--------------|
| навайбкодил | написал код | "навайбкодил" → "написал код" |
| артворкаут | ArtWorkout | "артворкаут" → "ArtWorkout" |
| тайпэси | Typeasy | "тайпэси" → "Typeasy" |

## Словарь замен (Text Replacements)

Создайте пользовательские замены для:
- **Сложных терминов** — "навайбкодил", "дебажил"
- **Email адресов** — "рабочая почта" → "aisakov@artworkout.app"
- **Упоминаний** — "Саша" → "@ulitiy"
- **Сокращений** — "др" → "день рождения"

### Как добавить замену:

1. Откройте **Settings → Replacements**
2. Нажмите кнопку **"Add"**
3. Введите:
   - **Trigger phrase** — что искать в тексте
   - **Replacement text** — на что заменить
   - **Case sensitive** — учитывать регистр (опционально)
4. Нажмите **"Save"**

### Примеры использования:

| Trigger | Replacement | Результат |
|---------|-------------|-----------|
| рабочая почта | aisakov@artworkout.app | "Напиши на рабочая почта" → "Напиши на aisakov@artworkout.app" |
| Саша | @ulitiy | "Спроси у Саша" → "Спроси у @ulitiy" |
| навайбкодил | написал код | "Я навайбкодил фичу" → "Я написал код фичу" |

### Порядок обработки:

**С включенной LLM обработкой:**
1. **WhisperKit** распознаёт речь
2. **LLM** исправляет пунктуацию и удаляет слова-паразиты
3. **Replacements** применяют пользовательские замены к обработанному тексту
4. **Текст вставляется** в активное поле

**Без LLM обработки:**
1. **WhisperKit** распознаёт речь
2. **Replacements** применяют пользовательские замены к распознанному тексту
3. **Текст вставляется** в активное поле

Замены применяются программно после LLM обработки, что гарантирует их точное применение только при наличии триггерных фраз в тексте.

## Структура проекта

```
Typeasy/
├── App/
│   └── TypeasyApp.swift           # Точка входа
├── Core/
│   ├── Audio/
│   │   └── AudioCaptureManager.swift
│   ├── Transcription/
│   │   └── TranscriptionService.swift
│   ├── LLM/
│   │   ├── LLMService.swift       # Ollama HTTP API
│   │   └── PromptTemplates.swift
│   ├── TextInsertion/
│   │   └── TextInsertionService.swift
│   └── Pipeline/
│       ├── DictationPipeline.swift
│       └── PipelineState.swift
├── UI/
│   ├── MenuBar/
│   │   └── MenuBarView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Onboarding/
│       └── OnboardingView.swift
├── Services/
│   └── PermissionService.swift
└── Models/
    └── AppState.swift
```

## Технологии

- **WhisperKit** — speech-to-text на Apple Silicon (4 модели на выбор: tiny/base/small/large)
- **LM Studio** — локальный LLM сервер с OpenAI-совместимым API
- **HotKey** — глобальные горячие клавиши
- **SwiftUI** — нативный UI

## Устранение неполадок

### WhisperKit модель не загружается

Если модель не загрузилась автоматически при первом запуске, скачайте её вручную:

```bash
cd ~/typeasy
./download-whisper-model.sh
```

### LLM обработка не работает

Убедитесь что:
1. LM Studio запущен
2. Модель загружена в LM Studio
3. Локальный сервер включён (Server Settings → Start Server)
4. Порт 1234 не занят другим приложением

### Текст переводится на английский

Убедитесь что в Settings → Prompt есть строка:
```
IMPORTANT: Keep the same language as the input text
```

Если её нет, нажмите "Reset to Default"

## Распространение

### Для разработчиков: Создание дистрибутива

Если хотите поделиться приложением с коллегами:

#### 1. Соберите Release версию

```bash
./build-release.sh
```

Это создаст подписанный (ad-hoc) `.app` bundle в папке `dist/`.

#### 2. Создайте DMG установщик

```bash
./create-dmg.sh
```

Это создаст `dist/Typeasy-Installer.dmg` со всем необходимым:
- Typeasy.app
- download-whisper-model.sh скрипт
- README с инструкциями
- Ссылка на /Applications для drag-and-drop установки

#### 3. Распространите DMG файл

Отправьте коллегам файл `dist/Typeasy-Installer.dmg`.

### Для пользователей: Установка из DMG

1. **Откройте DMG файл** — дважды кликните на `Typeasy-Installer.dmg`

2. **Перетащите Typeasy.app** в папку Applications

3. **Запустите setup скрипт** (автоматически установит зависимости):
   ```bash
   curl -sSL https://raw.githubusercontent.com/yourusername/typeasy/main/setup-typeasy.sh | bash
   ```

   Или вручную скачайте WhisperKit модель:
   ```bash
   ./download-whisper-model.sh
   ```

4. **Установите LM Studio**:
   ```bash
   brew install --cask lm-studio
   ```

   Или скачайте с [lmstudio.ai](https://lmstudio.ai/)

5. **Настройте LM Studio**:
   - Скачайте модель (Qwen 2.5 7B, Llama 3.2 3B и т.д.)
   - Запустите локальный сервер: Local Server → Start Server

6. **Запустите Typeasy**:
   - Найдите в Applications
   - При первом запуске: Control+Click → Open (обход Gatekeeper)
   - Дайте разрешения (Microphone, Accessibility)

### ⚠️ Gatekeeper Warning

Пользователи увидят предупреждение при первом запуске, так как приложение не нотаризовано Apple.

**Обход:**
1. System Settings → Privacy & Security
2. Найдите сообщение: "Typeasy was blocked"
3. Нажмите "Open Anyway"

Или через терминал:
```bash
xattr -cr /Applications/Typeasy.app
```

### Профессиональное распространение (опционально)

Для распространения без предупреждений нужен:
- Apple Developer Program ($99/год)
- Code signing с Developer ID certificate
- Notarization через Apple

Инструкция: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

## Лицензия

MIT
