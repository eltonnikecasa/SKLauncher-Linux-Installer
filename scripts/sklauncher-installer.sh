#!/bin/bash

set -e

############################################
# SkInstaller
############################################

APP_NAME="SkInstaller"

INSTALL_DIR="$HOME/.local/share/skinstaller"

DESKTOP_DIR="$HOME/.local/share/applications"

DESKTOP_FILE="$DESKTOP_DIR/skinstaller.desktop"

JAR_FILE="$INSTALL_DIR/SKlauncher.jar"

TEMP_DIR="/tmp/skinstaller-download"

DOWNLOAD_PAGE="https://skmedix.pl/downloads"

############################################
# DETECTAR VERSÃO MAIS RECENTE
############################################

PAGE_CONTENT=$(curl -L -s "$DOWNLOAD_PAGE")

LATEST_VERSION=$(echo "$PAGE_CONTENT" | grep -oE 'SKlauncher-[0-9]+\.[0-9]+\.[0-9]+\.jar' | head -n1 | sed 's/SKlauncher-//' | sed 's/\.jar//')

############################################
# FALLBACK
############################################

if [ -z "$LATEST_VERSION" ]; then
    echo "Não foi possível detectar automaticamente"
    echo "Usando versão fallback 3.2.18"
    LATEST_VERSION="3.2.18"
fi

echo "Versão detectada: $LATEST_VERSION"

SKL_URL="https://skmedix.pl/binaries/skl/${LATEST_VERSION}/SKlauncher-${LATEST_VERSION}.jar"

############################################
# REMOVER
############################################

if [ "$1" = "-remove" ]; then
    echo "Removendo SkInstaller..."

    rm -rf "$INSTALL_DIR"
    rm -f "$DESKTOP_FILE"

    kbuildsycoca6 >/dev/null 2>&1 || true
    kbuildsycoca5 >/dev/null 2>&1 || true
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

    echo "Remoção concluída"
    echo "Script preservado"
    exit 0
fi

############################################
# CRIAR PASTAS
############################################

mkdir -p "$INSTALL_DIR"
mkdir -p "$TEMP_DIR"
mkdir -p "$DESKTOP_DIR"

############################################
# VALIDAR PARU
############################################

if ! command -v paru >/dev/null 2>&1; then
    echo "ERRO: paru não encontrado"
    exit 1
fi

############################################
# INSTALAR JAVA 21 TEMURIN
############################################

install_java() {
    echo "Instalando Temurin 21..."
    paru -S --needed --noconfirm jdk21-temurin
    sudo archlinux-java set java-21-temurin
}

############################################
# VALIDAR JAVA
############################################

if ! command -v java >/dev/null 2>&1; then
    install_java
fi

if ! java -version 2>&1 | grep -q '21'; then
    install_java
fi

java -version

############################################
# VERIFICAR / BAIXAR LAUNCHER
############################################

DOWNLOAD=true

if [ -f "$JAR_FILE" ]; then
    if jar tf "$JAR_FILE" >/dev/null 2>&1; then
        echo "Launcher válido encontrado"
        DOWNLOAD=false
    else
        echo "Launcher corrompido"
        rm -f "$JAR_FILE"
    fi
fi

if [ "$DOWNLOAD" = true ]; then
    echo "Baixando SKlauncher ${LATEST_VERSION}..."

    wget --content-disposition -O "$JAR_FILE" "$SKL_URL"
fi

############################################
# CRIAR ATALHO
############################################

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
# ATUALIZAR MENU KDE/GNOME
############################################

kbuildsycoca6 >/dev/null 2>&1 || true
kbuildsycoca5 >/dev/null 2>&1 || true
update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

############################################
# EXECUTAR
############################################

echo "Executando launcher..."

java -jar "$JAR_FILE"
