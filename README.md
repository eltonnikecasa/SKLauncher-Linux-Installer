# SkInstaller

Instalador automático do SKlauncher para Linux (Garuda / Arch), com configuração automática de Java e criação de atalho no sistema.

---

## O que o script faz

Ao executar o `SkInstaller.sh`, ele automaticamente:

- Verifica se Java está instalado
- Instala Java Temurin 21 se necessário
- Define Java 21 como padrão no sistema
- Detecta a versão mais recente do SKlauncher
- Baixa automaticamente o launcher
- Valida se o arquivo não está corrompido
- Cria atalho no menu do sistema (KDE/GNOME)
- Usa ícone padrão do Minecraft do sistema
- Executa o launcher após instalação

---

## Como usar

### 1. Dar permissão de execução

```bash
chmod +x SkInstaller.sh
```

---

### 2. Executar

```bash
./SkInstaller.sh
```

---

## Instalação em uma linha (recomendado)

```bash
curl -fsSL https://raw.githubusercontent.com/eltonnikecasa/Garuda-Linux-SKLauncher-Installer/main/SkInstaller.sh | bash
```

---

## Remover instalação

```bash
./SkInstaller.sh -remove
```

Isso remove:

- Launcher instalado
- Atalho do sistema
- Arquivos locais do SkInstaller

O script permanece no sistema.

---

## Arquivos criados

```text
~/.local/share/skinstaller/
~/.local/share/applications/skinstaller.desktop
```

---

## Requisitos

- Arch Linux ou derivados (Garuda Linux)
- paru instalado
- conexão com internet

---

## Compatibilidade

- KDE Plasma
- GNOME
- Wayland
- X11
- Arch Linux / Garuda Linux

---

## Observações

- O script não precisa de instalação manual de Java
- O sistema escolhe automaticamente Java 21 (Temurin)
- O launcher é atualizado automaticamente se necessário

---

## Licença

Uso livre para automação pessoal.
