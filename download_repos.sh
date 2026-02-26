#!/bin/bash

#==========================================
#  Расшифровка токена и клонирование репо
#==========================================

set -euo pipefail

# ---- НАСТРОЙКИ ----
ENCRYPTED_FILE="./github_token.enc"
YANDEX_DISK_URL="https://disk.yandex.ru/d/Dy_1IMDJm6zEzQ"
REPO=""
BRANCH="main"
DEST_DIR=""

# ---- Цвета ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
print_err()   { echo -e "${RED}[ОШИБКА]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
print_info()  { echo -e "${CYAN}[i]${NC} $1"; }

echo "=========================================="
echo "  Скачивание приватного репозитория GitHub"
echo "=========================================="
echo

# ---- Проверка зависимостей ----
for cmd in openssl git curl; do
    if ! command -v "$cmd" &>/dev/null; then
        print_err "$cmd не установлен!"
        exit 1
    fi
done

# ======================================================
#  Скачивание github_token.enc с Яндекс.Диска (если нет)
# ======================================================
if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    print_info "Файл $ENCRYPTED_FILE не найден локально"
    print_info "Скачивание с Яндекс.Диска..."
    echo

    # 1) Получаем прямую ссылку через Yandex Disk API
    API_RESPONSE=$(curl -s \
        "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=${YANDEX_DISK_URL}")

    # Извлекаем href — прямую ссылку на скачивание
    # (работает и без jq — через grep/sed)
    DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep -oP '"href"\s*:\s*"\K[^"]+')

    if [[ -z "$DOWNLOAD_URL" ]]; then
        # Попытка без -P (macOS-совместимый вариант)
        DOWNLOAD_URL=$(echo "$API_RESPONSE" | sed -n 's/.*"href" *: *"\([^"]*\)".*/\1/p')
    fi

    if [[ -z "$DOWNLOAD_URL" ]]; then
        print_err "Не удалось получить ссылку для скачивания с Яндекс.Диска"
        print_warn "Ответ API: $API_RESPONSE"
        print_warn "Скачайте файл вручную: $YANDEX_DISK_URL"
        exit 1
    fi

    # 2) Скачиваем файл
    HTTP_CODE=$(curl -L -s -w "%{http_code}" -o "$ENCRYPTED_FILE" "$DOWNLOAD_URL")

    if [[ "$HTTP_CODE" -ne 200 ]] || [[ ! -f "$ENCRYPTED_FILE" ]] || [[ ! -s "$ENCRYPTED_FILE" ]]; then
        print_err "Ошибка скачивания (HTTP $HTTP_CODE)"
        rm -f "$ENCRYPTED_FILE"
        exit 1
    fi

    FILE_SIZE=$(stat -c%s "$ENCRYPTED_FILE" 2>/dev/null || stat -f%z "$ENCRYPTED_FILE")
    print_ok "Файл скачан: $ENCRYPTED_FILE ($FILE_SIZE байт)"
else
    print_ok "Файл $ENCRYPTED_FILE найден локально"
fi

echo

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

        if git clone --branch "$BRANCH" --single-branch \
            "https://x-access-token:${TOKEN}@github.com/${REPO}.git" \
            "$DEST_DIR" 2>&1; then

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
                if ! command -v unzip &>/dev/null; then
                    print_err "unzip не установлен!"
                    exit 1
                fi
                mkdir -p "$DEST_DIR"
                unzip -q "$ZIP_FILE" -d "$DEST_DIR"
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

# ---- Очистка ----
unset TOKEN

# ---- Удаление .enc после успешного использования ----
read -rp "Удалить $ENCRYPTED_FILE? [y/N]: " DEL_ENC
if [[ "${DEL_ENC,,}" == "y" ]]; then
    rm -f "$ENCRYPTED_FILE"
    print_ok "Файл $ENCRYPTED_FILE удалён"
fi

echo
echo "=========================================="
print_ok "Готово!"
echo "=========================================="
