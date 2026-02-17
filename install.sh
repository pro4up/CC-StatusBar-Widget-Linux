#!/bin/bash
# Установка tmux статус-бара с виджетом использования Claude
# Запускать из папки со скриптом: bash install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Установка Claude Usage Widget для tmux ==="

# Проверка зависимостей
for cmd in tmux jq curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ОШИБКА: не найден '$cmd'. Установите его и повторите."
    exit 1
  fi
done

# Backup существующих конфигов
if [[ -f ~/.tmux.conf ]]; then
  cp ~/.tmux.conf ~/.tmux.conf.bak
  echo "Резервная копия ~/.tmux.conf -> ~/.tmux.conf.bak"
fi

# Копирование файлов
mkdir -p ~/.claude
cp "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
cp "$SCRIPT_DIR/claude-usage.sh" ~/.claude/claude-usage.sh
chmod +x ~/.claude/claude-usage.sh

echo "Файлы установлены."

# Применение конфига tmux
if [[ -n "$TMUX" ]]; then
  tmux source-file ~/.tmux.conf
  echo "Конфиг tmux перезагружен."
else
  echo "ПРИМЕЧАНИЕ: запустите внутри tmux: tmux source-file ~/.tmux.conf"
fi

echo ""
echo "=== Готово ==="
echo "Виджет будет отображаться в правой части статус-бара tmux."
