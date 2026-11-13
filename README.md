# BTC Signal

Um bot simples para Telegram, feito em Bash, que publica a cotação do Bitcoin em um canal.

A cada minuto ele consulta o preço do BTC em **BRL, USD e EUR** e, quando algo muda, envia uma mensagem ao canal mostrando se o preço subiu (🟢), caiu (🔴) ou ficou estável (⚪), quantas vezes seguidas isso aconteceu, além do volume e da variação das últimas 24h.

É um projeto pequeno, feito por diversão e aprendizado. Sugestões são sempre bem-vindas!

## Exemplo de mensagem

```
Cotação Bitcoin:
🟢×2 BRL: 512.345
🟢×2 USD: 91.234
🔴×1 EUR: 84.567
Fonte: yadio.io

📊Volume (24h):   123.45 BTC
⬆️Variação (24h): 1.23%
Fonte: cointradermonitor.com
```

## Dependências

Nada de muito especial, só o básico de um sistema Linux:

- `bash` 4.3 ou superior
- `curl`
- `jq` (usado pelo ShellBot)
- `getopt` (vem no pacote `util-linux`)
- `bc` (para comparar os preços)

No Debian/Ubuntu:

```bash
sudo apt update
sudo apt install bash curl jq util-linux bc
```

No Termux (Android):

```bash
pkg install bash curl jq util-linux bc
```

A comunicação com o Telegram é feita pelo [ShellBot.sh](https://github.com/shellscriptx/ShellBot), de Juliano Santos (SHAMAN), que já está incluído no repositório.

## Instalação

1. Clone o repositório:

   ```bash
   git clone https://github.com/AlerrandroV/btcsignal.git
   cd btcsignal
   ```

2. Crie o seu bot falando com o [@BotFather](https://t.me/BotFather) no Telegram e guarde o token que ele te passar.

3. Crie um canal, adicione o bot como **administrador** (com permissão para publicar mensagens) e descubra o ID do canal. Ele costuma começar com `-100`.
   Uma forma fácil: encaminhe uma mensagem do canal para o [@userinfobot](https://t.me/userinfobot) ou bot parecido.

4. Copie o arquivo de exemplo e preencha com os seus dados:

   ```bash
   cp config.example.sh config.sh
   nano config.sh
   ```

   ```bash
   bot_token="SEU_TOKEN_DO_BOTFATHER"
   admins_id=(111111111)          # seu ID de usuário no Telegram
   channel_id="-100XXXXXXXXXX"    # ID do canal
   users_id=()
   ```

   > O `config.sh` está no `.gitignore` para que o seu token não vá parar no GitHub por engano. Nunca compartilhe o seu token.

## Uso

Dentro da pasta do projeto:

```bash
bash main.sh
```

O bot avisa os administradores que foi iniciado e começa a publicar a cotação no canal. Para encerrar, use `Ctrl+C`.

### Comandos

| Comando | Quem pode | O que faz |
|---|---|---|
| `/publi Seu texto` | Administradores | Publica o texto no canal |
| `/publi` respondendo a uma mensagem | Administradores | Publica a mensagem respondida no canal (fotos, vídeos etc. são encaminhados) |

Para deixar rodando depois de fechar o terminal, você pode usar o `screen`, o `tmux` ou simplesmente:

```bash
nohup bash main.sh > bot.log 2>&1 &
```

## Arquivos

| Arquivo | O que faz |
|---|---|
| `main.sh` | Inicia o bot, o loop de sinais e trata os comandos recebidos |
| `signals.sh` | Busca as cotações e monta a mensagem enviada ao canal |
| `config.example.sh` | Modelo de configuração (copie para `config.sh`) |
| `ShellBot.sh` | API em Bash para o Telegram ([shellscriptx/ShellBot](https://github.com/shellscriptx/ShellBot)) |
| `commands/` | Scripts dos comandos do bot (`/start`, ...) |
| `trader.sh` | Experimento à parte: um simulador de compra/venda no terminal, sem dinheiro real |
| `teste.sh` | Script de teste que encaminha as mensagens recebidas para os administradores |

## Fontes dos dados

- Cotações: [yadio.io](https://yadio.io)
- Volume e variação em 24h: [cointradermonitor.com](https://cointradermonitor.com)

## Aviso

As informações do bot servem apenas como acompanhamento. Isto **não** é recomendação de investimento.

## Créditos

Feito por [@SrKubitschek](https://t.me/SrKubitschek) usando o [ShellBot.sh](https://github.com/shellscriptx/ShellBot).
