#!/bin/bash

# Importa as configurações e a API ShellBot
source config.sh
source ShellBot.sh

# Inicializa o bot
ShellBot.init --token "$bot_token" --monitor

# Função para copiar mensagens recebidas para os administradores
copy_to_admins() {
    local chat_id="$1"
    local message_id="$2"

    for admin in "${admins_id[@]}"; do
        ShellBot.copyMessage --chat_id "$admin" --from_chat_id "$chat_id" --message_id "$message_id"
    done
}

# Loop principal para processar mensagens
while :; do
    ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30

    for id in $(ShellBot.ListUpdates); do
        # Copia a mensagem recebida para os administradores
        if [[ ${message_chat_id[$id]} && ${message_message_id[$id]} ]]; then
            copy_to_admins "${message_chat_id[$id]}" "${message_message_id[$id]}"
        fi
    done
done

