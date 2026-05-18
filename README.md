# Garuda SKLauncher

Launcher, instalador e atualizador automático do SKlauncher para Garuda Linux e Arch Linux.

---

## Funcionalidades

- Instala Java Temurin 21 automaticamente
- Define Java 21 como padrão
- Detecta automaticamente a versão mais recente do SKlauncher
- Baixa automaticamente o launcher
- Detecta arquivos corrompidos
- Cria atalho no KDE/GNOME
- Compatível com Wayland
- Atualização automática
- Script único standalone
- Modo remoção integrado

---

## Requisitos

- Garuda Linux / Arch Linux
- paru
- internet

---

# Comandos

## Instalar / Atualizar / Executar

```bash
./SKLauncher
```

O script automaticamente:

- instala Java se necessário
- atualiza launcher
- cria atalhos
- executa o launcher

---

## Remover

```bash
./SKLauncher -remove
```

Remove:

- launcher
- atalhos
- arquivos instalados

Preserva:

- o script SKLauncher

---

## Instalação rápida

Copie e cole no terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USUARIO/REPOSITORIO/main/SKLauncher)
```

---

## Download manual

```bash
chmod +x SKLauncher

./SKLauncher
```

---

## Estrutura instalada

```text
~/.local/share/sklauncher

~/.local/share/applications/garuda-sklauncher.desktop
```

---

## Compatibilidade

- KDE Plasma
- Wayland
- X11
- Garuda Linux
- Arch Linux

---

## Licença

MIT License
