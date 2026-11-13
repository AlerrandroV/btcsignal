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

> Pressa? Pode rodar `bash main.sh` direto: se faltar alguma coisa, o próprio bot mostra o passo a passo do que fazer.

2. Crie o seu bot falando com o [@BotFather](https://t.me/BotFather) no Telegram (envie `/newbot`) e guarde o token que ele te passar.

3. Copie o arquivo de exemplo e coloque o token nele:

   ```bash
   cp config.example.sh config.sh
   nano config.sh
   ```

4. Crie um canal e adicione o bot como **administrador**, com permissão para publicar mensagens. Depois:
   - envie uma mensagem qualquer no canal;
   - abra o seu bot no Telegram e envie `/start`.

5. Descubra o ID do canal e o seu ID de usuário:

   ```bash
   bash ids.sh
   ```

6. Preencha o resto do `config.sh`:

   ```bash
   bot_token="123456789:AAHk7x..."   # token do BotFather
   admins_id=(123456789)             # seu ID de usuário (vários: separados por espaço)
   channel_id="-1001234567890"       # ID do canal
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

### Atualizar

Para baixar a versão mais recente do código e já iniciar o bot:

```bash
bash update.sh
```

O `config.sh`, a pasta `users/` e o `secret_names.sh` não são alterados. Não precisa do `git`, só do `curl` e do `tar`. Se o bot já estiver rodando, encerre ele antes (`Ctrl+C`).

Para deixar rodando depois de fechar o terminal, você pode usar o `screen`, o `tmux` ou simplesmente:

```bash
nohup bash main.sh > bot.log 2>&1 &
```

## Se algo der errado

Antes de iniciar, o bot confere tudo o que precisa e, se encontrar um problema, explica o motivo e como resolver:

- programas que faltam instalar, com o comando certo para o seu sistema (Debian/Ubuntu, Termux, Fedora, Arch, macOS...);
- `config.sh` que não existe, com erro de digitação ou ainda com os valores de exemplo;
- token errado ou trocado no BotFather;
- canal errado, ou bot que não é administrador do canal;
- falta de internet ou Telegram bloqueado na rede.

Com o bot rodando, os erros também aparecem explicados no terminal, com data e hora. Por exemplo: quando um site de cotação sai do ar, quando um administrador nunca enviou `/start` para o bot, ou quando há duas cópias do bot rodando com o mesmo token. Se um `/publi` falhar, o administrador recebe o motivo no próprio Telegram.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `main.sh` | Inicia o bot, o loop de sinais e trata os comandos recebidos |
| `signals.sh` | Busca as cotações e monta a mensagem enviada ao canal |
| `checks.sh` | Verificações antes de iniciar e explicações dos erros |
| `update.sh` | Baixa a versão mais recente do código (sem mexer no `config.sh`) e inicia o bot |
| `ids.sh` | Mostra os IDs de quem falou com o bot e dos canais onde ele está |
| `config.example.sh` | Modelo de configuração (copie para `config.sh`) |
| `ShellBot.sh` | API em Bash para o Telegram ([shellscriptx/ShellBot](https://github.com/shellscriptx/ShellBot)), com uma pequena alteração marcada com `[btcsignal]` |
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
