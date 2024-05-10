#!/bin/bash

GAME_DIR="/home/$USER/Games/TurtleWoW//Interface/AddOns/"
ADDONS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/db/addons.json"
BASE64_STRINGS=$(jq -r '.[] | @base64' "$ADDONS_FILE")

getDecodeValue() {
  echo "$1" | base64 --decode | jq -r "$2"
}

dev() {
  echo "мимо!"
}

createdb() {
  if [ ! -s "$ADDONS_FILE" ]; then
    echo '[]' >"$ADDONS_FILE"
    echo "Создана пустая база аддонов в файле $ADDONS_FILE."
  fi
}

# Функция для установки аддона
installAddon() {
  createdb
  local repo="$1"
  local name
  name="$(basename -s .git "$repo")"
  if ! git ls-remote "$repo" &>/dev/null; then
    echo "Удалённый репозиторий с аддоном не существует или недоступен."
    return
  fi
  if [ -z "$(jq -c ".[] | select(.name == \"$name\")" "$ADDONS_FILE")" ]; then
    echo "Добавляю в json..."
    jq ".[length] |= . + {\"name\":\"$name\",\"repo\":\"$repo\"}" "$ADDONS_FILE" >tmpfile && mv tmpfile "$ADDONS_FILE"
    echo "Аддон добавлен"
  fi
  local addonDir="$GAME_DIR$name"
  if [ -d "$addonDir" ]; then
    echo "Найдена старая папка, удаляю..."
    rm -rf "$addonDir"
    echo "удалил"
  fi
  echo "Создаю папку и клонирую репу..."
  mkdir -p "$addonDir"
  git clone "$repo" "$addonDir"
  echo "Аддон $name установлен!"
}

synchronizationAddons() {
  for item in $BASE64_STRINGS; do
    local name
    name=$(getDecodeValue "$item" ".name")
    local repo
    repo=$(getDecodeValue "$item" ".repo")
    echo "Синхронизирую $name с репой $repo..."
    if ! git ls-remote "$repo" &>/dev/null; then
      echo "Удалённый репозиторий с аддоном не существует или недоступен."
      continue
    fi
    local addonDir="$GAME_DIR$name"
    if [ -d "$addonDir" ]; then
      if [ -d "$addonDir/.git" ]; then
        echo "Аддон $name уже установлен и имеет репозиторий"
        continue
      fi
      echo "Найдена старая папка, удаляю..."
      rm -rf "$addonDir"
      echo "удалил"
    fi
    echo "Создаю папку и клонирую репу..."
    mkdir -p "$addonDir"
    git clone "$repo" "$addonDir"
    echo "Аддон $name установлен!"
  done
}

# Функция для обновления аддонов
updateAddons() {
  for item in $BASE64_STRINGS; do
    local name
    name=$(getDecodeValue "$item" ".name")
    local repo
    repo=$(getDecodeValue "$item" ".repo")
    addonDir="$GAME_DIR$name"
    if [ -d "$addonDir/.git" ]; then
      git -C "$addonDir" pull
      echo "Аддон $name обновлен!"
    else
      echo "Ошибка: Аддон $name не имеет репозитория!"
    fi
  done
}

# Функция для удаления аддона
removeAddon() {
  local name=$1
  if jq -e ".[] | select(.name == \"$name\")" "$ADDONS_FILE" >/dev/null; then
    rm -rf "$GAME_DIR$name"
    jq --arg name "$name" ".[] | select(.name != \"$name\")" "$ADDONS_FILE" >tmpfile && mv tmpfile "$ADDONS_FILE"
    echo "Аддон $name удален"
  else
    echo "Ошибка: Аддон $name не найден."
  fi
}

statusAddons() {
  for item in $BASE64_STRINGS; do
    local name
    name=$(getDecodeValue "$item" ".name")
    local repo
    repo=$(getDecodeValue "$item" ".repo")
    local commits
    commits=$(git -C "$GAME_DIR/$name" log --oneline HEAD..master 2>&1)
    local status
    if [[ "$commits" == *"fatal"* ]]; then
      status="Репы не доступна"
    elif [[ -z "$commits" ]]; then
      status="Актуален"
    else
      status="Доступна обнова"
    fi
    printf "%-15s | %-40s | %-20s\n" "$name" "$repo" "$status"
  done
}

# Обработка аргументов
case "$1" in
add)
  installAddon "$2"
  ;;
sync)
  synchronizationAddons "$2"
  ;;
up)
  updateAddons "$2"
  ;;
remove)
  removeAddon "$2"
  ;;
stat)
  statusAddons
  ;;
clear_data_base)
  createdb
  ;;
*)
  dev
  # echo "Usage: $0 {install <repo> | update | remove <name>}"
  # exit 1
  ;;
esac
