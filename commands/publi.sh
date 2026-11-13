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

if [[ -n $publi_text ]]; then
	ShellBot.sendMessage --chat_id "$channel_id" --text "$publi_text" &&
		ShellBot.sendMessage --chat_id "$admin_chat" --text "✓ Publicado no canal."

elif [[ -n $reply_id && -n $reply_text ]]; then
	ShellBot.sendMessage --chat_id "$channel_id" --text "$reply_text" &&
		ShellBot.sendMessage --chat_id "$admin_chat" --text "✓ Publicado no canal."

elif [[ -n $reply_id ]]; then
	ShellBot.forwardMessage --chat_id "$channel_id" --from_chat_id "$admin_chat" --message_id "$reply_id" &&
		ShellBot.sendMessage --chat_id "$admin_chat" --text "✓ Encaminhado para o canal."

else
	ShellBot.sendMessage --chat_id "$admin_chat" --text "Uso:
/publi Seu texto aqui
ou responda a uma mensagem com /publi"
fi
