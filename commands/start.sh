#!/bin/bash

# Importar as configurações
source config.sh

# Função para gerar nome secreto aleatório
generate_secret_name() {
	while :; do
		secret_name=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
		# Verifica se o nome secreto já existe no arquivo
		grep -q "^${secret_name}=" secret_names.sh 2>/dev/null || break
	done
	echo "$secret_name"
}

# Função para cadastrar novo usuário
register_new_user() {
	chat_id=$1
	# Gerar nome secreto
	secret_name=$(generate_secret_name)

	# Salvar no arquivo secret_names.sh
	echo "${secret_name}=${chat_id}" >> secret_names.sh

	# Adicionar chat_id ao users_id no config.sh
	sed -i "s/^users_id=(/users_id=(${chat_id} /" config.sh

	# Criar arquivo do usuário
	user_file="users/${chat_id}"
	echo "created_at='$(date)'" > "$user_file"
	echo "tags=()" >> "$user_file"
	echo "banned=false" >> "$user_file"
	echo "ban_time=\"\"" >> "$user_file"
	echo "yellow_cards=0" >> "$user_file"

	# Enviar mensagem de boas-vindas
	welcome_message="🎉 *Bem-vindo ao nosso chat anônimo!*\n\n\
Aqui você pode conversar com desconhecidos de forma anônima.\n\n\
📌 *Regras e informações importantes:*\n\
1. Seja respeitoso e amigável.\n\
2. Não compartilhe informações pessoais.\n\
3. Não nos responsabilizamos pelo conteúdo das conversas.\n\
4. Ao continuar, você concorda com os nossos Termos de Uso.\n\n\
Digite /new para começar a conversar! ;)\n\
Digite /help para mais informações e comandos disponíveis.\n\n\
Créditos: Esse bot foi criado por @SrKubitschek usando ShellBot.sh, do usuário do GitHub SHELLSCRIPTX."

	ShellBot.sendMessage --chat_id "$chat_id" --text "$welcome_message" --parse_mode markdown
}

# Função para usuário existente
welcome_back_user() {
	chat_id=$1

	welcome_back_message="👋 *Bem-vindo de volta ao chat anônimo!*\n\n\
Continue explorando e fazendo conexões. Use /help para relembrar os comandos disponíveis.\n\n\
📌 Lembre-se: Ao continuar, você concorda com os nossos Termos de Uso."

	ShellBot.sendMessage --chat_id "$chat_id" --text "$welcome_back_message" --parse_mode markdown
}

# Verificar se o usuário já está registrado
if [[ " ${users_id[@]} " =~ " ${1} " ]]; then
	welcome_back_user "$1"
else
	register_new_user "$1"
fi
