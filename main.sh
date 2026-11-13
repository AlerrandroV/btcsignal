#!/bin/bash

# O bot precisa do bash. Se alguém rodar com "sh main.sh", explica e sai.
# (Este trecho usa só comandos simples para funcionar em qualquer shell.)
if [ -z "$BASH_VERSION" ]; then
	echo "✗ Este bot precisa ser executado com o bash, não com o sh." >&2
	echo "  Rode assim:  bash main.sh" >&2
	exit 1
fi

# Entra na pasta do bot, para funcionar mesmo se for chamado de outro lugar
# (ex.: bash ~/btcsignal/main.sh)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Verifica dependências, config.sh, token e canal antes de tudo.
# Se algo estiver faltando, mostra o passo a passo e encerra.
source checks.sh
check_everything || exit 1

# Importando a API ShellBot e o script de sinais
source ShellBot.sh
source signals.sh

# Inicializando o bot
# (a saída normal do init mostra o token na tela, por isso vai para /dev/null;
#  erros continuam aparecendo)
ShellBot.init --token "$bot_token" --monitor >/dev/null

# Mensagem inicial para os administradores
# (se falhar, send_message explica o motivo na tela e o bot segue normalmente)
for i in "${!admins_id[@]}"; do
	send_message "${admins_id[i]}" "✓ Bot iniciado com sucesso."
done

# Executa o script de um comando, se ele existir
run_command() {
	local name=$1 script="./commands/$1.sh"
	shift
	if [[ -f $script ]]; then
		source "$script" "$@"
	else
		log "Comando /$name recebido, mas o arquivo $script ainda não existe. Ignorando."
	fi
}

# Função principal que chama os scripts de comando
handle_command() {
	case $1 in
		"/start")
			run_command start "${message_chat_id[$id]}"
			;;
		"/help")
			run_command help "${message_chat_id[$id]}"
			;;
		"/new")
			run_command new "${message_chat_id[$id]}"
			;;
		"/stop")
			run_command stop "${message_chat_id[$id]}"
			;;
		"/publi"|"/publi "*|"/publi@"*)
			if [[ " ${admins_id[@]} " =~ " ${message_from_id[$id]} " ]]; then
				run_command publi
			else
				log "Usuário ${message_from_id[$id]} tentou usar /publi, mas não está em admins_id no config.sh."
				send_message "${message_chat_id[$id]}" "Este comando é só para administradores do bot."
			fi
			;;
		*)
			;;
	esac
}

# Arquivo temporário para capturar os erros do getUpdates
updates_err=$(mktemp)

# Função para encerrar o bot e os processos em background
stop_bot() {
	echo "Encerrando o bot..."
	kill $signals_pid 2>/dev/null  # Encerra o processo de sinais
	rm -f "$updates_err"
	exit 0
}

# Captura sinais de interrupção (Ctrl+C) e encerra o bot
trap stop_bot SIGINT SIGTERM

# Inicia o loop de sinais em background
start_signals &
signals_pid=$!  # Captura o PID do processo de sinais

ok "Bot rodando! Para encerrar, aperte Ctrl+C."

# Loop principal para processar as mensagens
while :
do
	# Obtemos as atualizações
	if ! ShellBot.getUpdates --limit 30 --offset $(ShellBot.OffsetNext) --timeout 30 2>"$updates_err"; then
		# Explica o erro e espera um pouco antes de tentar de novo,
		# para não ficar repetindo o mesmo erro sem parar
		log "Não foi possível receber mensagens do Telegram. Tentando de novo em 15 segundos."
		explain_telegram_error "$(<"$updates_err")" | sed 's/^/    /' >&2
		sleep 15
		continue
	fi

	# Processa as atualizações
	for id in $(ShellBot.ListUpdates); do
		handle_command "${message_text[$id]}"
	done
done
