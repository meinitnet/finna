#!/usr/bin/env bash
# Fetches upcoming tour dates from kiosque-booking.com and writes them into
# index.html as the meta description / og:description.
set -euo pipefail

SOURCE_URL="https://www.kiosque-booking.com/artists/finna/"
INDEX_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/index.html"
TMP_HTML="$(mktemp)"
trap 'rm -f "$TMP_HTML"' EXIT

curl -fsSL -A "Mozilla/5.0" "$SOURCE_URL" -o "$TMP_HTML"

# dates (YYYY-MM-DD) and cities appear in the same order, one per show row.
mapfile -t dates < <(grep -oP '(?<=<td class="date" date=")[^"]+' "$TMP_HTML")
mapfile -t cities < <(grep -oP '(?<=<b>)[^<]+' "$TMP_HTML")

if [[ ${#dates[@]} -eq 0 ]]; then
	echo "No tour dates found on $SOURCE_URL" >&2
	exit 1
fi

entries=()
for i in "${!dates[@]}"; do
	# YYYY-MM-DD -> DD.MM.
	formatted="$(date -d "${dates[$i]}" +'%d.%m.')"
	entries+=("${formatted} ${cities[$i]}")
done

# Limit to the next few dates so the description stays a reasonable length.
max_entries=4
list=""
for entry in "${entries[@]:0:$max_entries}"; do
	list="${list:+${list}, }${entry}"
done

description="Finna live: ${list}. Tickets, Musik und News auf finnamusik.de."

escaped="$(printf '%s' "$description" | sed 's/[&/\]/\\&/g')"

sed -i \
	-e "s|<meta name=\"description\" content=\"[^\"]*\">|<meta name=\"description\" content=\"${escaped}\">|" \
	-e "s|<meta property=\"og:description\" content=\"[^\"]*\">|<meta property=\"og:description\" content=\"${escaped}\">|" \
	"$INDEX_FILE"

echo "Updated meta description: $description"
