#!/bin/bash
# ============================================
# ПОЛНАЯ АВТОМАТИЧЕСКАЯ НАСТРОЙКА ДЛЯ ЭКЗАМЕНА
# JeOS Alt Linux - Практическая работа
# ============================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции вывода
print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }
print_info() { echo -e "${YELLOW}[i] $1${NC}"; }
print_step() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Переменные
USERNAME="myuser1"
PASSWORD="exam123"  # Пароль для пользователя
TIMEZONE="Europe/Moscow"
HOSTNAME="jeos-exam"
GUI_CHOICE="xfce4-default"  # Можно изменить: kde5, mate-default, gnome3-default и т.д.

# ============================================
# ПРОВЕРКА ПРАВ ROOT
# ============================================
check_root() {
    print_step "1. Проверка прав root"
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен запускаться с правами root!"
        print_info "Используйте: sudo $0"
        exit 1
    fi
    print_success "Запуск с правами root"
}

# ============================================
# ОБНОВЛЕНИЕ СИСТЕМЫ И ЗАМЕНА ЯДРА
# ============================================
update_system() {
    print_step "2. Обновление системы и замена ядра"
    
    print_info "Обновление репозиториев..."
    apt-get update > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        print_error "Не удалось обновить репозитории"
        print_info "Проверьте сетевое подключение"
        exit 1
    fi
    
    print_info "Обновление системы..."
    apt-get dist-upgrade -y > /dev/null 2>&1
    print_success "Система обновлена"
    
    print_info "Замена ядра на rbs-def..."
    if command -v update-kernel > /dev/null 2>&1; then
        update-kernel -t rbs-def > /dev/null 2>&1
        print_success "Ядро заменено на rbs-def"
        NEED_REBOOT=true
    else
        print_error "Команда update-kernel не найдена"
        print_info "Пропускаем замену ядра"
    fi
}

# ============================================
# СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ
# ============================================
create_user() {
    print_step "3. Создание пользователя $USERNAME"
    
    # Проверяем, существует ли пользователь
    if id "$USERNAME" &>/dev/null; then
        print_info "Пользователь $USERNAME уже существует"
        # Меняем пароль
        echo "$USERNAME:$PASSWORD" | chpasswd > /dev/null 2>&1
        print_success "Пароль обновлен"
    else
        print_info "Создание пользователя $USERNAME..."
        useradd -m -s /bin/bash "$USERNAME" > /dev/null 2>&1
        echo "$USERNAME:$PASSWORD" | chpasswd > /dev/null 2>&1
        print_success "Пользователь создан"
    fi
    
    # Добавляем в группу wheel (администраторы)
    print_info "Добавление в группу wheel..."
    if grep -q "wheel" /etc/group; then
        usermod -aG wheel "$USERNAME" > /dev/null 2>&1
        print_success "Пользователь добавлен в группу wheel"
    else
        # Создаем группу wheel если её нет
        groupadd wheel > /dev/null 2>&1
        usermod -aG wheel "$USERNAME" > /dev/null 2>&1
        
        # Настраиваем sudo для wheel
        if [[ -f /etc/sudoers ]]; then
            echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers 2>/dev/null
        fi
        print_success "Группа wheel создана и пользователь добавлен"
    fi
}

# ============================================
# УСТАНОВКА ГРАФИЧЕСКОЙ ОБОЛОЧКИ
# ============================================
install_gui() {
    print_step "4. Установка графической оболочки"
    
    # Определяем версию ядра для драйверов
    print_info "Определение версии ядра..."
    KERNEL_VERSION=$(uname -r 2>/dev/null || echo "6.6.0")
    KERNEL_CODE=$(echo "$KERNEL_VERSION" | cut -d. -f1-2 | tr -d '.')
    
    print_info "Версия ядра: $KERNEL_VERSION"
    print_info "Код драйверов: $KERNEL_CODE"
    
    # Устанавливаем базовые пакеты
    print_info "Установка базовых пакетов Xorg..."
    apt-get install -y xorg-server xinit accountsservice beesu bash-completion mc > /dev/null 2>&1
    
    # Устанавливаем драйверы для текущего ядра
    print_info "Установка видео драйверов..."
    if apt-get install -y "kernel-modules-drm-$KERNEL_CODE" > /dev/null 2>&1; then
        print_success "Драйверы установлены (kernel-modules-drm-$KERNEL_CODE)"
    else
        print_error "Не удалось установить драйверы для ядра $KERNEL_CODE"
        print_info "Пробуем найти доступные драйверы..."
        apt-cache search kernel-modules-drm | head -5
    fi
    
    # Создаем initrd
    print_info "Создание initrd..."
    if command -v make-initrd > /dev/null 2>&1; then
        make-initrd > /dev/null 2>&1
        print_success "Initrd создан"
    fi
    
    # Устанавливаем выбранную графическую оболочку
    print_info "Установка графической оболочки: $GUI_CHOICE"
    case $GUI_CHOICE in
        "kde5")
            apt-get install -y kde5 > /dev/null 2>&1
            ;;
        "mate-default")
            apt-get install -y mate-default lightdm > /dev/null 2>&1
            ;;
        "xfce4-default")
            apt-get install -y xfce4-default lightdm > /dev/null 2>&1
            ;;
        "gnome3-default")
            apt-get install -y gnome3-default lightdm > /dev/null 2>&1
            ;;
        "cinnamon-default")
            apt-get install -y cinnamon-default lightdm > /dev/null 2>&1
            ;;
        "lxde")
            apt-get install -y lxde lightdm > /dev/null 2>&1
            ;;
        *)
            print_info "Устанавливаю XFCE по умолчанию"
            apt-get install -y xfce4-default lightdm > /dev/null 2>&1
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        print_success "Графическая оболочка установлена"
    else
        print_error "Ошибка установки графической оболочки"
    fi
    
    # Настраиваем графический вход
    print_info "Настройка графического входа..."
    if systemctl set-default graphical.target > /dev/null 2>&1; then
        print_success "Графический режим установлен по умолчанию"
    else
        print_info "Использую старый метод..."
        ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target 2>/dev/null
    fi
}

# ============================================
# НАСТРОЙКА ЛОКАЛИ И ШРИФТОВ
# ============================================
setup_locale_fonts() {
    print_step "5. Настройка локали и шрифтов"
    
    # Локаль
    print_info "Настройка локали ru_RU.UTF-8..."
    echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
    localectl set-locale LANG=ru_RU.UTF-8 2>/dev/null
    print_success "Локаль настроена"
    
    # Шрифты
    print_info "Установка шрифтов..."
    apt-get install -y \
        fonts-ttf-dejavu \
        fonts-ttf-google-crosextra* \
        fonts-ttf-google-droid* \
        fonts-ttf-google-noto* \
        fonts-ttf-material-icons > /dev/null 2>&1
    print_success "Шрифты установлены"
    
    # Значки
    print_info "Установка значков..."
    apt-get install -y \
        gnome-icon-theme \
        icon-theme-breeze \
        icon-theme-hicolor \
        icon-theme-oxygen > /dev/null 2>&1
    print_success "Значки установлены"
}

# ============================================
# НАСТРОЙКА СЕТИ
# ============================================
setup_network() {
    print_step "6. Настройка сети"
    
    # Определяем сетевые интерфейсы
    print_info "Поиск сетевых интерфейсов..."
    INTERFACES=$(ip link show | grep -E '^[0-9]+:' | grep -v lo | awk -F: '{print $2}' | tr -d ' ')
    
    if [[ -z "$INTERFACES" ]]; then
        print_error "Сетевые интерфейсы не найдены"
        return 1
    fi
    
    # Берем первые два интерфейса
    IF1=$(echo "$INTERFACES" | head -1)
    IF2=$(echo "$INTERFACES" | head -2 | tail -1)
    
    print_info "Найденные интерфейсы: $INTERFACES"
    print_info "Использую: $IF1 (интернет) и $IF2 (локальная сеть)"
    
    # Пробуем netplan
    print_info "Проверка netplan..."
    if command -v netplan > /dev/null 2>&1; then
        print_info "Использую netplan для настройки сети"
        
        # Создаем конфиг netplan
        cat > /etc/netplan/50-cloud-init.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IF1:
      dhcp4: true
      dhcp6: false
      optional: true
    $IF2:
      dhcp4: false
      addresses: [172.16.10.1/24]
EOF
        
        # Применяем настройки
        if netplan apply > /dev/null 2>&1; then
            print_success "Netplan настроен"
        else
            print_error "Ошибка netplan, использую ручную настройку"
            setup_network_manual "$IF1" "$IF2"
        fi
    else
        print_info "Netplan не найден, использую ручную настройку"
        setup_network_manual "$IF1" "$IF2"
    fi
    
    # Проверка сети
    print_info "Проверка сетевого подключения..."
    sleep 3
    if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
        print_success "Интернет работает"
    else
        print_error "Нет интернет-подключения"
    fi
}

# Ручная настройка сети
setup_network_manual() {
    local if1=$1
    local if2=$2
    
    print_info "Ручная настройка интерфейсов..."
    
    # Поднимаем интерфейсы
    ip link set "$if1" up
    ip link set "$if2" up
    
    # Настраиваем DHCP на первом интерфейсе
    if command -v dhclient > /dev/null 2>&1; then
        dhclient "$if1" > /dev/null 2>&1 &
        print_info "DHCP запущен на $if1"
    fi
    
    # Настраиваем статический IP на втором интерфейсе
    ip addr add 172.16.10.1/24 dev "$if2" 2>/dev/null
    print_info "Статический IP 172.16.10.1/24 на $if2"
    
    # Сохраняем настройки в старый формат
    cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $if1
iface $if1 inet dhcp

auto $if2
iface $if2 inet static
    address 172.16.10.1
    netmask 255.255.255.0
EOF
    
    print_success "Сеть настроена вручную"
}

# ============================================
# УСТАНОВКА APACHE2
# ============================================
install_apache() {
    print_step "7. Установка Apache2"
    
    print_info "Установка Apache2..."
    apt-get install -y apache2 > /dev/null 2>&1
    
    # Запускаем и включаем автозагрузку
    if systemctl start apache2 > /dev/null 2>&1; then
        systemctl enable apache2 > /dev/null 2>&1
        print_success "Apache2 установлен и запущен"
    else
        # Пробуем старый способ
        /etc/init.d/apache2 start > /dev/null 2>&1
        print_success "Apache2 запущен (старый метод)"
    fi
    
    # Создаем тестовую страницу
    cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>JeOS Exam Setup</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Экзаменационная настройка успешно завершена!</h1>
    <p>Система JeOS Alt Linux настроена автоматически</p>
    <p>Пользователь: $USERNAME</p>
    <p>Хост: $HOSTNAME</p>
    <p>Время: $(date)</p>
</body>
</html>
EOF
    
    print_info "Тестовая страница создана"
}

# ============================================
# НАСТРОЙКА ВРЕМЕНИ И ИМЕНИ ХОСТА
# ============================================
setup_time_hostname() {
    print_step "8. Настройка времени и имени хоста"
    
    # Часовой пояс
    print_info "Установка часового пояса $TIMEZONE..."
    if command -v timedatectl > /dev/null 2>&1; then
        timedatectl set-timezone "$TIMEZONE" > /dev/null 2>&1
        print_success "Часовой пояс установлен"
    else
        # Старый метод
        ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime 2>/dev/null
        print_info "Часовой пояс установлен (старый метод)"
    fi
    
    # Имя хоста
    print_info "Установка имени хоста: $HOSTNAME"
    hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || echo "$HOSTNAME" > /etc/hostname
    echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
    
    print_success "Имя хоста установлено"
}

# ============================================
# УСТАНОВКА BASH-COMPLETION
# ============================================
install_bash_completion() {
    print_step "9. Установка bash-completion"
    
    if apt-get install -y bash-completion > /dev/null 2>&1; then
        print_success "Bash-completion установлен"
        
        # Активируем для текущей сессии
        if [[ -f /etc/bash_completion ]]; then
            . /etc/bash_completion
        fi
    else
        print_error "Не удалось установить bash-completion"
    fi
}

# ============================================
# ПРОВЕРКА И ТЕСТИРОВАНИЕ
# ============================================
final_check() {
    print_step "10. Финальная проверка"
    
    echo -e "\n${YELLOW}=== ОТЧЕТ О НАСТРОЙКЕ ===${NC}"
    
    # 1. Проверка ядра
    echo -n "Ядро: "
    if uname -r | grep -q "rbs-def"; then
        echo -e "${GREEN}$(uname -r) ✓${NC}"
    else
        echo -e "${RED}$(uname -r) ✗${NC}"
    fi
    
    # 2. Проверка пользователя
    echo -n "Пользователь $USERNAME: "
    if id "$USERNAME" &>/dev/null; then
        echo -e "${GREEN}существует ✓${NC}"
        echo -n "  В группе wheel: "
        if groups "$USERNAME" | grep -q "wheel"; then
            echo -e "${GREEN}да ✓${NC}"
        else
            echo -e "${RED}нет ✗${NC}"
        fi
    else
        echo -e "${RED}не существует ✗${NC}"
    fi
    
    # 3. Проверка сети
    echo -n "Сеть: "
    if ip addr show | grep -q "172.16.10.1"; then
        echo -e "${GREEN}локальная сеть настроена ✓${NC}"
    else
        echo -e "${RED}локальная сеть не настроена ✗${NC}"
    fi
    
    # 4. Проверка Apache
    echo -n "Apache2: "
    if systemctl is-active --quiet apache2 2>/dev/null || pgrep apache2 > /dev/null; then
        echo -e "${GREEN}работает ✓${NC}"
    else
        echo -e "${RED}не работает ✗${NC}"
    fi
    
    # 5. Проверка времени
    echo -n "Часовой пояс: "
    if timedatectl 2>/dev/null | grep -q "Moscow"; then
        echo -e "${GREEN}Europe/Moscow ✓${NC}"
    elif date +%Z | grep -q "MSK"; then
        echo -e "${GREEN}MSK ✓${NC}"
    else
        echo -e "${RED}не настроен ✗${NC}"
    fi
    
    # 6. Проверка GUI пакетов
    echo -n "Графическая оболочка: "
    if dpkg -l | grep -q "$GUI_CHOICE"; then
        echo -e "${GREEN}$GUI_CHOICE установлена ✓${NC}"
    else
        echo -e "${YELLOW}проверьте установку GUI${NC}"
    fi
    
    echo -e "\n${GREEN}=== КРАТКАЯ ИНФОРМАЦИЯ ===${NC}"
    echo "Для входа в систему используйте:"
    echo "  Логин: $USERNAME"
    echo "  Пароль: $PASSWORD"
    echo "  Имя хоста: $HOSTNAME"
    echo ""
    echo "Проверьте веб-сервер: curl http://localhost"
    
    if [[ "$NEED_REBOOT" == true ]]; then
        echo -e "\n${RED}⚠ ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА! ⚠${NC}"
        echo "Выполните: reboot"
    fi
}

# ============================================
# ОСНОВНОЙ ПРОЦЕСС
# ============================================

main() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║    АВТОМАТИЧЕСКАЯ НАСТРОЙКА ДЛЯ ЭКЗАМЕНА  ║"
    echo "║         JeOS Alt Linux - Практика        ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Выполняем все шаги
    check_root
    update_system
    create_user
    install_gui
    setup_locale_fonts
    setup_network
    install_apache
    setup_time_hostname
    install_bash_completion
    final_check
    
    echo -e "\n${GREEN}✅ Настройка завершена!${NC}"
    echo -e "${YELLOW}Логи сохранены в: /var/log/exam-setup.log${NC}"
    
    # Сохраняем лог
    echo "Настройка завершена: $(date)" > /var/log/exam-setup.log
}

# ============================================
# ЗАПУСК
# ============================================

# Запускаем основной процесс и логируем вывод
main 2>&1 | tee -a /var/log/exam-setup.log

# Выход с кодом успеха
exit 0
