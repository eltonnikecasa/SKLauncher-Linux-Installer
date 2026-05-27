# SKLauncher Linux Installer

Instalador automático do SKLauncher para Linux com configuração automática de Java, download do launcher e integração com o sistema.

---

## Recursos

Ao executar o script, ele automaticamente:

- Verifica se Java está instalado
- Instala Java 21 automaticamente se necessário
- Define Java 21 como padrão do sistema
- Detecta a versão mais recente do SKLauncher
- Baixa automaticamente o launcher
- Valida integridade básica do arquivo
- Cria atalho no menu do sistema
- Atualiza cache de aplicações do desktop
- Executa o launcher após instalação

---

## Como usar

### 1. Dar permissão de execução

```bash
chmod +x scripts/sklauncher-installer.sh
```

---

### 2. Executar

```bash
./scripts/sklauncher-installer.sh
```

---

## Instalação em uma linha (recomendado)

```bash
curl -fsSL https://raw.githubusercontent.com/eltonnikecasa/SKLauncher-Linux-Installer/main/scripts/sklauncher-installer.sh | bash
```

---

## Remover instalação

```bash
./scripts/sklauncher-installer.sh -remove
```

Isso remove:

- Launcher instalado
- Atalho do sistema
- Arquivos locais do instalador

O script permanece no sistema.

---

## Arquivos criados

```text
~/.local/share/skinstaller/
~/.local/share/applications/skinstaller.desktop
```

---

## Compatibilidade atual

- Arch Linux
- Garuda Linux
- CachyOS

---

## Compatibilidade planejada

- Debian
- Ubuntu
- Linux Mint

---

## Compatibilidade gráfica

- KDE Plasma
- GNOME
- Wayland
- X11

---

## Requisitos

- Linux
- conexão com internet

---

## Segurança

O script:

- Não coleta dados
- Não executa processos ocultos
- Não modifica arquivos pessoais do usuário
- Usa fontes oficiais do SKLauncher
- Instala apenas dependências necessárias

---

## Observações

- O script automatiza toda a instalação do Java
- O launcher é baixado automaticamente
- O instalador foi desenvolvido para simplificar a instalação do SKLauncher no Linux

---

## Licença

MIT License
