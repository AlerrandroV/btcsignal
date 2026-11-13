#!/bin/bash

# Baixa a versão mais recente do BTC Signal e já inicia o bot.
#
# Uso:
#   bash update.sh
#
# Os seus dados não são tocados: config.sh, a pasta users/ e o secret_names.sh
# ficam como estão. Também serve para a primeira instalação: coloque este
# arquivo numa pasta vazia e rode.

if [ -z "$BASH_VERSION" ]; then
	echo "✗ Este script precisa ser executado com o bash. Rode assim:  bash update.sh" >&2
	exit 1
fi

REPO="AlerrandroV/btcsignal"
BRANCH="ccr-86c2cc7d-dygqk2"
URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"

# Arquivos e pastas do usuário que nunca são substituídos
KEEP=(config.sh users secret_names.sh)

# Todo o script fica dentro de uma função: assim o bash lê tudo antes de
# começar, e não tem problema se este próprio arquivo for atualizado no meio.
main() {
	local cmd tmp src item

	# Entra na pasta onde este script está
	cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

	for cmd in curl tar; do
		if ! command -v "$cmd" &>/dev/null; then
			echo "✗ O programa \"$cmd\" não está instalado." >&2
			echo "  No Debian/Ubuntu:  sudo apt install $cmd" >&2
			echo "  No Termux:         pkg install $cmd" >&2
			exit 1
		fi
	done

	tmp=$(mktemp -d) || { echo "✗ Não foi possível criar uma pasta temporária." >&2; exit 1; }
	trap 'rm -rf "$tmp"' EXIT

	echo "Baixando a versão mais recente ($BRANCH)..."
	if ! curl -fsSL --max-time 120 "$URL" -o "$tmp/btcsignal.tar.gz"; then
		echo "✗ Não foi possível baixar o código." >&2
		echo "  Verifique a sua conexão com a internet e tente de novo." >&2
		echo "  Endereço: $URL" >&2
		exit 1
	fi

	if ! tar -xzf "$tmp/btcsignal.tar.gz" -C "$tmp"; then
		echo "✗ O arquivo baixado está corrompido. Tente de novo." >&2
		exit 1
	fi

	# O GitHub coloca tudo dentro de uma pasta "btcsignal-<branch>"
	src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)
	if [[ ! -f $src/main.sh ]]; then
		echo "✗ O download não tem o main.sh. O repositório pode ter mudado." >&2
		exit 1
	fi

	# Remove do download o que for do usuário, para não sobrescrever nada
	for item in "${KEEP[@]}"; do
		rm -rf "${src:?}/$item"
	done

	# Copia os arquivos novos por cima dos antigos
	if ! cp -R "$src/." .; then
		echo "✗ Não foi possível copiar os arquivos. Verifique se você tem permissão de escrita nesta pasta." >&2
		exit 1
	fi
	chmod +x ./*.sh 2>/dev/null

	echo "✓ Código atualizado."

	if [[ ! -f config.sh ]]; then
		echo "  (O config.sh ainda não existe: o bot vai mostrar como criar.)"
	fi

	echo "Iniciando o bot..."
	echo
	rm -rf "$tmp"
	trap - EXIT
	exec bash main.sh
}

main "$@"; exit
