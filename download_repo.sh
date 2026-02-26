#!/bin/bash

#==========================================
#  Расшифровка токена и клонирование репо
#==========================================

set -euo pipefail

# ---- НАСТРОЙКИ ----
ENCRYPTED_FILE="./github_token.enc"
REPO=""
BRANCH="main"
DEST_DIR=""

# ---- Цвета ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
print_err()   { echo -e "${RED}[ОШИБКА]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

echo "=========================================="
echo "  Скачивание приватного репозитория GitHub"
echo "=========================================="
echo

# ---- Проверка зависимостей ----
for cmd in openssl git; do
    if ! command -v "$cmd" &>/dev/null; then
        print_err "$cmd не установлен!"
        exit 1
    fi
done

# ---- Путь к зашифрованному файлу ----
if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    read -rp "Путь к зашифрованному файлу (.enc): " ENCRYPTED_FILE
    if [[ ! -f "$ENCRYPTED_FILE" ]]; then
        print_err "Файл не найден: $ENCRYPTED_FILE"
        exit 1
    fi
fi

# ---- Запрос пароля ----
read -rsp "Введите пароль для расшифровки: " PASSWORD
echo

# ---- Расшифровка ----
TOKEN=$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
    -pass pass:"$PASSWORD" -in "$ENCRYPTED_FILE" 2>/dev/null | tr -d '[:space:]')

unset PASSWORD

if [[ -z "$TOKEN" ]]; then
    print_err "Не удалось расшифровать токен. Неверный пароль?"
    exit 1
fi

print_ok "Токен расшифрован"

# ---- Запрос репозитория ----
if [[ -z "$REPO" ]]; then
    echo
    read -rp "Репозиторий (owner/repo): " REPO
fi

if [[ -z "$REPO" || ! "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
    print_err "Неверный формат. Используйте: owner/repo"
    unset TOKEN
    exit 1
fi

# ---- Запрос ветки ----
read -rp "Ветка [${BRANCH}]: " input_branch
BRANCH="${input_branch:-$BRANCH}"

# ---- Папка назначения ----
DEFAULT_DEST=$(echo "$REPO" | cut -d'/' -f2)
read -rp "Папка назначения [${DEFAULT_DEST}]: " input_dest
DEST_DIR="${input_dest:-$DEFAULT_DEST}"

# ---- Проверка доступа ----
echo
echo "Проверка доступа к репозиторию..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    "https://api.github.com/repos/${REPO}")

if [[ "$HTTP_CODE" != "200" ]]; then
    print_err "Нет доступа к репозиторию (HTTP $HTTP_CODE)"
    print_warn "Проверьте токен и имя репозитория"
    unset TOKEN
    exit 1
fi

print_ok "Доступ подтверждён"

# ---- Выбор метода ----
echo
echo "Метод скачивания:"
echo "  1) git clone (полный репозиторий)"
echo "  2) Скачать ZIP-архив"
read -rp "Выберите [1]: " METHOD
METHOD="${METHOD:-1}"

echo

case "$METHOD" in
    1)
        print_warn "Клонирование репозитория..."
        
        # Клонирование без сохранения токена в конфиге
        git clone --branch "$BRANCH" --single-branch \
            "https://x-access-token:${TOKEN}@github.com/${REPO}.git" \
            "$DEST_DIR" 2>&1

        if [[ $? -eq 0 ]]; then
            # Убираем токен из remote URL
            cd "$DEST_DIR"
            git remote set-url origin "https://github.com/${REPO}.git"
            cd ..
            
            print_ok "Репозиторий склонирован в: $DEST_DIR"
            print_ok "Токен удалён из remote URL"
        else
            print_err "Ошибка клонирования"
        fi
        ;;
    2)
        ZIP_FILE="${DEST_DIR}.zip"
        print_warn "Скачивание ZIP-архива..."
        
        curl -L \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/${REPO}/zipball/${BRANCH}" \
            -o "$ZIP_FILE" 2>/dev/null

        if [[ -f "$ZIP_FILE" && $(stat -c%s "$ZIP_FILE" 2>/dev/null || stat -f%z "$ZIP_FILE") -gt 100 ]]; then
            print_ok "Архив скачан: $ZIP_FILE"
            
            read -rp "Распаковать? [Y/n]: " UNZIP
            if [[ "${UNZIP,,}" != "n" ]]; then
                mkdir -p "$DEST_DIR"
                unzip -q "$ZIP_FILE" -d "$DEST_DIR"
                # Переместить содержимое из вложенной папки
                INNER=$(find "$DEST_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
                if [[ -n "$INNER" ]]; then
                    mv "$INNER"/* "$INNER"/.* "$DEST_DIR/" 2>/dev/null
                    rmdir "$INNER" 2>/dev/null
                fi
                print_ok "Распаковано в: $DEST_DIR"
                rm -f "$ZIP_FILE"
            fi
        else
            print_err "Ошибка скачивания архива"
        fi
        ;;
    *)
        print_err "Неизвестный метод"
        ;;
esac

# ---- Полная очистка токена из памяти ----
unset TOKEN

echo
echo "=========================================="
print_ok "Готово!"
echo "=========================================="
