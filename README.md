# Claude Usage Widget для tmux

Виджет отображает лимиты использования Claude в правой части статус-бара tmux.

## Что отображается

```
[main] 0:claude*                    4h40m: [▓▓░░░░░░░░] 16%
```

- **Левая часть** — сессия tmux и список окон (серый)
- **Правая часть** — виджет лимитов:
  - `4h40m` — время до сброса 5-часового лимита
  
  - `[▓▓░░░░░░░░]` — прогресс-бар (10 блоков)
  - `16%` — процент использования

### Цвета прогресс-бара

| Процент | Цвет     |
|---------|----------|
| < 60%   | Серый    |
| 60–80%  | Жёлтый   |
| > 80%   | Красный  |

Пустые блоки всегда тёмно-серые для контраста.

## Файлы

| Файл               | Назначение                          | Куда устанавливается        |
|--------------------|-------------------------------------|-----------------------------|
| `tmux.conf`        | Конфиг tmux (стили + виджет)        | `~/.tmux.conf`              |
| `claude-usage.sh`  | Скрипт получения лимитов Claude API | `~/.claude/claude-usage.sh` |
| `install.sh`       | Автоматическая установка            | —                           |

## Установка
Перед установкой нужно выкачать весь репозиторий. Либо скинуть ссылку на этот репозиторий вашему Claude Code и попросить установить все.

### Автоматически

```bash
bash install.sh
```

### Вручную

```bash
# 1. Скопировать скрипт
mkdir -p ~/.claude
cp claude-usage.sh ~/.claude/claude-usage.sh
chmod +x ~/.claude/claude-usage.sh

# 2. Скопировать конфиг tmux
#    ВНИМАНИЕ: если ~/.tmux.conf уже существует — сначала сделайте бэкап
cp tmux.conf ~/.tmux.conf

# 3. Применить конфиг (внутри tmux)
tmux source-file ~/.tmux.conf
```

### Если ~/.tmux.conf уже существует

Добавьте вручную в конец вашего `~/.tmux.conf`:

```bash
# Claude usage widget
set -g status-style bg=default,fg=default
set -g status-left-style fg=#565f89
set -g status-right-style fg=#565f89
set -g window-status-style fg=#565f89
set -g window-status-current-style fg=#565f89
set -g status-right-length 120
set -g status-right '#(bash ~/.claude/claude-usage.sh all)'
set -g status-interval 30
```

## Зависимости

- `tmux` (любая современная версия)
- `jq` — парсинг JSON
- `curl` — запросы к Claude API
- Авторизованный Claude Code (`~/.claude/.credentials.json` должен существовать)

## Как работает

1. Скрипт читает токен из `~/.claude/.credentials.json` (создаётся при логине в Claude Code)
2. Делает запрос к `https://api.anthropic.com/api/oauth/usage`
3. Кэширует ответ на 60 секунд в `~/.cache/claude-api-response.json`
4. tmux опрашивает скрипт каждые 30 секунд (`status-interval`)

## Ручное обновление виджета

```bash
# Сбросить кэш и принудительно обновить
rm -f ~/.cache/claude-api-response.json ~/.cache/claude-usage.lock
tmux refresh-client -S
```

## Палитра (Tokyo Night Storm)

| Переменная | Цвет      | Применение              |
|------------|-----------|-------------------------|
| `C_RED`    | `#f7767e` | > 80%                   |
| `C_YELLOW` | `#e0af68` | 60–80%                  |
| `C_GRAY`   | `#565f89` | < 60%, метки, скобки    |
| `C_DIM`    | `#3b4261` | Пустые блоки прогресс-бара |
