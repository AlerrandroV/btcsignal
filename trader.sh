#!/bin/bash

# Simulador de compra e venda no terminal (sem dinheiro real).
# Durante a execução: aperte "b" para forçar uma compra ou "s" para uma venda.

if [ -z "$BASH_VERSION" ]; then
	echo "✗ Este script precisa ser executado com o bash. Rode assim:  bash trader.sh" >&2
	exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Verifica se os programas necessários estão instalados (com explicação se faltar)
source checks.sh
check_bash_version || exit 1
check_dependencies curl jq bc || exit 1

# Configurações iniciais
API_URL="https://cointradermonitor.com/api/pbb/v1/ticker?exchanges=true"
SALDO_BRL=100            # Saldo inicial em BRL (R$100)
SALDO_SATS=1000000       # Saldo inicial em Satoshis (0.01 BTC)
CERTEZA=50               # Nível de certeza inicial (em %)
MIN_CERTEZA_OPERAR=60    # Certeza mínima para operar
VARIACAO_LIMITE=0.5      # Variação mínima para ajustar certeza (em %)
HISTORICO_PRECOS=()      # Histórico de preços para análise de tendência
MAX_HISTORICO=2          # Histórico curto para avaliar acertos (compra/venda recente)
PRECISOES=0              # Número de apostas bem-sucedidas consecutivas
ULTIMA_OPERACAO=""       # Última operação (compra ou venda)
PRECO_OPERACAO=0         # Cotação da última operação
TEMPO_ANTECIPACAO=2      # Tempo de antecipação (em segundos) para não fazer nada imediatamente

# Função para obter os dados da API
obter_dados() {
    curl -sS --max-time 20 "$API_URL" 2>/dev/null
}

# Função para calcular o saldo total
calcular_saldo_total() {
    echo "$SALDO_BRL + ($SALDO_SATS * $1 / 100000000)" | bc -l
}

# Função para calcular o valor da operação baseado na precisão
calcular_valor_operacao() {
    fator=$(echo "scale=2; $PRECISOES / 10" | bc -l)  # Cada precisão aumenta a aposta em 10%
    if (( $(echo "$fator > 1" | bc -l) )); then
        fator=1  # Máximo de 100%
    fi
    echo "($CERTEZA / 100) * 50000 * (1 + $fator)" | bc -l
}

# Função para simular compra de Satoshis
comprar() {
    valor_operacao=$(calcular_valor_operacao)
    sats_comprados=$(echo "($valor_operacao * 100000000) / $1" | bc -l)
    echo ">> Comprando $sats_comprados SATS por $valor_operacao BRL (Certeza: $CERTEZA%)"

    SALDO_BRL=$(echo "$SALDO_BRL - $valor_operacao" | bc -l)
    SALDO_SATS=$(echo "$SALDO_SATS + $sats_comprados" | bc -l)
    ULTIMA_OPERACAO="compra"
    PRECO_OPERACAO=$1
}

# Função para simular venda de Satoshis
vender() {
    valor_operacao=$(calcular_valor_operacao)
    sats_vendidos=$(echo "($valor_operacao * 100000000) / $1" | bc -l)

    # Limitar à quantidade de sats disponíveis
    if (( $(echo "$sats_vendidos > $SALDO_SATS" | bc -l) )); then
        sats_vendidos=$SALDO_SATS
        valor_operacao=$(echo "($sats_vendidos * $1) / 100000000" | bc -l)
    fi

    echo ">> Vendendo $sats_vendidos SATS por $valor_operacao BRL (Certeza: $CERTEZA%)"

    SALDO_BRL=$(echo "$SALDO_BRL + $valor_operacao" | bc -l)
    SALDO_SATS=$(echo "$SALDO_SATS - $sats_vendidos" | bc -l)
    ULTIMA_OPERACAO="venda"
    PRECO_OPERACAO=$1
}

# Função para verificar se a última operação foi um acerto
verificar_acerto() {
    if [[ "$ULTIMA_OPERACAO" == "compra" && $(echo "$1 > $PRECO_OPERACAO" | bc -l) -eq 1 ]]; then
        echo ">> Acerto! Preço subiu após a compra."
        PRECISOES=$((PRECISOES + 1))
    elif [[ "$ULTIMA_OPERACAO" == "venda" && $(echo "$1 < $PRECO_OPERACAO" | bc -l) -eq 1 ]]; then
        echo ">> Acerto! Preço caiu após a venda."
        PRECISOES=$((PRECISOES + 1))
    else
        echo ">> Erro! Operação incorreta."
        PRECISOES=0
    fi
    ULTIMA_OPERACAO=""
}

# Função para exibir as informações formatadas
exibir_informacoes() {
    status="Estável"
    if (( ${#HISTORICO_PRECOS[@]} > 1 )); then
        if (( $(echo "$1 > ${HISTORICO_PRECOS[-2]}" | bc -l) )); then
            status="Alta"
        elif (( $(echo "$1 < ${HISTORICO_PRECOS[-2]}" | bc -l) )); then
            status="Baixa"
        fi
    fi

    saldo_total=$(calcular_saldo_total "$1")
    echo "Cotação: $1 BRL"
    echo "Status: [$status]"
    echo "Saldo A: $SALDO_SATS SATS"
    echo "Saldo B: $SALDO_BRL BRL"
    echo "Saldo A+B: $saldo_total BRL"
    echo "Precisão: [$PRECISOES]"
    echo "————————————————————————"
}

# Loop principal
while true; do
    # Obter dados da API
    dados=$(obter_dados)
    codigo=$?
    preco_atual=$(echo "$dados" | jq -r '.last // empty' 2>/dev/null)

    # Se a cotação não veio, explica e tenta de novo, em vez de fazer contas com valor vazio
    if [[ ! $preco_atual =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log "Não foi possível obter a cotação no cointradermonitor.com. Tentando de novo em 30 segundos."
        if (( codigo != 0 )); then
            explain_curl_error "$codigo" | sed 's/^/    /' >&2
        else
            echo "    O site respondeu, mas sem o preço. Ele pode estar fora do ar ou ter mudado o formato." >&2
        fi
        sleep 30
        continue
    fi

    # Verificar se a última operação foi um acerto
    if [[ -n "$ULTIMA_OPERACAO" ]]; then
        verificar_acerto "$preco_atual"
    fi

    # Adicionar cotação ao histórico
    HISTORICO_PRECOS+=("$preco_atual")
    if (( ${#HISTORICO_PRECOS[@]} > MAX_HISTORICO )); then
        HISTORICO_PRECOS=("${HISTORICO_PRECOS[@]:1}")
    fi

    # Exibir informações formatadas
    exibir_informacoes "$preco_atual"

    # Permitir empurrão humano
    read -t 10 -n 1 entrada
    if [[ "$entrada" == "b" ]]; then
        comprar "$preco_atual"
        continue
    elif [[ "$entrada" == "s" ]]; then
        vender "$preco_atual"
        continue
    fi

    # Aguardar antes de realizar a próxima operação, sem antecipação imediata
    sleep $TEMPO_ANTECIPACAO

    # Decisão automática com base na certeza
    if (( $(echo "$CERTEZA >= $MIN_CERTEZA_OPERAR" | bc -l) )); then
        if (( $(echo "$CERTEZA >= 75" | bc -l) )) && (( $(echo "${HISTORICO_PRECOS[-1]} < ${HISTORICO_PRECOS[-2]}" | bc -l) )); then
            comprar "$preco_atual"
        elif (( $(echo "$CERTEZA >= 75" | bc -l) )) && (( $(echo "${HISTORICO_PRECOS[-1]} > ${HISTORICO_PRECOS[-2]}" | bc -l) )); then
            vender "$preco_atual"
        fi
    else
        echo "Nenhuma operação realizada (Certeza: $CERTEZA%)."
    fi

    # Aguardar antes de verificar novamente
    sleep 10
done

