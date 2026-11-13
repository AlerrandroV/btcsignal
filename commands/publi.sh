#!/bin/bash

# Comando /publi (somente administradores)
# Publica uma mensagem no canal configurado em config.sh.
#
# Formas de uso:
#   /publi Seu texto aqui          -> publica o texto no canal
#   /publi (respondendo a uma msg) -> publica a mensagem respondida no canal
#                                     (texto é reenviado; fotos, vídeos etc. são encaminhados)

admin_chat="${message_chat_id[$id]}"

# Texto que veio depois de "/publi" (ou "/publi@NomeDoBot")
publi_text="${message_text[$id]#/publi}"
publi_text="${publi_text#@*[[:space:]]}"
[[ ${message_text[$id]} =~ ^/publi@[^[:space:]]*$ ]] && publi_text=""
publi_text="${publi_text#"${publi_text%%[![:space:]]*}"}"   # remove espaços no início

reply_id="${message_reply_to_message_message_id[$id]}"
reply_text="${message_reply_to_message_text[$id]}"

# Avisa o administrador do resultado. Em caso de erro, manda também a explicação.
report_publi() {
	if (( $1 == 0 )); then
		send_message "$admin_chat" "$2"
	else
		send_message "$admin_chat" "✗ Não consegui publicar no canal.

${LAST_ERROR}"
	fi
}

if [[ -n $publi_text ]]; then
	send_message "$channel_id" "$publi_text"
	report_publi $? "✓ Publicado no canal."

elif [[ -n $reply_id && -n $reply_text ]]; then
	send_message "$channel_id" "$reply_text"
	report_publi $? "✓ Publicado no canal."

elif [[ -n $reply_id ]]; then
	LAST_ERROR=""
	if ! forward_output=$(ShellBot.forwardMessage --chat_id "$channel_id" --from_chat_id "$admin_chat" --message_id "$reply_id" 2>&1 >/dev/null); then
		LAST_ERROR=$(explain_telegram_error "$forward_output" "$channel_id")
		log "Não foi possível encaminhar a mensagem para o canal."
		sed 's/^/    /' <<< "$LAST_ERROR" >&2
		false
	fi
	report_publi $? "✓ Encaminhado para o canal."

else
	send_message "$admin_chat" "Uso:
/publi Seu texto aqui
ou responda a uma mensagem com /publi"
fi
