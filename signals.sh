#!/bin/bash

# Variáveis para armazenar o preço anterior em BRL, USD e EUR
previous_prices=(0 0 0)
streaks=(0 0 0)
last_trends=("none" "none" "none") # Armazena a última tendência (alta/baixa)

# Função para consultar o preço do Bitcoin em várias moedas (BRL, USD, EUR)
get_bitcoin_prices() {
	local api_url="https://api.yadio.io/exrates/BTC"
	local response=$(curl -s "$api_url")
	local brl=$(echo "$response" | grep -o '"BRL":[0-9.]*' | cut -d':' -f2)
	local usd=$(echo "$response" | grep -o '"USD":[0-9.]*' | cut -d':' -f2)
	local eur=$(echo "$response" | grep -o '"EUR":[0-9.]*' | cut -d':' -f2)

	# Retorna os valores separados por "|"
	echo "$brl|$usd|$eur"
}

# Função para consultar volume e variação em 24h
get_volume_and_variation() {
	local api_url="https://cointradermonitor.com/api/pbb/v1/ticker"
	local response=$(curl -s "$api_url")
	local volume=$(echo "$response" | grep -o '"volume24h":[0-9.]*' | cut -d':' -f2)
	local variation=$(echo "$response" | grep -o '"var24h":[0-9.-]*' | cut -d':' -f2)

	# Retorna os valores separados por "|"
	echo "$volume|$variation"
}

# Função para formatar números com separação de milhares e sem casas decimais
format_number() {
	printf "%'.0f" "$1"
}

# Função para enviar uma mensagem de atualização ao canal
send_to_channel() {
	# Obtemos os dados da função get_bitcoin_prices
	local price_data=($(get_bitcoin_prices | tr '|' ' '))
	local brl=${price_data[0]}
	local usd=${price_data[1]}
	local eur=${price_data[2]}

	# Verifica se os valores são válidos antes de usar `bc`
	if [[ -z $brl || -z $usd || -z $eur ]]; then
		echo "Erro: Valores de preço inválidos."
		return
	fi

	# Obtemos os dados de volume e variação
	local volume_data=($(get_volume_and_variation | tr '|' ' '))
	local volume=${volume_data[0]}
	local variation=${volume_data[1]}

	# Verifica se houve mudança em qualquer uma das cotações (BRL, USD, EUR)
	if (( $(echo "$brl != ${previous_prices[0]}" | bc -l) )) || \
	   (( $(echo "$usd != ${previous_prices[1]}" | bc -l) )) || \
	   (( $(echo "$eur != ${previous_prices[2]}" | bc -l) )); then

		local trends=()
		for i in {0..2}; do
			local current_price
			local current_trend="none"

			if [ $i -eq 0 ]; then current_price=$brl; fi
			if [ $i -eq 1 ]; then current_price=$usd; fi
			if [ $i -eq 2 ]; then current_price=$eur; fi

			# Verifica tendência (alta/baixa/estável) e atualiza streak
			if (( $(echo "$current_price > ${previous_prices[$i]}" | bc -l) )); then
				current_trend="up"
				trends[$i]="🟢"
			elif (( $(echo "$current_price < ${previous_prices[$i]}" | bc -l) )); then
				current_trend="down"
				trends[$i]="🔴"
			else
				current_trend="neutral"
				trends[$i]="⚪"
			fi

			# Atualiza o streak
			if [[ ${last_trends[$i]} != "$current_trend" ]]; then
				streaks[$i]=1
			else
				streaks[$i]=$((streaks[$i] + 1))
			fi

			# Atualiza os valores para a próxima verificação
			last_trends[$i]=$current_trend
			previous_prices[$i]=$current_price
		done

		local message="*Cotação Bitcoin:*
\`${trends[0]}×${streaks[0]} BRL: $(format_number $brl)\`
\`${trends[1]}×${streaks[1]} USD: $(format_number $usd)\`
\`${trends[2]}×${streaks[2]} EUR: $(format_number $eur)\`
Fonte: yadio.io

\`📊Volume (24h):   $(printf '%.2f' $volume) BTC\`
\`⬆️Variação (24h): $(printf '%.2f' $variation)%\`
Fonte: cointradermonitor.com

> Sua sugestão é sempre bem-vinda!
— @SrKubitschek"

		# Envia a mensagem ao canal configurado no `config.sh`
		ShellBot.sendMessage --chat_id "$channel_id" --text "$message" --parse_mode markdown
	fi
}

# Função para iniciar o loop de sinais
start_signals() {
	while :; do
		send_to_channel
		sleep 60
	done
}
