#!/bin/bash

# Verificações e mensagens de erro explicadas.
#
# A ideia é que qualquer pessoa, mesmo sem experiência, consiga entender
# o que deu errado e como resolver. Todas as mensagens vão para a tela
# (saída de erro), nunca para o Telegram, a não ser quando indicado.

# ---------------------------------------------------------------------------
# Aparência
# ---------------------------------------------------------------------------

# Só usa cores quando a saída é um terminal (não suja arquivos de log)
if [[ -t 2 ]]; then
	_C_RED=$'\e[1;31m' _C_YEL=$'\e[1;33m' _C_GRN=$'\e[1;32m' _C_BLD=$'\e[1m' _C_RST=$'\e[0m'
else
	_C_RED='' _C_YEL='' _C_GRN='' _C_BLD='' _C_RST=''
fi

# Mostra um erro com título. A explicação vem pela entrada padrão (heredoc).
#   error_box "Título" <<EOF
#   explicação...
#   EOF
error_box() {
	printf '\n%s✗ %s%s\n\n' "$_C_RED" "$1" "$_C_RST" >&2
	cat >&2
	echo >&2
}

# Mesmo formato, mas para avisos que não impedem o bot de rodar
warning_box() {
	printf '\n%s⚠ %s%s\n\n' "$_C_YEL" "$1" "$_C_RST" >&2
	cat >&2
	echo >&2
}

ok() {
	printf '%s✓%s %s\n' "$_C_GRN" "$_C_RST" "$*" >&2
}

# Registro com data e hora, para erros que acontecem com o bot já rodando
log() {
	printf '[%s] %s\n' "$(date '+%d/%m %H:%M:%S')" "$*" >&2
}

# ---------------------------------------------------------------------------
# Guias passo a passo
# ---------------------------------------------------------------------------

guide_create_bot() {
	cat >&2 <<EOF
${_C_BLD}Passo a passo para criar o seu bot:${_C_RST}

  1. Abra o Telegram e procure por @BotFather (o bot oficial, com selo azul).
  2. Envie /newbot e responda o que ele perguntar:
       - o nome do bot (ex.: Meu BTC Signal)
       - o usuário do bot, que precisa terminar em "bot" (ex.: meu_btcsignal_bot)
  3. No final o BotFather envia o token, parecido com isto:
       123456789:AAHk7xQ2bN0v9sYk3Lr8mPq1Zt5Wc4dEfGh
     Guarde com cuidado: quem tiver o token controla o seu bot.
  4. Coloque o token no config.sh, entre aspas:
       bot_token="123456789:AAHk7xQ2bN0v9sYk3Lr8mPq1Zt5Wc4dEfGh"

  Perdeu o token? Envie /token para o @BotFather e escolha o seu bot.
EOF
}

guide_channel() {
	cat >&2 <<EOF
${_C_BLD}Passo a passo para configurar o canal:${_C_RST}

  1. Crie um canal no Telegram (ou use um que você já tenha).
  2. Abra o canal → toque no nome dele → Administradores → Adicionar administrador.
     Procure o usuário do seu bot e deixe marcada a permissão "Publicar mensagens".
  3. Envie qualquer mensagem no canal.
  4. Rode o comando abaixo para descobrir o ID do canal (começa com -100):
       bash ids.sh
  5. Coloque o ID no config.sh, entre aspas:
       channel_id="-1001234567890"
EOF
}

guide_admin_id() {
	cat >&2 <<EOF
${_C_BLD}Como descobrir o seu ID de usuário:${_C_RST}

  1. Abra o seu bot no Telegram e envie /start.
  2. Rode:
       bash ids.sh
  3. Coloque o seu ID no config.sh (vários IDs separados por espaço):
       admins_id=(123456789)
EOF
}

# ---------------------------------------------------------------------------
# Verificações do sistema
# ---------------------------------------------------------------------------

check_bash_version() {
	if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
		error_box "Versão do bash muito antiga (${BASH_VERSION})" <<EOF
O bot precisa do bash 4.3 ou mais novo.

Isso costuma acontecer no macOS, que vem com o bash 3.2. Para resolver:
  brew install bash
e depois rode o bot com o bash novo:
  /opt/homebrew/bin/bash main.sh    (Mac com chip Apple)
  /usr/local/bin/bash main.sh       (Mac com chip Intel)
EOF
		return 1
	fi
}

# Monta o comando de instalação de acordo com o sistema
install_command() {
	local pkgs=("$@") i
	if [[ $PREFIX == *com.termux* ]]; then
		echo "pkg install ${pkgs[*]}"
	elif command -v apt-get &>/dev/null; then
		echo "sudo apt update && sudo apt install ${pkgs[*]}"
	elif command -v dnf &>/dev/null; then
		echo "sudo dnf install ${pkgs[*]}"
	elif command -v pacman &>/dev/null; then
		echo "sudo pacman -S ${pkgs[*]}"
	elif command -v apk &>/dev/null; then
		echo "sudo apk add ${pkgs[*]}"
	elif command -v brew &>/dev/null; then
		for i in "${!pkgs[@]}"; do [[ ${pkgs[i]} == util-linux ]] && pkgs[i]=gnu-getopt; done
		echo "brew install ${pkgs[*]}"
	else
		echo "use o gerenciador de pacotes do seu sistema para instalar: ${pkgs[*]}"
	fi
}

# Verifica se os programas necessários estão instalados.
#   check_dependencies curl jq getopt bc
check_dependencies() {
	local cmd missing=() pkgs=() details=""

	for cmd in "$@"; do
		command -v "$cmd" &>/dev/null && continue
		missing+=("$cmd")
		case $cmd in
			curl)   pkgs+=(curl);       details+="  - curl: conversa com o Telegram e busca as cotações"$'\n' ;;
			jq)     pkgs+=(jq);         details+="  - jq: lê as respostas do Telegram (formato JSON)"$'\n' ;;
			getopt) pkgs+=(util-linux); details+="  - getopt: usado pelo ShellBot (vem no pacote util-linux)"$'\n' ;;
			bc)     pkgs+=(bc);         details+="  - bc: faz as contas para comparar os preços"$'\n' ;;
			*)      pkgs+=("$cmd");     details+="  - $cmd"$'\n' ;;
		esac
	done

	if (( ${#missing[@]} )); then
		error_box "Faltam programas para o bot funcionar: ${missing[*]}" <<EOF
${details}
Para instalar, rode:
  $(install_command "${pkgs[@]}")

Depois é só rodar o bot de novo.
EOF
		return 1
	fi

	# O macOS vem com um getopt diferente, que o ShellBot não entende.
	# O getopt do util-linux responde "getopt --test" com o código 4.
	if [[ " $* " == *" getopt "* ]]; then
		getopt --test &>/dev/null
		if (( $? != 4 )); then
			error_box "O getopt instalado não é compatível" <<EOF
O ShellBot precisa do getopt do util-linux (o do macOS é diferente).

No macOS, rode:
  brew install gnu-getopt
e coloque ele na frente do getopt do sistema:
  export PATH="\$(brew --prefix gnu-getopt)/bin:\$PATH"

Dica: adicione essa linha "export" no final do arquivo ~/.zshrc (ou ~/.bashrc)
para não precisar repetir toda vez.
EOF
			return 1
		fi
	fi
}

# ---------------------------------------------------------------------------
# Verificações do config.sh
# ---------------------------------------------------------------------------

# Carrega e confere o config.sh.
# Retorna 1 se algo impedir o bot de funcionar.
check_config() {
	local problems=0 err

	if [[ ! -f config.sh ]]; then
		error_box "O arquivo config.sh não existe" <<EOF
Parece que é a primeira vez que você roda o bot. Bem-vindo! :)

O config.sh guarda o token do bot e o canal onde os sinais serão publicados.
Primeiro, crie ele a partir do modelo:

  cp config.example.sh config.sh

EOF
		guide_create_bot
		echo >&2
		guide_channel
		cat >&2 <<EOF

Para editar o config.sh, use um editor de texto, por exemplo:
  nano config.sh      (para salvar: Ctrl+O, Enter; para sair: Ctrl+X)

Quando terminar, rode o bot de novo:
  bash main.sh

EOF
		return 1
	fi

	# Erro de digitação no config.sh (ex.: aspas sem fechar)
	if ! err=$(bash -n config.sh 2>&1); then
		error_box "O config.sh tem um erro de digitação" <<EOF
O bash não conseguiu ler o arquivo. Mensagem original:
  ${err}

O mais comum é esquecer de fechar aspas ou parênteses. Compare com o modelo:
  cat config.example.sh
EOF
		return 1
	fi

	source config.sh

	# --- Token ---
	if [[ -z $bot_token || $bot_token == "SEU_TOKEN_DO_BOTFATHER" ]]; then
		error_box "O token do bot não foi configurado" <<EOF
O config.sh ainda está com o token de exemplo (ou vazio).

EOF
		guide_create_bot
		echo >&2
		problems=1
	elif [[ ! $bot_token =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]]; then
		error_box "O token do bot parece estar errado" <<EOF
Um token tem este formato: números, dois-pontos e uma sequência de letras:
  123456789:AAHk7xQ2bN0v9sYk3Lr8mPq1Zt5Wc4dEfGh

O que está no config.sh:
  ${bot_token}

Confira se não ficaram espaços, quebras de linha ou letras faltando.
Para ver o token de novo, envie /token para o @BotFather.
EOF
		problems=1
	fi

	if [[ ${REQUIRE_CHANNEL:-true} == true ]]; then
		# --- Canal ---
		if [[ -z $channel_id || $channel_id == "-100XXXXXXXXXX" ]]; then
			error_box "O canal não foi configurado" <<EOF
O config.sh ainda está com o canal de exemplo (ou vazio).
É nesse canal que o bot publica a cotação.

EOF
			guide_channel
			echo >&2
			problems=1
		elif [[ ! $channel_id =~ ^-?[0-9]+$ && ! $channel_id =~ ^@[A-Za-z0-9_]{5,}$ ]]; then
			error_box "O ID do canal parece estar errado" <<EOF
O channel_id deve ser um número (canais começam com -100) ou o @usuario
de um canal público. O que está no config.sh:
  ${channel_id}

EOF
			guide_channel
			echo >&2
			problems=1
		fi

	fi

	# --- Administradores (não impede o bot de rodar) ---
	local id bad_admins=()
	for id in "${admins_id[@]}"; do
		[[ $id =~ ^[0-9]+$ && $id != 111111111 ]] || bad_admins+=("$id")
	done
	if (( ${#admins_id[@]} == 0 )); then
		warning_box "Nenhum administrador configurado" <<EOF
O bot vai funcionar, mas ninguém vai poder usar comandos como /publi
e ninguém recebe o aviso de "Bot iniciado".

EOF
		guide_admin_id
	elif (( ${#bad_admins[@]} )); then
		warning_box "IDs de administrador inválidos ou de exemplo: ${bad_admins[*]}" <<EOF
O ID de usuário é só números, sem @ e sem aspas.

EOF
		guide_admin_id
	fi

	return $problems
}

# ---------------------------------------------------------------------------
# Verificações com o Telegram
# ---------------------------------------------------------------------------

# Explica erros de rede do curl pelo código de saída
explain_curl_error() {
	case $1 in
		6)  echo "Não foi possível encontrar o endereço. Verifique se o computador está conectado à internet." ;;
		7)  echo "A conexão foi recusada. Verifique a internet ou se algum firewall/proxy está bloqueando." ;;
		28) echo "A conexão demorou demais e foi cancelada. A internet pode estar lenta ou instável." ;;
		5)  echo "Não foi possível encontrar o proxy configurado. Confira as variáveis http_proxy/https_proxy." ;;
		52|56)
		    echo "A conexão caiu no meio do caminho. A internet pode estar instável,"
		    echo "ou um firewall/proxy da sua rede está bloqueando o Telegram."
		    echo "Em algumas redes (trabalho, escola) ou países o Telegram é bloqueado: tente outra rede." ;;
		35|60|77)
		    echo "Falha no certificado de segurança (SSL). Normalmente se resolve instalando os certificados:"
		    echo "  $(install_command ca-certificates)"
		    echo "Também confira se a data e a hora do aparelho estão certas." ;;
		*)  echo "O curl falhou com o código $1. Verifique a sua conexão com a internet." ;;
	esac
}

# Chama um método da API do Telegram direto pelo curl (antes do ShellBot iniciar).
#   telegram_api getMe
#   telegram_api getChat chat_id=-100123
# A resposta fica em $TG_RESPONSE. Retorna o código do curl.
telegram_api() {
	local method=$1 arg args=(); shift
	for arg in "$@"; do args+=(--data-urlencode "$arg"); done
	TG_RESPONSE=$(curl -sS --max-time 20 "https://api.telegram.org/bot${bot_token}/${method}" "${args[@]}" 2>/dev/null)
}

# Traduz as mensagens de erro mais comuns do Telegram para uma explicação.
#   explain_telegram_error "descrição do erro" [chat_id]
explain_telegram_error() {
	local msg chat=${2:-?}
	msg=$(tr '[:upper:]' '[:lower:]' <<< "$1")

	case $msg in
		*"chat not found"*)
			echo "O chat $chat não foi encontrado."
			echo "Se for um canal: confira o ID no config.sh (começa com -100) e se o bot foi adicionado como administrador."
			echo "Se for uma pessoa: ela precisa abrir o bot e enviar /start antes de receber mensagens." ;;
		*"bot can't initiate conversation"*)
			echo "O bot não pode mandar mensagem para $chat porque essa pessoa nunca falou com ele."
			echo "Peça para ela abrir o bot no Telegram e enviar /start." ;;
		*"bot was blocked by the user"*)
			echo "A pessoa $chat bloqueou o bot. Ela precisa desbloquear o bot no Telegram para voltar a receber mensagens." ;;
		*"user is deactivated"*)
			echo "A conta $chat foi apagada no Telegram." ;;
		*"not enough rights"*|*"need administrator rights"*|*"have no rights to send"*)
			echo "O bot não tem permissão para publicar em $chat."
			echo "No canal, vá em Administradores e dê ao bot a permissão \"Publicar mensagens\"." ;;
		*"bot is not a member"*|*"bot was kicked"*)
			echo "O bot não faz parte de $chat (foi removido ou nunca foi adicionado)."
			echo "Adicione o bot de novo como administrador do canal." ;;
		*"can't parse entities"*)
			echo "A mensagem tem caracteres de formatação (* _ \` [) sem par, e o Telegram não conseguiu entender."
			echo "Confira se todo * e _ abre e fecha corretamente." ;;
		*"message is too long"*)
			echo "A mensagem passou do limite de 4096 caracteres do Telegram. Divida em partes menores." ;;
		*"message to forward not found"*|*"message to copy not found"*)
			echo "A mensagem original não existe mais (provavelmente foi apagada)." ;;
		*"too many requests"*|*"retry after"*)
			echo "O Telegram pediu para o bot ir mais devagar (muitas mensagens em pouco tempo). Ele vai tentar de novo depois." ;;
		*"terminated by other getupdates"*|*"conflict"*)
			echo "Tem outro programa usando o mesmo token ao mesmo tempo."
			echo "Provavelmente o bot já está rodando em outro terminal (ou o teste.sh/ids.sh está aberto)."
			echo "Feche a outra cópia. Para encontrar: ps aux | grep -E 'main.sh|teste.sh'" ;;
		*"webhook is active"*)
			echo "Este bot está configurado com um webhook, e assim ele não recebe mensagens deste jeito."
			echo "Para desativar, rode:"
			echo "  curl \"https://api.telegram.org/bot<SEU_TOKEN>/deleteWebhook\"" ;;
		*"unauthorized"*|*": 401:"*)
			echo "O Telegram recusou o token. Ele pode ter sido trocado (/revoke) ou digitado errado."
			echo "Envie /token para o @BotFather para ver o token atual e atualize o config.sh." ;;
		*"desconhecido"*|"")
			echo "O Telegram não respondeu. Verifique a sua conexão com a internet." ;;
		*)
			echo "Resposta do Telegram: $1" ;;
	esac
}

# Testa internet, token e canal antes de iniciar o bot.
check_telegram() {
	local code desc status

	# --- Conexão e token ---
	telegram_api getMe
	code=$?
	if (( code != 0 )); then
		error_box "Não foi possível conectar ao Telegram" <<EOF
$(explain_curl_error "$code")
EOF
		return 1
	fi

	if [[ $(jq -r '.ok' <<< "$TG_RESPONSE" 2>/dev/null) != true ]]; then
		desc=$(jq -r '.description // empty' <<< "$TG_RESPONSE" 2>/dev/null)
		error_box "O Telegram recusou o token do bot" <<EOF
Resposta do Telegram: ${desc:-sem resposta}

Isso acontece quando o token foi digitado errado ou foi trocado no @BotFather.
Envie /token para o @BotFather, escolha o seu bot e copie o token atual
para o config.sh.
EOF
		return 1
	fi

	BOT_USERNAME=$(jq -r '.result.username' <<< "$TG_RESPONSE")
	BOT_USER_ID=$(jq -r '.result.id' <<< "$TG_RESPONSE")
	ok "Token válido: @${BOT_USERNAME}"

	# Scripts que não publicam no canal (ids.sh, teste.sh) pulam esta parte
	if [[ ${REQUIRE_CHANNEL:-true} == true ]]; then

		# --- Canal ---
		telegram_api getChat "chat_id=$channel_id"
		if [[ $(jq -r '.ok' <<< "$TG_RESPONSE" 2>/dev/null) != true ]]; then
			desc=$(jq -r '.description // empty' <<< "$TG_RESPONSE" 2>/dev/null)
			error_box "O bot não consegue acessar o canal $channel_id" <<EOF
$(explain_telegram_error "$desc" "$channel_id")

Lembre que o bot é o @${BOT_USERNAME}: é ele que precisa estar no canal.

EOF
			guide_channel
			echo >&2
			return 1
		fi

		# Em canais, o bot precisa ser administrador com permissão de publicar
		if [[ $(jq -r '.result.type' <<< "$TG_RESPONSE") == channel ]]; then
			local title
			title=$(jq -r '.result.title' <<< "$TG_RESPONSE")
			telegram_api getChatMember "chat_id=$channel_id" "user_id=$BOT_USER_ID"
			status=$(jq -r '.result.status // empty' <<< "$TG_RESPONSE" 2>/dev/null)

			if [[ $status != administrator ]]; then
				error_box "O bot não é administrador do canal \"$title\"" <<EOF
Para publicar em um canal, o @${BOT_USERNAME} precisa ser administrador.
Abra o canal → toque no nome dele → Administradores → Adicionar administrador,
procure @${BOT_USERNAME} e deixe marcada a permissão "Publicar mensagens".
EOF
				return 1
			fi

			if [[ $(jq -r '.result.can_post_messages' <<< "$TG_RESPONSE") == false ]]; then
				error_box "O bot não tem permissão para publicar no canal \"$title\"" <<EOF
O @${BOT_USERNAME} é administrador, mas está sem a permissão "Publicar mensagens".
Abra o canal → Administradores → @${BOT_USERNAME} e ative essa permissão.
EOF
				return 1
			fi
			ok "Canal: $title"
		fi
	fi
}

# Roda todas as verificações, na ordem. Para no primeiro grupo que falhar,
# porque as verificações seguintes dependem das anteriores.
check_everything() {
	check_bash_version                  || return 1
	check_dependencies curl jq getopt bc || return 1
	check_config                        || return 1
	check_telegram                      || return 1
}

# ---------------------------------------------------------------------------
# Envio de mensagens com explicação em caso de erro (com o ShellBot já iniciado)
# ---------------------------------------------------------------------------

# Envia uma mensagem e, se falhar, explica o motivo na tela.
# A explicação também fica em $LAST_ERROR, caso precise mostrar no Telegram.
#   send_message chat_id "texto" [opções extras do ShellBot.sendMessage]
send_message() {
	local chat=$1 text=$2 output
	shift 2
	LAST_ERROR=""

	output=$(ShellBot.sendMessage --chat_id "$chat" --text "$text" "$@" 2>&1 >/dev/null) && return 0

	LAST_ERROR=$(explain_telegram_error "$output" "$chat")
	log "Não foi possível enviar a mensagem para $chat."
	sed 's/^/    /' <<< "$LAST_ERROR" >&2
	return 1
}
