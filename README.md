# SKLauncher Linux Installer

Instalador gráfico e automático do **SKLauncher para Linux**, com detecção da distribuição, configuração do Java 21, download do launcher e integração com o ambiente desktop.

O projeto foi criado para simplificar a instalação do SKLauncher em diferentes distribuições Linux, evitando que o usuário precise instalar e configurar manualmente o Java ou criar atalhos.

> **Projeto não oficial**
>
> Este projeto é um instalador comunitário e **não possui afiliação, patrocínio ou vínculo oficial com o SKLauncher ou seus desenvolvedores**.
>
> O instalador **não redistribui o SKLauncher**. O launcher é baixado diretamente dos servidores do SKLauncher durante a instalação.

---

## Interface gráfica

O instalador utiliza **Zenity** para fornecer uma interface gráfica simples durante a instalação.

A interface apresenta:

* distribuição Linux detectada;
* etapas da instalação;
* barra de progresso;
* mensagens de erro;
* confirmação de conclusão;
* opção para executar o SKLauncher após a instalação;
* confirmação gráfica durante a remoção.

Caso o Zenity não esteja instalado, o instalador tenta instalá-lo automaticamente.

Quando não existe uma sessão gráfica disponível, o instalador pode continuar pelo terminal.

---

## Recursos

Ao executar o script, ele automaticamente:

* detecta a distribuição Linux;
* identifica a família da distribuição;
* detecta o gerenciador de pacotes;
* verifica e instala as dependências necessárias;
* verifica a instalação do Java;
* instala **Java 21** automaticamente quando necessário;
* configura Java 21 no Arch Linux e derivados quando necessário;
* verifica a conexão com a internet através de HTTPS;
* detecta a versão disponível do SKLauncher;
* baixa o launcher diretamente do servidor do SKLauncher;
* realiza validação básica do arquivo JAR;
* baixa e instala o ícone;
* cria um script de inicialização;
* cria um atalho no menu de aplicações;
* atualiza o cache de aplicações;
* permite executar o launcher após a instalação;
* permite remover os arquivos instalados.

---

## Distribuições

O instalador utiliza `/etc/os-release` para identificar a distribuição e sua família.

Atualmente existem três famílias implementadas:

| Família    | Gerenciador       |
| ---------- | ----------------- |
| Arch Linux | `pacman` / `paru` |
| Fedora     | `dnf` / `dnf5`    |
| Debian     | `apt`             |

### Distribuições testadas

As seguintes distribuições foram testadas diretamente:

* **CachyOS**
* **Fedora**

### Suportadas, mas ainda não testadas

O instalador possui suporte implementado para as distribuições abaixo, porém elas ainda precisam de testes reais.

#### Arch e derivados

* Arch Linux
* EndeavourOS
* Manjaro Linux
* Garuda Linux

#### Fedora e derivados

Distribuições que utilizem uma base Fedora compatível e forneçam `dnf` ou `dnf5` podem funcionar, mas ainda não foram validadas individualmente.

#### Debian e derivados

* Debian
* Ubuntu
* Linux Mint
* Pop!_OS
* Zorin OS

> **Ajude nos testes**
>
> Se você testar o instalador em uma distribuição ainda não validada, abra uma Issue informando a distribuição, versão, ambiente desktop e o resultado do teste.

---

## Ambientes gráficos

O instalador foi desenvolvido para funcionar em sessões Linux gráficas modernas.

### Compatibilidade prevista

* KDE Plasma
* GNOME
* X11
* Wayland

A interface gráfica depende do **Zenity**.

Ferramentas específicas do KDE, como `kbuildsycoca6`, são utilizadas apenas quando estão disponíveis e não são obrigatórias para outros ambientes desktop.

---

## Como usar

Clone ou baixe este repositório e dê permissão de execução ao instalador:

```bash
chmod +x scripts/sklauncher-installer.sh
```

Depois execute:

```bash
./scripts/sklauncher-installer.sh
```

O instalador detectará automaticamente o sistema e iniciará a instalação.

---

## Instalação em uma linha

Também é possível executar diretamente:

```bash
rm -rf /tmp/sklauncher-installer /tmp/sklauncher-installer.sh && \
curl -fL https://raw.githubusercontent.com/eltonnikecasa/SKLauncher-Linux-Installer/main/scripts/sklauncher-installer.sh \
-o /tmp/sklauncher-installer.sh && \
chmod +x /tmp/sklauncher-installer.sh && \
/tmp/sklauncher-installer.sh
```

> Para maior segurança, usuários que desejarem revisar o código antes da execução podem baixar o script primeiro e executá-lo localmente.

---

## Remover instalação

Se você possui o script localmente:

```bash
./scripts/sklauncher-installer.sh --remove
```

Também são aceitos:

```bash
./scripts/sklauncher-installer.sh -remove
./scripts/sklauncher-installer.sh -r
```

A remoção exclui:

* SKLauncher instalado pelo script;
* ícone instalado;
* script auxiliar de inicialização;
* atalho do menu de aplicações;
* arquivos locais utilizados pelo instalador.

O próprio script utilizado para realizar a instalação não é removido.

---

## Arquivos criados

O instalador utiliza:

```text
~/.local/share/skinstaller/
```

Dentro desse diretório ficam arquivos como:

```text
SKlauncher.jar
minecraft.png
sklauncher.sh
```

O atalho do menu é criado em:

```text
~/.local/share/applications/sklauncher-installer.desktop
```

Arquivos temporários podem ser criados durante a instalação em:

```text
/tmp/sklauncher-installer/
```

---

## Java

O SKLauncher é configurado para utilizar **Java 21**.

Dependendo da distribuição, o instalador utiliza os pacotes apropriados.

### Fedora

```text
java-21-openjdk
java-21-openjdk-devel
```

### Arch Linux e derivados

```text
jdk21-openjdk
```

### Debian, Ubuntu e derivados

```text
openjdk-21-jdk
```

No Arch Linux e derivados, quando disponível, o instalador utiliza `archlinux-java` para selecionar uma instalação Java 21 compatível.

---

## Dependências

O instalador pode utilizar ou instalar:

```text
Java 21
curl
wget
desktop-file-utils
zenity
```

Outras ferramentas já fornecidas pela distribuição podem ser utilizadas quando disponíveis.

---

## Gerenciadores de pacotes

Atualmente são reconhecidos:

```text
pacman
paru
dnf
dnf5
apt
```

O instalador escolhe automaticamente o gerenciador apropriado de acordo com a distribuição detectada.

---

## Atualização do SKLauncher

Durante a execução, o instalador consulta a página de download do SKLauncher para identificar a versão disponível.

Quando a detecção automática não é possível, o instalador possui uma versão de fallback para evitar que uma alteração temporária na página interrompa completamente a instalação.

O arquivo JAR é obtido diretamente do servidor do SKLauncher.

---

## Segurança

O instalador:

* não coleta dados do usuário;
* não envia telemetria;
* não executa serviços em segundo plano;
* não modifica documentos ou arquivos pessoais;
* não armazena senhas;
* utiliza `sudo` somente para operações que exigem privilégios administrativos, como instalação de dependências;
* instala o SKLauncher dentro do diretório do próprio usuário;
* baixa o SKLauncher diretamente de sua fonte;
* mantém o código do instalador aberto para auditoria.

O SKLauncher é um projeto independente. As políticas, funcionamento e segurança do próprio launcher são responsabilidade de seus respectivos desenvolvedores.

---

## Estrutura da instalação

A instalação é feita no espaço do usuário:

```text
$HOME
└── .local
    └── share
        ├── skinstaller
        │   ├── SKlauncher.jar
        │   ├── minecraft.png
        │   └── sklauncher.sh
        │
        └── applications
            └── sklauncher-installer.desktop
```

Isso evita instalar o launcher diretamente em diretórios globais como `/opt` ou `/usr/local`.

---

## Problemas e relatórios

Caso encontre algum problema, informe preferencialmente:

```text
Distribuição:
Versão:
Desktop:
Wayland/X11:
Gerenciador de pacotes:
Versão do Java:
Mensagem de erro:
```

Para obter informações da distribuição:

```bash
cat /etc/os-release
```

Para verificar o Java:

```bash
java -version
```

---

## Objetivo do projeto

O objetivo do **SKLauncher Linux Installer** é fornecer uma forma simples e consistente de instalar o SKLauncher em diferentes distribuições Linux.

A ideia é permitir que um usuário possa executar um único instalador sem precisar descobrir manualmente:

* qual pacote Java instalar;
* qual gerenciador de pacotes utilizar;
* onde armazenar o launcher;
* como criar um arquivo `.desktop`;
* como atualizar o cache do ambiente gráfico.

---

## Contribuições

Testes em outras distribuições são bem-vindos.

Relatórios de compatibilidade ajudam a mover distribuições da lista **“suportadas, mas não testadas”** para **“testadas”** e a identificar diferenças entre versões e ambientes desktop.

---

## Licença

Este projeto é distribuído sob a **MIT License**.

Consulte o arquivo `LICENSE` do repositório para mais informações.
