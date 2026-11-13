#!/bin/bash

# Variáveis para armazenar o preço anterior em BRL, USD e EUR
previous_prices=(0 0 0)
streaks=(0 0 0)
last_trends=("none" "none" "none") # Armazena a última tendência (alta/baixa)

# Guarda se a última consulta falhou, para avisar só quando a situação muda
# (e não repetir o mesmo erro a cada minuto)
price_source_failing=false
volume_source_failing=false

# Faz uma requisição. A resposta fica em $FETCH_RESPONSE; se falhar,
# a explicação fica em $FETCH_ERROR.
#   fetch_json "nome da fonte" "url"
fetch_json() {
	local name=$1 url=$2 code
	FETCH_ERROR=""
	FETCH_RESPONSE=$(curl -sS --max-time 20 "$url" 2>/dev/null)
	code=$?
	if (( code != 0 )); then
		FETCH_ERROR="$(explain_curl_error "$code")"
		return 1
	fi
	if [[ -z $FETCH_RESPONSE ]]; then
		FETCH_ERROR="O site $name respondeu vazio. Pode estar fora do ar."
		return 1
	fi
}

# Função para consultar o preço do Bitcoin em várias moedas (BRL, USD, EUR)
get_bitcoin_prices() {
	local api_url="https://api.yadio.io/exrates/BTC"
	fetch_json "yadio.io" "$api_url" || return 1
	local response=$FETCH_RESPONSE
	local brl=$(echo "$response" | grep -o '"BRL":[0-9.]*' | cut -d':' -f2)
	local usd=$(echo "$response" | grep -o '"USD":[0-9.]*' | cut -d':' -f2)
	local eur=$(echo "$response" | grep -o '"EUR":[0-9.]*' | cut -d':' -f2)

	# Guarda os valores separados por "|" (em variável, e não com echo,
	# para que $FETCH_ERROR também chegue até quem chamou a função)
	PRICES="$brl|$usd|$eur"
}

# Função para consultar volume e variação em 24h
get_volume_and_variation() {
	local api_url="https://cointradermonitor.com/api/pbb/v1/ticker"
	fetch_json "cointradermonitor.com" "$api_url" || return 1
	local response=$FETCH_RESPONSE
	local volume=$(echo "$response" | grep -o '"volume24h":[0-9.]*' | cut -d':' -f2)
	local variation=$(echo "$response" | grep -o '"var24h":[0-9.-]*' | cut -d':' -f2)

	# Guarda os valores separados por "|"
	VOLUME_DATA="$volume|$variation"
}

# Função para formatar números com separação de milhares e sem casas decimais
# (corta as casas decimais antes, para não depender do idioma do sistema,
#  que no português usa vírgula e faria o printf reclamar do ponto)
format_number() {
	printf "%'d" "${1%.*}"
}

# Formata com 2 casas decimais, sempre lendo o número com ponto
format_decimal() {
	LC_NUMERIC=C printf '%.2f' "$1"
}

# Função para enviar uma mensagem de atualização ao canal
send_to_channel() {
	# Obtemos os dados da função get_bitcoin_prices
	PRICES=""
	get_bitcoin_prices
	local price_data=(${PRICES//|/ })
	local brl=${price_data[0]}
	local usd=${price_data[1]}
	local eur=${price_data[2]}

	# Verifica se os valores são válidos antes de usar `bc`
	if [[ -z $brl || -z $usd || -z $eur ]]; then
		if ! $price_source_failing; then
			log "Não foi possível obter a cotação no yadio.io. Nada foi publicado; tentando de novo a cada minuto."
			echo "    ${FETCH_ERROR:-O site respondeu, mas sem os preços em BRL, USD e EUR. Ele pode estar com problemas ou ter mudado o formato.}" >&2
			price_source_failing=true
		fi
		return
	fi
	if $price_source_failing; then
		log "A cotação voltou a funcionar."
		price_source_failing=false
	fi

	# Obtemos os dados de volume e variação (se falhar, a mensagem sai sem eles)
	VOLUME_DATA=""
	get_volume_and_variation
	local volume_data=(${VOLUME_DATA//|/ })
	local volume=${volume_data[0]}
	local variation=${volume_data[1]}

	if [[ -z $volume || -z $variation ]]; then
		if ! $volume_source_failing; then
			log "Não foi possível obter volume e variação no cointradermonitor.com. A mensagem vai sair sem esses dados."
			echo "    ${FETCH_ERROR:-O site respondeu, mas sem os dados de volume e variação.}" >&2
			volume_source_failing=true
		fi
	elif $volume_source_failing; then
		log "Volume e variação voltaram a funcionar."
		volume_source_failing=false
	fi

	local volume_text="indisponível" variation_text="indisponível"
	[[ -n $volume ]] && volume_text="$(format_decimal "$volume") BTC"
	[[ -n $variation ]] && variation_text="$(format_decimal "$variation")%"

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

\`📊Volume (24h):   $volume_text\`
\`⬆️Variação (24h): $variation_text\`
Fonte: cointradermonitor.com

> Sua sugestão é sempre bem-vinda!
— @SrKubitschek"

		# Envia a mensagem ao canal configurado no `config.sh`
		# (se falhar, send_message explica o motivo na tela)
		send_message "$channel_id" "$message" --parse_mode markdown
	fi
}

# Função para iniciar o loop de sinais
start_signals() {
	while :; do
		send_to_channel
		sleep 60
	done
}
