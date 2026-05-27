#!/bin/bash

set -e

############################################
# SKLauncher Linux Installer
############################################

APP_NAME="SKLauncher Linux Installer"

INSTALL_DIR="$HOME/.local/share/skinstaller"
DESKTOP_DIR="$HOME/.local/share/applications"

DESKTOP_FILE="$DESKTOP_DIR/sklauncher-installer.desktop"

JAR_FILE="$INSTALL_DIR/SKlauncher.jar"

TEMP_DIR="/tmp/sklauncher-installer"

DOWNLOAD_PAGE="https://skmedix.pl/downloads"

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

############################################
# DETECTAR SISTEMA
############################################

detect_system() {

    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        error "Não foi possível detectar o sistema"
        exit 1
    fi

    DISTRO="$ID"

    if command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"

    elif command -v paru >/dev/null 2>&1; then
        PKG_MANAGER="paru"

    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"

    else
        error "Gerenciador de pacotes não suportado"
        exit 1
    fi

    info "Sistema detectado: $PRETTY_NAME"
    info "Gerenciador detectado: $PKG_MANAGER"
}

############################################
# EXECUTAR DETECÇÃO
############################################

detect_system

############################################
# VALIDAR INTERNET
############################################

info "Verificando conexão com internet..."

if ! ping -c 1 github.com >/dev/null 2>&1; then

    error "Sem conexão com internet"

    exit 1
fi

success "Internet OK"

############################################
# VALIDAR SUDO
############################################

info "Validando permissões sudo..."

if ! sudo -v; then

    error "Permissões sudo necessárias"

    exit 1
fi

success "Sudo validado"

############################################
# DETECTAR VERSÃO MAIS RECENTE
############################################

info "Detectando versão mais recente do SKLauncher..."

if command -v curl >/dev/null 2>&1; then

    PAGE_CONTENT=$(curl -L -s "$DOWNLOAD_PAGE")

else

    PAGE_CONTENT=$(wget -qO- "$DOWNLOAD_PAGE")
fi

LATEST_VERSION=$(echo "$PAGE_CONTENT" \
| grep -oE 'SKlauncher-[0-9]+\.[0-9]+\.[0-9]+\.jar' \
| head -n1 \
| sed 's/SKlauncher-//' \
| sed 's/\.jar//')

############################################
# FALLBACK
############################################

if [ -z "$LATEST_VERSION" ]; then

    warning "Não foi possível detectar automaticamente"
    warning "Usando versão fallback 3.2.18"

    LATEST_VERSION="3.2.18"
fi

success "Versão detectada: $LATEST_VERSION"

SKL_URL="https://skmedix.pl/binaries/skl/${LATEST_VERSION}/SKlauncher-${LATEST_VERSION}.jar"

############################################
# REMOVER
############################################

if [[ "$1" == "-remove" || "$1" == "--remove" || "$1" == "-r" ]]; then

    info "Removendo instalação..."

    rm -rf "$INSTALL_DIR"
    rm -f "$DESKTOP_FILE"

    kbuildsycoca6 >/dev/null 2>&1 || true
    kbuildsycoca5 >/dev/null 2>&1 || true

    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

    success "Remoção concluída"
    info "Script preservado"

    exit 0
fi

############################################
# CRIAR PASTAS
############################################

info "Criando diretórios..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$TEMP_DIR"
mkdir -p "$DESKTOP_DIR"

############################################
# INSTALAR JAVA
############################################

install_java() {

    info "Instalando Java 21..."

    case "$PKG_MANAGER" in

        apt)

            sudo apt update

            sudo apt install -y \
                openjdk-21-jdk \
                curl \
                wget \
                desktop-file-utils
        ;;

        paru)

            paru -S --needed --noconfirm \
                jdk21-temurin \
                curl \
                wget \
                desktop-file-utils

            sudo archlinux-java set java-21-temurin
        ;;

        pacman)

            sudo pacman -Sy --needed --noconfirm \
                jdk21-openjdk \
                curl \
                wget \
                desktop-file-utils
        ;;

        *)

            error "Gerenciador não suportado"
            exit 1
        ;;

    esac
}

############################################
# VALIDAR JAVA
############################################

if ! command -v java >/dev/null 2>&1; then

    warning "Java não encontrado"

    install_java
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')

if ! echo "$JAVA_VERSION" | grep -q '^21'; then

    warning "Java 21 não encontrado"

    install_java
fi

success "Java detectado: $JAVA_VERSION"

############################################
# VERIFICAR / BAIXAR LAUNCHER
############################################

DOWNLOAD=true

if [ -f "$JAR_FILE" ]; then

    if jar tf "$JAR_FILE" >/dev/null 2>&1; then

        success "Launcher válido encontrado"

        DOWNLOAD=false

    else

        warning "Launcher corrompido"

        rm -f "$JAR_FILE"
    fi
fi

if [ "$DOWNLOAD" = true ]; then

    info "Baixando SKLauncher ${LATEST_VERSION}..."

    wget --content-disposition -O "$JAR_FILE" "$SKL_URL"

    success "Download concluído"
fi

############################################
# CRIAR ATALHO
############################################

info "Criando atalho do sistema..."

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=SKLauncher Minecraft
Comment=Minecraft Launcher Installer
Exec=java -jar "$JAR_FILE"
Icon=minecraft
Terminal=false
Categories=Game;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

############################################
# ATUALIZAR MENU
############################################

info "Atualizando cache de aplicações..."

kbuildsycoca6 >/dev/null 2>&1 || true
kbuildsycoca5 >/dev/null 2>&1 || true

update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

############################################
# EXECUTAR
############################################

success "Executando launcher..."

java -jar "$JAR_FILE"
