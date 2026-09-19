```bash
#!/usr/bin/env bash

set -Eeuo pipefail

############################################
# SKLauncher Linux Installer
# Fedora / Arch / CachyOS / Debian / Ubuntu
############################################

APP_NAME="SKLauncher Linux Installer"

INSTALL_DIR="$HOME/.local/share/skinstaller"
DESKTOP_DIR="$HOME/.local/share/applications"

DESKTOP_FILE="$DESKTOP_DIR/sklauncher-installer.desktop"

JAR_FILE="$INSTALL_DIR/SKlauncher.jar"
ICON_FILE="$INSTALL_DIR/minecraft.png"
LAUNCHER_SCRIPT="$INSTALL_DIR/sklauncher.sh"

ICON_URL="https://raw.githubusercontent.com/eltonnikecasa/SKLauncher-Linux-Installer/main/assets/minecraft.png"

TEMP_DIR="${TMPDIR:-/tmp}/sklauncher-installer"

DOWNLOAD_PAGE="https://skmedix.pl/downloads"

FALLBACK_VERSION="3.2.18"

############################################
# CORES
############################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

############################################
# VARIÁVEIS
############################################

DISTRO=""
DISTRO_NAME=""
DISTRO_FAMILY=""
PKG_MANAGER=""

LATEST_VERSION=""
SKL_URL=""

GUI_AVAILABLE=false

############################################
# LOG
############################################

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

############################################
# ERROS
############################################

show_error() {
    local message="$1"

    error "$message"

    if command -v zenity >/dev/null 2>&1 && \
       { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then

        zenity \
            --error \
            --title="$APP_NAME" \
            --width=450 \
            --text="$message" \
            2>/dev/null || true
    fi
}

fatal() {
    show_error "$1"
    exit 1
}

trap 'fatal "A instalação foi interrompida devido a um erro inesperado na linha $LINENO."' ERR

############################################
# DETECTAR SISTEMA
############################################

detect_system() {

    if [ ! -f /etc/os-release ]; then
        fatal "Não foi possível detectar a distribuição Linux."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    DISTRO="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO}"

    local distro_like="${ID_LIKE:-}"

    case "$DISTRO" in

        fedora)
            DISTRO_FAMILY="fedora"
            ;;

        cachyos|arch|endeavouros|manjaro)
            DISTRO_FAMILY="arch"
            ;;

        debian|ubuntu|linuxmint|pop|zorin)
            DISTRO_FAMILY="debian"
            ;;

        *)
            if [[ "$distro_like" == *"fedora"* ]]; then
                DISTRO_FAMILY="fedora"

            elif [[ "$distro_like" == *"arch"* ]]; then
                DISTRO_FAMILY="arch"

            elif [[ "$distro_like" == *"debian"* ]] || \
                 [[ "$distro_like" == *"ubuntu"* ]]; then
                DISTRO_FAMILY="debian"

            else
                fatal "Distribuição não suportada: $DISTRO_NAME"
            fi
            ;;
    esac

    case "$DISTRO_FAMILY" in

        fedora)

            if command -v dnf5 >/dev/null 2>&1; then
                PKG_MANAGER="dnf5"

            elif command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"

            else
                fatal "DNF não foi encontrado no sistema."
            fi
            ;;

        arch)

            if command -v paru >/dev/null 2>&1; then
                PKG_MANAGER="paru"

            elif command -v pacman >/dev/null 2>&1; then
                PKG_MANAGER="pacman"

            else
                fatal "Pacman não foi encontrado no sistema."
            fi
            ;;

        debian)

            if command -v apt-get >/dev/null 2>&1; then
                PKG_MANAGER="apt"

            else
                fatal "APT não foi encontrado no sistema."
            fi
            ;;
    esac

    info "Sistema detectado: $DISTRO_NAME"
    info "Família: $DISTRO_FAMILY"
    info "Gerenciador: $PKG_MANAGER"
}

############################################
# VALIDAR AMBIENTE GRÁFICO
############################################

has_graphical_session() {

    [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]
}

############################################
# VALIDAR SUDO
############################################

validate_sudo() {

    info "Validando permissões sudo..."

    if ! sudo -v; then
        fatal "Permissões sudo são necessárias para instalar as dependências."
    fi

    success "Sudo validado"
}

############################################
# INSTALAR ZENITY
############################################

install_zenity() {

    if command -v zenity >/dev/null 2>&1; then
        GUI_AVAILABLE=true
        return
    fi

    if ! has_graphical_session; then
        warning "Nenhuma sessão gráfica detectada."
        warning "O instalador continuará pelo terminal."
        return
    fi

    info "Zenity não encontrado."
    info "Instalando interface gráfica..."

    validate_sudo

    case "$DISTRO_FAMILY" in

        fedora)

            sudo "$PKG_MANAGER" install -y zenity
            ;;

        arch)

            if [ "$PKG_MANAGER" = "paru" ]; then
                paru -S --needed --noconfirm zenity
            else
                sudo pacman -S --needed --noconfirm zenity
            fi
            ;;

        debian)

            sudo apt-get update
            sudo apt-get install -y zenity
            ;;
    esac

    if command -v zenity >/dev/null 2>&1; then
        GUI_AVAILABLE=true
        success "Zenity instalado"
    else
        warning "Não foi possível instalar Zenity."
        warning "Continuando pelo terminal."
    fi
}

############################################
# INTERNET
############################################

check_internet() {

    info "Verificando conexão com a internet..."

    if command -v curl >/dev/null 2>&1; then

        if curl \
            --silent \
            --fail \
            --location \
            --connect-timeout 10 \
            --max-time 15 \
            --output /dev/null \
            "$DOWNLOAD_PAGE"; then

            success "Internet OK"
            return
        fi

    elif command -v wget >/dev/null 2>&1; then

        if wget \
            --quiet \
            --timeout=15 \
            --spider \
            "$DOWNLOAD_PAGE"; then

            success "Internet OK"
            return
        fi

    else
        warning "curl/wget ainda não estão instalados."
        return
    fi

    fatal "Não foi possível acessar o servidor do SKLauncher. Verifique sua conexão com a internet."
}

############################################
# INSTALAR DEPENDÊNCIAS
############################################

install_dependencies() {

    info "Verificando dependências..."

    validate_sudo

    case "$DISTRO_FAMILY" in

        fedora)

            sudo "$PKG_MANAGER" install -y \
                java-21-openjdk \
                java-21-openjdk-devel \
                curl \
                wget \
                desktop-file-utils
            ;;

        arch)

            if [ "$PKG_MANAGER" = "paru" ]; then

                paru -S --needed --noconfirm \
                    jdk21-openjdk \
                    curl \
                    wget \
                    desktop-file-utils

            else

                sudo pacman -S --needed --noconfirm \
                    jdk21-openjdk \
                    curl \
                    wget \
                    desktop-file-utils
            fi
            ;;

        debian)

            sudo apt-get update

            sudo apt-get install -y \
                openjdk-21-jdk \
                curl \
                wget \
                desktop-file-utils
            ;;
    esac
}

############################################
# DETECTAR JAVA
############################################

get_java_major_version() {

    if ! command -v java >/dev/null 2>&1; then
        echo "0"
        return
    fi

    java -version 2>&1 |
        awk -F '"' '/version/ {
            split($2, version, ".");
            if (version[1] == "1") {
                print version[2]
            } else {
                print version[1]
            }
            exit
        }'
}

############################################
# CONFIGURAR JAVA 21 NO ARCH
############################################

configure_arch_java() {

    [ "$DISTRO_FAMILY" = "arch" ] || return

    if ! command -v archlinux-java >/dev/null 2>&1; then
        return
    fi

    local java_env

    java_env="$(
        archlinux-java status 2>/dev/null |
        sed 's/^[[:space:]]*//' |
        grep '^java-21-' |
        head -n1 |
        awk '{print $1}'
    )"

    if [ -n "$java_env" ]; then
        info "Configurando Java 21 como padrão: $java_env"
        sudo archlinux-java set "$java_env"
    fi
}

############################################
# VALIDAR JAVA
############################################

ensure_java() {

    local java_major

    java_major="$(get_java_major_version)"

    if [ "$java_major" != "21" ]; then

        warning "Java 21 não está ativo."

        install_dependencies
        configure_arch_java

        java_major="$(get_java_major_version)"
    fi

    if [ "$java_major" != "21" ]; then
        fatal "Java 21 foi instalado, mas não pôde ser ativado corretamente."
    fi

    JAVA_VERSION="$(java -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"

    success "Java detectado: $JAVA_VERSION"
}

############################################
# OBTER PÁGINA
############################################

download_page_content() {

    if command -v curl >/dev/null 2>&1; then

        curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 15 \
            "$DOWNLOAD_PAGE"

    elif command -v wget >/dev/null 2>&1; then

        wget \
            --quiet \
            --timeout=20 \
            -O - \
            "$DOWNLOAD_PAGE"

    else
        return 1
    fi
}

############################################
# DETECTAR VERSÃO
############################################

detect_latest_version() {

    info "Detectando versão mais recente do SKLauncher..."

    local page_content

    page_content="$(download_page_content || true)"

    LATEST_VERSION="$(
        printf '%s' "$page_content" |
        grep -oE 'SKlauncher-[0-9]+\.[0-9]+\.[0-9]+\.jar' |
        head -n1 |
        sed 's/SKlauncher-//' |
        sed 's/\.jar//' || true
    )"

    if [ -z "$LATEST_VERSION" ]; then

        warning "Não foi possível detectar automaticamente a versão mais recente."
        warning "Usando versão fallback $FALLBACK_VERSION"

        LATEST_VERSION="$FALLBACK_VERSION"
    fi

    SKL_URL="https://skmedix.pl/binaries/skl/${LATEST_VERSION}/SKlauncher-${LATEST_VERSION}.jar"

    success "Versão detectada: $LATEST_VERSION"
}

############################################
# CRIAR DIRETÓRIOS
############################################

create_directories() {

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DESKTOP_DIR"

    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
}

############################################
# VALIDAR JAR
############################################

jar_is_valid() {

    [ -s "$JAR_FILE" ] || return 1

    if command -v jar >/dev/null 2>&1; then
        jar tf "$JAR_FILE" >/dev/null 2>&1
    else
        return 0
    fi
}

############################################
# DOWNLOAD COM PROGRESSO
############################################

download_launcher() {

    if jar_is_valid; then

        success "Launcher válido encontrado."

        return
    fi

    rm -f "$JAR_FILE"

    info "Baixando SKLauncher $LATEST_VERSION..."

    if command -v curl >/dev/null 2>&1; then

        curl \
            --fail \
            --location \
            --show-error \
            --progress-bar \
            --output "$JAR_FILE" \
            "$SKL_URL"

    else

        wget \
            --show-progress \
            -O "$JAR_FILE" \
            "$SKL_URL"
    fi

    if ! jar_is_valid; then

        rm -f "$JAR_FILE"

        fatal "O arquivo do SKLauncher baixado é inválido ou está corrompido."
    fi

    success "SKLauncher baixado"
}

############################################
# BAIXAR ÍCONE
############################################

download_icon() {

    info "Baixando ícone..."

    if command -v curl >/dev/null 2>&1; then

        curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --output "$ICON_FILE" \
            "$ICON_URL"

    else

        wget \
            --quiet \
            -O "$ICON_FILE" \
            "$ICON_URL"
    fi

    success "Ícone instalado"
}

############################################
# CRIAR SCRIPT DE EXECUÇÃO
############################################

create_launcher_script() {

    info "Criando inicializador..."

    cat > "$LAUNCHER_SCRIPT" <<EOF
#!/usr/bin/env bash

JAR_FILE="$JAR_FILE"

if [ ! -f "\$JAR_FILE" ]; then

    if command -v zenity >/dev/null 2>&1; then
        zenity \
            --error \
            --title="SKLauncher" \
            --text="SKLauncher não foi encontrado.\nExecute novamente o instalador."
    fi

    exit 1
fi

exec java -jar "\$JAR_FILE"
EOF

    chmod +x "$LAUNCHER_SCRIPT"
}

############################################
# CRIAR DESKTOP FILE
############################################

create_desktop_file() {

    info "Criando atalho do sistema..."

    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=SKLauncher Minecraft
Comment=Minecraft Launcher
Exec=$LAUNCHER_SCRIPT
Icon=$ICON_FILE
Terminal=false
Categories=Game;
StartupNotify=true
EOF

    chmod +x "$DESKTOP_FILE"
}

############################################
# ATUALIZAR MENU
############################################

update_desktop_cache() {

    info "Atualizando menu de aplicações..."

    if command -v update-desktop-database >/dev/null 2>&1; then

        update-desktop-database "$DESKTOP_DIR" \
            >/dev/null 2>&1 || true
    fi

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 >/dev/null 2>&1 || true
    fi

    if command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 >/dev/null 2>&1 || true
    fi
}

############################################
# REMOVER
############################################

remove_installation() {

    if [ "$GUI_AVAILABLE" = true ]; then

        if ! zenity \
            --question \
            --title="$APP_NAME" \
            --width=420 \
            --text="Deseja remover o SKLauncher instalado por este instalador?"; then

            exit 0
        fi
    fi

    info "Removendo SKLauncher..."

    rm -f "$DESKTOP_FILE"
    rm -rf "$INSTALL_DIR"

    update_desktop_cache

    success "Remoção concluída."

    if [ "$GUI_AVAILABLE" = true ]; then

        zenity \
            --info \
            --title="$APP_NAME" \
            --width=400 \
            --text="SKLauncher removido com sucesso.\n\nO script do instalador foi preservado."
    fi
}

############################################
# TELA INICIAL
############################################

show_welcome() {

    [ "$GUI_AVAILABLE" = true ] || return

    zenity \
        --info \
        --title="$APP_NAME" \
        --width=480 \
        --height=250 \
        --text="<b>SKLauncher Linux Installer</b>

Sistema detectado:
<b>$DISTRO_NAME</b>

Este instalador irá:

• verificar as dependências
• instalar/verificar Java 21
• detectar a versão do SKLauncher
• baixar o launcher oficial
• instalar o ícone
• criar o atalho no menu de aplicações"
}

############################################
# INSTALAÇÃO INTERNA
############################################

perform_installation() {

    echo "5"
    echo "# Preparando diretórios..."

    create_directories

    echo "15"
    echo "# Instalando e verificando dependências..."

    install_dependencies

    echo "30"
    echo "# Verificando Java 21..."

    configure_arch_java
    ensure_java

    echo "40"
    echo "# Verificando conexão com a internet..."

    check_internet

    echo "50"
    echo "# Detectando versão mais recente..."

    detect_latest_version

    echo "60"
    echo "# Baixando SKLauncher $LATEST_VERSION..."

    download_launcher

    echo "80"
    echo "# Instalando ícone..."

    download_icon

    echo "88"
    echo "# Criando inicializador..."

    create_launcher_script

    echo "93"
    echo "# Criando atalho..."

    create_desktop_file

    echo "97"
    echo "# Atualizando menu de aplicações..."

    update_desktop_cache

    echo "100"
    echo "# Instalação concluída."

    sleep 1
}

############################################
# INSTALAÇÃO GRÁFICA
############################################

graphical_installation() {

    local fifo
    local status_file

    fifo="$TEMP_DIR/progress.fifo"
    status_file="$TEMP_DIR/install.status"

    rm -f "$fifo" "$status_file"

    mkfifo "$fifo"

    (
        set +e

        perform_installation > "$fifo"

        status=$?

        echo "$status" > "$status_file"

        exit "$status"

    ) &

    local worker_pid=$!

    set +e

    zenity \
        --progress \
        --title="$APP_NAME" \
        --width=520 \
        --height=140 \
        --percentage=0 \
        --auto-close \
        --no-cancel \
        < "$fifo"

    local zenity_status=$?

    wait "$worker_pid"
    local worker_status=$?

    set -e

    rm -f "$fifo"

    if [ "$worker_status" -ne 0 ]; then

        fatal "A instalação não pôde ser concluída. Execute o instalador pelo terminal para visualizar os detalhes."
    fi

    if [ "$zenity_status" -ne 0 ]; then
        warning "A janela de progresso foi fechada."
    fi
}

############################################
# INSTALAÇÃO TERMINAL
############################################

terminal_installation() {

    perform_installation
}

############################################
# FINALIZAÇÃO
############################################

finish_installation() {

    success "SKLauncher $LATEST_VERSION instalado com sucesso."

    if [ "$GUI_AVAILABLE" = true ]; then

        if zenity \
            --question \
            --title="$APP_NAME" \
            --width=450 \
            --text="<b>Instalação concluída!</b>

SKLauncher $LATEST_VERSION foi instalado com sucesso.

Deseja executar o SKLauncher agora?" \
            --ok-label="Executar" \
            --cancel-label="Fechar"; then

            "$LAUNCHER_SCRIPT" >/dev/null 2>&1 &
        fi

    else

        echo
        info "Para executar:"
        echo "$LAUNCHER_SCRIPT"
        echo

        read -r -p "Deseja executar o SKLauncher agora? [S/n] " answer

        case "${answer:-S}" in
            s|S|sim|SIM|Sim)
                "$LAUNCHER_SCRIPT"
                ;;
        esac
    fi
}

############################################
# MAIN
############################################

main() {

    detect_system

    ########################################
    # PREPARAR GUI
    ########################################

    install_zenity

    ########################################
    # REMOÇÃO
    ########################################

    case "${1:-}" in

        -remove|--remove|-r|remove|uninstall)

            remove_installation
            exit 0
            ;;
    esac

    ########################################
    # TELA INICIAL
    ########################################

    show_welcome

    ########################################
    # PREPARAR TEMP
    ########################################

    mkdir -p "$TEMP_DIR"

    ########################################
    # INSTALAR
    ########################################

    if [ "$GUI_AVAILABLE" = true ]; then
        graphical_installation
    else
        terminal_installation
    fi

    ########################################
    # FINALIZAR
    ########################################

    finish_installation
}

main "$@"
```
