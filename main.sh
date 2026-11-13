#!/bin/bash

# Importando as configurações, a API ShellBot e o script de sinais
source config.sh
source ShellBot.sh
source signals.sh

# Inicializando o bot
ShellBot.init --token "$bot_token" --monitor

# Mensagem inicial para os administradores
for i in "${!admins_id[@]}"; do
	ShellBot.sendMessage --chat_id "${admins_id[i]}" --text "✓ Bot iniciado com sucesso."
done

# Função principal que chama os scripts de comando
handle_command() {
	case $1 in
		"/start")
			source ./commands/start.sh "${message_chat_id[$id]}"
			;;
		"/help")
			source ./commands/help.sh "${message_chat_id[$id]}"
			;;
		"/new")
			source ./commands/new.sh "${message_chat_id[$id]}"
			;;
		"/stop")
			source ./commands/stop.sh "${message_chat_id[$id]}"
			;;
		"/publi")
			if [[ " ${admins_id[@]} " =~ " ${message_from_id[$id]} " ]]; then
				source ./commands/publi.sh
			fi
			;;
		*)
			;;
	esac
}

# Função para encerrar o bot e os processos em background
stop_bot() {
	echo "Encerrando o bot..."
	kill $signals_pid 2>/dev/null  # Encerra o processo de sinais
	exit 0
}

# Captura sinais de interrupção (Ctrl+C) e encerra o bot
trap stop_bot SIGINT SIGTERM

# Inicia o loop de sinais em background
start_signals &
signals_pid=$!  # Captura o PID do processo de sinais

# Loop principal para processar as mensagens
while :
do
	# Obtemos as atualizações
	ShellBot.getUpdates --limit 30 --offset $(ShellBot.OffsetNext) --timeout 30

	# Processa as atualizações
	for id in $(ShellBot.ListUpdates); do
		handle_command "${message_text[$id]}"
	done
done
