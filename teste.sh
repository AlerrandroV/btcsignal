#!/bin/bash

# Script de teste: encaminha toda mensagem recebida pelo bot para os administradores.
# Não rode junto com o main.sh: os dois usam o mesmo token e disputam as mensagens.

if [ -z "$BASH_VERSION" ]; then
	echo "✗ Este script precisa ser executado com o bash. Rode assim:  bash teste.sh" >&2
	exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Verifica dependências, config.sh e token (com explicações se algo faltar).
# O canal não é necessário para este teste.
source checks.sh
REQUIRE_CHANNEL=false
check_everything || exit 1

if (( ${#admins_id[@]} == 0 )); then
	error_box "Nenhum administrador configurado" <<EOT
Este teste encaminha as mensagens recebidas para os administradores,
então precisa de pelo menos um ID em admins_id no config.sh.

EOT
	guide_admin_id
	exit 1
fi

# Importa a API ShellBot
source ShellBot.sh

# Inicializa o bot
ShellBot.init --token "$bot_token" --monitor >/dev/null  # a saída normal mostra o token na tela

# Função para encaminhar mensagens recebidas para os administradores
# (esta versão do ShellBot não tem copyMessage, então usamos forwardMessage)
copy_to_admins() {
    local chat_id="$1"
    local message_id="$2"
    local output

    for admin in "${admins_id[@]}"; do
        output=$(ShellBot.forwardMessage --chat_id "$admin" --from_chat_id "$chat_id" --message_id "$message_id" 2>&1 >/dev/null) || {
            log "Não foi possível encaminhar a mensagem para o administrador $admin."
            explain_telegram_error "$output" "$admin" | sed 's/^/    /' >&2
        }
    done
}

updates_err=$(mktemp)
trap 'rm -f "$updates_err"; echo "Encerrando o teste..."; exit 0' SIGINT SIGTERM

ok "Teste rodando: envie mensagens para @${BOT_USERNAME}. Para encerrar, aperte Ctrl+C."

# Loop principal para processar mensagens
while :; do
    if ! ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30 2>"$updates_err"; then
        log "Não foi possível receber mensagens do Telegram. Tentando de novo em 15 segundos."
        explain_telegram_error "$(<"$updates_err")" | sed 's/^/    /' >&2
        sleep 15
        continue
    fi

    for id in $(ShellBot.ListUpdates); do
        # Copia a mensagem recebida para os administradores
        if [[ ${message_chat_id[$id]} && ${message_message_id[$id]} ]]; then
            copy_to_admins "${message_chat_id[$id]}" "${message_message_id[$id]}"
        fi
    done
done
