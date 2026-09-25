#!/bin/bash
set -e
export TZ="Europe/Paris"

ESPN="https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1"
PSG_ID="160"

SCHEDULE=$(curl -sf "$ESPN/teams/$PSG_ID/schedule" || echo '{}')

echo "=== SCHEDULE KEYS ===" >&2
echo "$SCHEDULE" | jq 'keys' >&2

echo "=== TOTAL EVENTS ===" >&2
echo "$SCHEDULE" | jq '[.events[]?] | length' >&2

echo "=== LAST COMPLETED EVENT (compact) ===" >&2
echo "$SCHEDULE" | jq '[.events[]? | select(.competitions[0].status.type.completed == true)] | last | {id, date, name, status: .status.type.name, competitors: [.competitions[0].competitors[]? | {homeAway, teamId: .team.id, teamName: .team.displayName, score}]}' >&2

echo "=== ALL NON-COMPLETED EVENTS ===" >&2
echo "$SCHEDULE" | jq '[.events[]? | select(.competitions[0].status.type.completed != true)] | [.[]? | {id, date, name, status: .status.type.name}]' >&2

echo "=== SCOREBOARD TEST ===" >&2
SCOREBOARD=$(curl -sf "$ESPN/scoreboard" || echo '{}')
echo "$SCOREBOARD" | jq --arg pid "$PSG_ID" '[.events[]? | select(.competitions[0].competitors[]?.team.id == $pid) | {id, date, name}]' >&2

# Dummy index.html pour eviter erreur git
echo '<html><body>debug</body></html>' > index.html
