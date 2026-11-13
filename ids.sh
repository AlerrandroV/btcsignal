#!/bin/bash

# Mostra os IDs de quem conversou com o bot e dos canais/grupos onde ele está.
# Útil para preencher admins_id e channel_id no config.sh.
#
# Antes de rodar:
#   - para descobrir o SEU ID: envie /start para o bot no Telegram;
#   - para descobrir o ID do CANAL: adicione o bot como administrador
#     e envie uma mensagem qualquer no canal.

if [ -z "$BASH_VERSION" ]; then
	echo "✗ Este script precisa ser executado com o bash. Rode assim:  bash ids.sh" >&2
	exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

source checks.sh

# Aqui só precisamos do token: o canal ainda pode não estar configurado
REQUIRE_CHANNEL=false
check_everything || exit 1

telegram_api getUpdates
code=$?
if (( code != 0 )); then
	error_box "Não foi possível conectar ao Telegram" <<EOT
$(explain_curl_error "$code")
EOT
	exit 1
fi

if [[ $(jq -r '.ok' <<< "$TG_RESPONSE") != true ]]; then
	error_box "O Telegram não entregou as mensagens do bot" <<EOT
$(explain_telegram_error "$(jq -r '.description // empty' <<< "$TG_RESPONSE")")
EOT
	exit 1
fi

# Pessoas que mandaram mensagem para o bot
people=$(jq -r '
	[.result[] | (.message // .edited_message // empty) | select(.chat.type == "private") | .from]
	| unique_by(.id) | .[]
	| "  \(.first_name)\(if .username then " (@\(.username))" else "" end) → \(.id)"
' <<< "$TG_RESPONSE")

# Canais e grupos onde o bot apareceu (inclusive quando ele foi adicionado)
chats=$(jq -r '
	[.result[] | (.channel_post // .edited_channel_post // .my_chat_member // .message // empty) | .chat
	 | select(.type != "private")]
	| unique_by(.id) | .[]
	| "  \(.title) (\(if .type == "channel" then "canal" else "grupo" end)) → \(.id)"
' <<< "$TG_RESPONSE")

echo
if [[ -n $people ]]; then
	echo "${_C_BLD}Pessoas que falaram com o bot${_C_RST} (use em admins_id):"
	echo "$people"
else
	echo "${_C_BLD}Nenhuma pessoa encontrada.${_C_RST}"
	echo "  Abra @${BOT_USERNAME} no Telegram, envie /start e rode este script de novo."
fi

echo
if [[ -n $chats ]]; then
	echo "${_C_BLD}Canais e grupos${_C_RST} (use em channel_id):"
	echo "$chats"
else
	echo "${_C_BLD}Nenhum canal encontrado.${_C_RST}"
	echo "  Adicione @${BOT_USERNAME} como administrador do canal, envie uma"
	echo "  mensagem qualquer no canal e rode este script de novo."
fi

cat <<EOT

Exemplo de como fica no config.sh:
  admins_id=(123456789)
  channel_id="-1001234567890"

Obs.: o Telegram só guarda as mensagens das últimas 24 horas, e elas somem
daqui quando o bot (main.sh) as lê. Se não aparecer o que você esperava,
pare o bot, envie uma nova mensagem e rode este script de novo.
EOT
