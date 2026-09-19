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

JAVA_DIR="$INSTALL_DIR/java"
JAVA_BIN="$JAVA_DIR/bin/java"
JAR_BIN="$JAVA_DIR/bin/jar"

ICON_URL="https://raw.githubusercontent.com/eltonnikecasa/SKLauncher-Linux-Installer/main/assets/minecraft.png"
DOWNLOAD_PAGE="https://skmedix.pl/downloads"
FALLBACK_VERSION="3.2.18"

TEMURIN_MAJOR="21"
ADOPTIUM_API="https://api.adoptium.net/v3"

TEMP_DIR="${TMPDIR:-/tmp}/sklauncher-installer"
LOG_FILE="$TEMP_DIR/install.log"
PROGRESS_FIFO="$TEMP_DIR/progress.fifo"
ASKPASS_FILE="$TEMP_DIR/askpass.sh"

DISTRO=""
DISTRO_NAME=""
DISTRO_FAMILY=""
PKG_MANAGER=""
LATEST_VERSION=""
SKL_URL=""
TEMURIN_ARCH=""
GUI_AVAILABLE=false
SUDO_KEEPALIVE_PID=""
LOG_WINDOW_PID=""

############################################
# CORES
############################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

############################################
# LOG
############################################

timestamp() {
    date '+%H:%M:%S'
}

log_line() {
    local level="$1"
    shift
    local message="$*"

    mkdir -p "$TEMP_DIR"
    printf '[%s] [%s] %s\n' "$(timestamp)" "$level" "$message" >> "$LOG_FILE"

    case "$level" in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" >&2 ;;
        OK)    echo -e "${GREEN}[OK]${NC} $message" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" >&2 ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        *)     echo "[$level] $message" >&2 ;;
    esac
}

info()    { log_line INFO "$@"; }
success() { log_line OK "$@"; }
warning() { log_line WARN "$@"; }
error()   { log_line ERROR "$@"; }

run_logged() {
    info "Executando: $*"
    "$@" >>"$LOG_FILE" 2>&1
}

############################################
# PROGRESSO
############################################

progress() {
    local percent="$1"
    shift
    local message="$*"

    info "$message"

    if [ -p "$PROGRESS_FIFO" ]; then
        printf '%s\n# %s\n' "$percent" "$message" > "$PROGRESS_FIFO" || true
    fi
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
            --width=500 \
            --text="$message

Log:
$LOG_FILE" \
            2>/dev/null || true
    fi
}

fatal() {
    show_error "$1"
    exit 1
}

on_error() {
    local line="$1"
    local code="$2"

    trap - ERR
    fatal "A instalação foi interrompida por um erro na linha $line (código $code)."
}

trap 'on_error "$LINENO" "$?"' ERR

############################################
# LIMPEZA
############################################

cleanup() {
    if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    fi

    if [ -n "${LOG_WINDOW_PID:-}" ]; then
        kill "$LOG_WINDOW_PID" >/dev/null 2>&1 || true
    fi

    rm -f "$PROGRESS_FIFO" "$ASKPASS_FILE" >/dev/null 2>&1 || true
}

trap cleanup EXIT

prepare_temp() {
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    : > "$LOG_FILE"
}

############################################
# AMBIENTE GRÁFICO
############################################

has_graphical_session() {
    [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]
}

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
        cachyos|arch|endeavouros|manjaro|garuda)
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
            elif [[ "$distro_like" == *"debian"* ]] || [[ "$distro_like" == *"ubuntu"* ]]; then
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
# DEPENDÊNCIA DA GUI
############################################

bootstrap_zenity() {
    if command -v zenity >/dev/null 2>&1; then
        GUI_AVAILABLE=true
        return
    fi

    if ! has_graphical_session; then
        warning "Nenhuma sessão gráfica detectada. O instalador continuará pelo terminal."
        return
    fi

    warning "Zenity não está instalado. A primeira autenticação poderá ocorrer no terminal somente para instalar a interface gráfica."

    case "$DISTRO_FAMILY" in
        fedora)
            sudo "$PKG_MANAGER" install -y zenity
            ;;
        arch)
            sudo pacman -S --needed --noconfirm zenity
            ;;
        debian)
            sudo apt-get update
            sudo apt-get install -y zenity
            ;;
    esac

    if command -v zenity >/dev/null 2>&1; then
        GUI_AVAILABLE=true
        success "Zenity instalado."
    else
        warning "Zenity não pôde ser instalado. Continuando pelo terminal."
    fi
}

############################################
# SENHA ADMINISTRATIVA NA INTERFACE
############################################

setup_graphical_sudo() {
    if [ "$GUI_AVAILABLE" != true ]; then
        info "Validando permissões administrativas..."
        sudo -v || fatal "Permissões administrativas são necessárias."
        return
    fi

    cat > "$ASKPASS_FILE" <<'EOF'
#!/usr/bin/env bash
exec zenity \
    --password \
    --title="SKLauncher Linux Installer" \
    --text="Digite sua senha administrativa para continuar:"
EOF

    chmod 700 "$ASKPASS_FILE"

    export SUDO_ASKPASS="$ASKPASS_FILE"

    info "Solicitando autenticação administrativa..."

    if ! sudo -A -v; then
        fatal "Não foi possível validar a senha administrativa."
    fi

    success "Autenticação administrativa validada."

    # Mantém o timestamp do sudo válido enquanto o instalador estiver aberto.
    (
        while true; do
            sudo -n -v >/dev/null 2>&1 || exit
            sleep 50
        done
    ) &

    SUDO_KEEPALIVE_PID=$!
}

############################################
# ARQUITETURA TEMURIN
############################################

detect_temurin_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            TEMURIN_ARCH="x64"
            ;;
        aarch64|arm64)
            TEMURIN_ARCH="aarch64"
            ;;
        *)
            fatal "Arquitetura não suportada para o Temurin 21: $(uname -m)"
            ;;
    esac

    info "Arquitetura Temurin: $TEMURIN_ARCH"
}

############################################
# DEPENDÊNCIAS
############################################

missing_commands() {
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v tar >/dev/null 2>&1 || missing+=("tar")

    printf '%s\n' "${missing[@]:-}"
}

install_dependencies() {
    local missing
    missing="$(missing_commands)"

    if [ -z "$missing" ]; then
        success "Dependências essenciais já estão instaladas."
        return
    fi

    info "Instalando dependências ausentes: $(echo "$missing" | tr '\n' ' ')"

    case "$DISTRO_FAMILY" in
        fedora)
            run_logged sudo "$PKG_MANAGER" install -y curl tar wget desktop-file-utils
            ;;
        arch)
            run_logged sudo pacman -S --needed --noconfirm curl tar wget desktop-file-utils
            ;;
        debian)
            run_logged sudo apt-get update
            run_logged sudo apt-get install -y curl tar wget desktop-file-utils
            ;;
    esac

    command -v curl >/dev/null 2>&1 || fatal "curl não pôde ser instalado."
    command -v tar >/dev/null 2>&1 || fatal "tar não pôde ser instalado."

    success "Dependências instaladas."
}

############################################
# INTERNET
############################################

check_internet() {
    info "Verificando conexão com a internet..."

    if curl \
        --silent \
        --fail \
        --location \
        --connect-timeout 10 \
        --max-time 20 \
        --output /dev/null \
        "https://api.adoptium.net/"; then

        success "Internet OK."
        return
    fi

    fatal "Não foi possível acessar a internet ou a API do Adoptium."
}

############################################
# TEMURIN 21
############################################

temurin_is_valid() {
    [ -x "$JAVA_BIN" ] || return 1

    local major
    major="$("$JAVA_BIN" -version 2>&1 | awk -F '"' '/version/ {split($2,v,"."); print v[1]; exit}')"

    [ "$major" = "$TEMURIN_MAJOR" ]
}

install_temurin() {
    if temurin_is_valid; then
        local version
        version="$("$JAVA_BIN" -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"
        success "Temurin já instalado: Java $version"
        return
    fi

    progress 30 "Baixando Eclipse Temurin 21..."

    local archive="$TEMP_DIR/temurin21.tar.gz"
    local extract_dir="$TEMP_DIR/temurin-extract"
    local url

    url="${ADOPTIUM_API}/binary/latest/${TEMURIN_MAJOR}/ga/linux/${TEMURIN_ARCH}/jdk/hotspot/normal/eclipse?project=jdk"

    info "Fonte do Java: Eclipse Adoptium Temurin ${TEMURIN_MAJOR}"
    info "Baixando JDK para linux/${TEMURIN_ARCH}..."

    curl \
        --fail \
        --location \
        --show-error \
        --retry 3 \
        --connect-timeout 20 \
        --output "$archive" \
        "$url" >>"$LOG_FILE" 2>&1

    [ -s "$archive" ] || fatal "O download do Temurin 21 retornou um arquivo vazio."

    local archive_size
    archive_size="$(du -h "$archive" | awk '{print $1}')"
    success "Download do Temurin concluído: $archive_size"

    progress 40 "Preparando extração do Eclipse Temurin 21..."

    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    info "Diretório temporário de extração: $extract_dir"
    info "Iniciando extração do Temurin 21. Isso pode levar alguns segundos..."

    progress 43 "Extraindo Eclipse Temurin 21..."

    if ! tar -xzf "$archive" -C "$extract_dir" >>"$LOG_FILE" 2>&1; then
        fatal "Falha ao extrair o Eclipse Temurin 21. O download pode estar incompleto ou corrompido."
    fi

    success "Arquivos do Temurin 21 extraídos com sucesso."
    progress 48 "Localizando o JDK extraído..."

    local extracted
    extracted="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)"

    [ -n "$extracted" ] || fatal "Não foi possível localizar o JDK extraído."

    info "JDK extraído encontrado em: $extracted"

    progress 50 "Instalando Eclipse Temurin 21..."

    rm -rf "$JAVA_DIR"
    mv "$extracted" "$JAVA_DIR"

    if ! temurin_is_valid; then
        fatal "O Temurin foi baixado e extraído, mas a validação do Java 21 falhou."
    fi

    local version
    version="$("$JAVA_BIN" -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"

    success "Eclipse Temurin instalado: Java $version"
}

############################################
# SKLAUNCHER - VERSÃO
############################################

detect_latest_version() {
    info "Detectando versão mais recente do SKLauncher..."

    local page_content

    page_content="$(
        curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 15 \
            "$DOWNLOAD_PAGE" || true
    )"

    LATEST_VERSION="$(
        printf '%s' "$page_content" |
        grep -oE 'SKlauncher-[0-9]+\.[0-9]+\.[0-9]+\.jar' |
        head -n1 |
        sed 's/SKlauncher-//' |
        sed 's/\.jar//' || true
    )"

    if [ -z "$LATEST_VERSION" ]; then
        warning "Não foi possível detectar automaticamente a versão mais recente."
        warning "Usando versão fallback $FALLBACK_VERSION."
        LATEST_VERSION="$FALLBACK_VERSION"
    fi

    SKL_URL="https://skmedix.pl/binaries/skl/${LATEST_VERSION}/SKlauncher-${LATEST_VERSION}.jar"

    success "Versão detectada: $LATEST_VERSION"
}

############################################
# DIRETÓRIOS
############################################

create_directories() {
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DESKTOP_DIR"
}

############################################
# VALIDAR JAR
############################################

jar_is_valid() {
    [ -s "$JAR_FILE" ] || return 1
    [ -x "$JAR_BIN" ] || return 1

    "$JAR_BIN" tf "$JAR_FILE" >/dev/null 2>&1
}

############################################
# DOWNLOAD SKLAUNCHER
############################################

download_launcher() {
    if jar_is_valid; then
        success "Launcher válido encontrado."
        return
    fi

    rm -f "$JAR_FILE"

    info "Baixando SKLauncher $LATEST_VERSION..."

    curl \
        --fail \
        --location \
        --show-error \
        --retry 3 \
        --connect-timeout 20 \
        --output "$JAR_FILE" \
        "$SKL_URL" >>"$LOG_FILE" 2>&1

    if ! jar_is_valid; then
        rm -f "$JAR_FILE"
        fatal "O arquivo do SKLauncher baixado é inválido ou está corrompido."
    fi

    success "SKLauncher baixado e validado."
}

############################################
# ÍCONE
############################################

download_icon() {
    info "Baixando ícone..."

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 3 \
        --output "$ICON_FILE" \
        "$ICON_URL" >>"$LOG_FILE" 2>&1

    success "Ícone instalado."
}

############################################
# SCRIPT DE EXECUÇÃO
############################################

create_launcher_script() {
    info "Criando inicializador..."

    cat > "$LAUNCHER_SCRIPT" <<EOF
#!/usr/bin/env bash

JAVA_BIN="$JAVA_BIN"
JAR_FILE="$JAR_FILE"

if [ ! -x "\$JAVA_BIN" ]; then
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="SKLauncher" --text="Java Temurin 21 não foi encontrado.\nExecute novamente o instalador."
    fi
    exit 1
fi

if [ ! -f "\$JAR_FILE" ]; then
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="SKLauncher" --text="SKLauncher não foi encontrado.\nExecute novamente o instalador."
    fi
    exit 1
fi

exec "\$JAVA_BIN" -jar "\$JAR_FILE"
EOF

    chmod +x "$LAUNCHER_SCRIPT"
    success "Inicializador criado."
}

############################################
# DESKTOP FILE
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
    success "Atalho criado."
}

############################################
# CACHE DO DESKTOP
############################################

update_desktop_cache() {
    info "Atualizando menu de aplicações..."

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" >>"$LOG_FILE" 2>&1 || true
    fi

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 >>"$LOG_FILE" 2>&1 || true
    fi

    if command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 >>"$LOG_FILE" 2>&1 || true
    fi

    success "Menu de aplicações atualizado."
}

############################################
# REMOVER
############################################

remove_installation() {
    if [ "$GUI_AVAILABLE" = true ]; then
        if ! zenity \
            --question \
            --title="$APP_NAME" \
            --width=450 \
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
            --width=420 \
            --text="SKLauncher removido com sucesso.

O script do instalador foi preservado." \
            2>/dev/null || true
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
        --width=500 \
        --height=300 \
        --text="<b>SKLauncher Linux Installer</b>

Sistema detectado:
<b>$DISTRO_NAME</b>

Java:
<b>Eclipse Temurin 21</b>

O instalador solicitará a senha administrativa agora e depois iniciará a instalação.

Durante a instalação serão exibidos:
• barra de progresso
• log em tempo real
• download e validação do Java
• download e validação do SKLauncher" \
        2>/dev/null || true
}

############################################
# JANELA DE LOG
############################################

start_log_window() {
    [ "$GUI_AVAILABLE" = true ] || return

    (
        tail --pid="$$" -n +1 -F "$LOG_FILE" 2>/dev/null |
        while IFS= read -r line; do
            line="${line//&/&amp;}"
            line="${line//</&lt;}"
            line="${line//>/&gt;}"
            printf '# %s\n' "$line"
        done |
        zenity \
            --progress \
            --pulsate \
            --no-cancel \
            --title="$APP_NAME — Andamento da instalação" \
            --width=760 \
            --height=120 \
            --text="Iniciando instalação..." \
            2>/dev/null || true
    ) &

    LOG_WINDOW_PID=$!
}

stop_log_window() {
    if [ -n "${LOG_WINDOW_PID:-}" ]; then
        kill "$LOG_WINDOW_PID" >/dev/null 2>&1 || true
        wait "$LOG_WINDOW_PID" >/dev/null 2>&1 || true
        LOG_WINDOW_PID=""
    fi
}
############################################
# INSTALAÇÃO
############################################

perform_installation() {
    progress 5 "Preparando diretórios..."
    create_directories

    progress 10 "Verificando dependências..."
    install_dependencies

    progress 18 "Verificando conexão com a internet..."
    check_internet

    progress 22 "Detectando arquitetura..."
    detect_temurin_arch

    progress 25 "Verificando Eclipse Temurin 21..."
    install_temurin

    progress 52 "Detectando versão do SKLauncher..."
    detect_latest_version

    progress 60 "Baixando SKLauncher $LATEST_VERSION..."
    download_launcher

    progress 80 "Instalando ícone..."
    download_icon

    progress 87 "Criando inicializador..."
    create_launcher_script

    progress 92 "Criando atalho..."
    create_desktop_file

    progress 97 "Atualizando menu de aplicações..."
    update_desktop_cache

    progress 100 "Instalação concluída."
    sleep 1
}

############################################
# INSTALAÇÃO GRÁFICA
############################################

graphical_installation() {
    rm -f "$PROGRESS_FIFO"
    mkfifo "$PROGRESS_FIFO"

    start_log_window

    (
        set +e
        perform_installation
        status=$?
        printf '%s\n# Finalizando...\n' "100" > "$PROGRESS_FIFO" 2>/dev/null || true
        exit "$status"
    ) &

    local worker_pid=$!

    set +e

    zenity \
        --progress \
        --title="$APP_NAME" \
        --width=560 \
        --height=160 \
        --percentage=0 \
        --auto-close \
        --no-cancel \
        < "$PROGRESS_FIFO" \
        2>/dev/null

    local zenity_status=$?

    wait "$worker_pid"
    local worker_status=$?

    set -e

    rm -f "$PROGRESS_FIFO"

    stop_log_window

    if [ "$worker_status" -ne 0 ]; then
        fatal "A instalação não pôde ser concluída. Consulte o arquivo de log: $LOG_FILE"
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
    local java_version
    java_version="$("$JAVA_BIN" -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"

    success "SKLauncher $LATEST_VERSION instalado com sucesso."
    success "Java utilizado: Eclipse Temurin $java_version"

    if [ "$GUI_AVAILABLE" = true ]; then
        if zenity \
            --question \
            --title="$APP_NAME" \
            --width=480 \
            --text="<b>Instalação concluída!</b>

SKLauncher: <b>$LATEST_VERSION</b>
Java: <b>Eclipse Temurin $java_version</b>

Deseja executar o SKLauncher agora?" \
            --ok-label="Executar" \
            --cancel-label="Fechar" \
            2>/dev/null; then

            "$LAUNCHER_SCRIPT" >>"$LOG_FILE" 2>&1 &
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
    prepare_temp
    detect_system
    bootstrap_zenity

    case "${1:-}" in
        -remove|--remove|-r|remove|uninstall)
            remove_installation
            exit 0
            ;;
    esac

    show_welcome

    # A senha é solicitada no início, antes da instalação.
    setup_graphical_sudo

    if [ "$GUI_AVAILABLE" = true ]; then
        graphical_installation
    else
        terminal_installation
    fi

    finish_installation
}

main "$@"
