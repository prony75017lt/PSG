#!/bin/bash
set -e
export TZ="Europe/Paris"

ESPN="https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1"
PSG_ID=160

# --- Calendrier PSG ---
SCHEDULE=$(curl -sf "$ESPN/teams/$PSG_ID/schedule" || echo '{}')

# Dernier match termine
LAST_EVENT=$(echo "$SCHEDULE" | jq '[.events[]? | select(.competitions[0].status.type.completed == true)] | last')
LAST_EVENT_ID=$(echo "$LAST_EVENT" | jq -r '.id // empty')

# Prochain match a venir
NEXT_EVENT=$(echo "$SCHEDULE" | jq '[.events[]? | select(.competitions[0].status.type.completed == false and .competitions[0].status.type.description != "In Progress")] | first')

# --- Donnees du dernier match ---
LAST_DATE=$(echo "$LAST_EVENT" | jq -r '.date // empty')
LAST_HOME=$(echo "$LAST_EVENT" | jq '.competitions[0].competitors[] | select(.homeAway == "home")')
LAST_AWAY=$(echo "$LAST_EVENT" | jq '.competitions[0].competitors[] | select(.homeAway == "away")')

LAST_HOME_NAME=$(echo "$LAST_HOME" | jq -r '.team.shortDisplayName // .team.displayName // "?"')
LAST_AWAY_NAME=$(echo "$LAST_AWAY" | jq -r '.team.shortDisplayName // .team.displayName // "?"')
LAST_HOME_LOGO=$(echo "$LAST_HOME" | jq -r '.team.logo // ""')
LAST_AWAY_LOGO=$(echo "$LAST_AWAY" | jq -r '.team.logo // ""')
LAST_HOME_SCORE=$(echo "$LAST_HOME" | jq -r '.score // "?"')
LAST_AWAY_SCORE=$(echo "$LAST_AWAY" | jq -r '.score // "?"')
LAST_HOME_ID=$(echo "$LAST_HOME" | jq -r '.team.id')
LAST_AWAY_ID=$(echo "$LAST_AWAY" | jq -r '.team.id')

# --- Buteurs (detail du match) ---
HOME_GOALS_HTML=""
AWAY_GOALS_HTML=""
if [ -n "$LAST_EVENT_ID" ]; then
  sleep 1
  SUMMARY=$(curl -sf "$ESPN/summary?event=$LAST_EVENT_ID" || echo '{}')

 echo "DEBUG FULL_GOAL: $(echo "$SUMMARY" | jq '[.keyEvents[] | select(.type.text == "Goal")] | .[0]')" >&2

  HOME_GOALS_HTML=$(echo "$SUMMARY" | jq -r --arg hid "$LAST_HOME_ID" \
    '[.keyEvents[]? // .competitions[0].details[]? | select(.type.text == "Goal" or .type.text == "Goal - Header" or .type.text == "Penalty - Scored") | select(.team.id == $hid) | "\(.athletesInvolved[0].displayName // "?") \(.clock.displayValue // "")"] | join("<br>")' 2>/dev/null || echo "")

  AWAY_GOALS_HTML=$(echo "$SUMMARY" | jq -r --arg aid "$LAST_AWAY_ID" \
    '[.keyEvents[]? // .competitions[0].details[]? | select(.type.text == "Goal" or .type.text == "Goal - Header" or .type.text == "Penalty - Scored") | select(.team.id == $aid) | "\(.athletesInvolved[0].displayName // "?") \(.clock.displayValue // "")"] | join("<br>")' 2>/dev/null || echo "")
fi

# --- Donnees du prochain match ---
NEXT_DATE=$(echo "$NEXT_EVENT" | jq -r '.date // empty')
NEXT_HOME=$(echo "$NEXT_EVENT" | jq '.competitions[0].competitors[] | select(.homeAway == "home")')
NEXT_AWAY=$(echo "$NEXT_EVENT" | jq '.competitions[0].competitors[] | select(.homeAway == "away")')

NEXT_HOME_NAME=$(echo "$NEXT_HOME" | jq -r '.team.shortDisplayName // .team.displayName // "?"')
NEXT_AWAY_NAME=$(echo "$NEXT_AWAY" | jq -r '.team.shortDisplayName // .team.displayName // "?"')
NEXT_HOME_LOGO=$(echo "$NEXT_HOME" | jq -r '.team.logo // ""')
NEXT_AWAY_LOGO=$(echo "$NEXT_AWAY" | jq -r '.team.logo // ""')

# --- Formatage des dates en francais ---
LAST_DATE_FR=""
if [ -n "$LAST_DATE" ]; then
  LAST_DATE_FR=$(date -d "$LAST_DATE" "+%a %d %b %Y" \
    | sed 's/Mon/Lun/;s/Tue/Mar/;s/Wed/Mer/;s/Thu/Jeu/;s/Fri/Ven/;s/Sat/Sam/;s/Sun/Dim/' \
    | sed 's/Jan/jan./;s/Feb/fev./;s/Mar/mars/;s/Apr/avr./;s/May/mai/;s/Jun/juin/' \
    | sed 's/Jul/juil./;s/Aug/aout/;s/Sep/sept./;s/Oct/oct./;s/Nov/nov./;s/Dec/dec./')
fi

NEXT_DATE_FR=""
NEXT_TIME_FR=""
if [ -n "$NEXT_DATE" ]; then
  NEXT_DATE_FR=$(date -d "$NEXT_DATE" "+%a %d %b %Y" \
    | sed 's/Mon/Lun/;s/Tue/Mar/;s/Wed/Mer/;s/Thu/Jeu/;s/Fri/Ven/;s/Sat/Sam/;s/Sun/Dim/' \
    | sed 's/Jan/jan./;s/Feb/fev./;s/Mar/mars/;s/Apr/avr./;s/May/mai/;s/Jun/juin/' \
    | sed 's/Jul/juil./;s/Aug/aout/;s/Sep/sept./;s/Oct/oct./;s/Nov/nov./;s/Dec/dec./')
  NEXT_TIME_FR=$(date -d "$NEXT_DATE" "+%Hh%M")
fi

# --- Generation du HTML statique ---
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#000;color:#e0e0e0;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;display:flex;flex-direction:column;align-items:center;padding:8px}
.mb{width:100%;max-width:340px;margin-bottom:10px}
.dt{text-align:center;font-size:11px;color:#999;text-transform:capitalize;margin-bottom:4px;letter-spacing:.5px}
.mr{display:flex;align-items:center;justify-content:center;gap:10px}
.tm{display:flex;flex-direction:column;align-items:center;width:90px}
.tm img{width:36px;height:36px;object-fit:contain;margin-bottom:3px}
.tn{font-size:11px;color:#ccc;text-align:center;line-height:1.2}
.sc{font-size:28px;font-weight:700;color:#fff;letter-spacing:2px;min-width:60px;text-align:center}
.ti{font-size:18px;font-weight:600;color:#aaa;min-width:60px;text-align:center}
.gr{display:flex;justify-content:center;gap:10px;margin-top:4px}
.gs{width:90px;font-size:9px;color:#888;text-align:center;line-height:1.4}
.gx{min-width:60px}
hr.sep{width:60px;border:none;border-top:1px solid #333;margin:6px auto}
.nd{text-align:center;font-size:11px;color:#666}
</style>
</head>
<body>
HTMLEOF

if [ -n "$LAST_DATE" ] && [ "$LAST_HOME_NAME" != "?" ]; then
  cat >> index.html << EOF
<div class="mb">
  <div class="dt">${LAST_DATE_FR}</div>
  <div class="mr">
    <div class="tm">
      <img src="${LAST_HOME_LOGO}" alt="${LAST_HOME_NAME}" onerror="this.style.display='none'">
      <span class="tn">${LAST_HOME_NAME}</span>
    </div>
    <div class="sc">${LAST_HOME_SCORE} - ${LAST_AWAY_SCORE}</div>
    <div class="tm">
      <img src="${LAST_AWAY_LOGO}" alt="${LAST_AWAY_NAME}" onerror="this.style.display='none'">
      <span class="tn">${LAST_AWAY_NAME}</span>
    </div>
  </div>
EOF
  if [ -n "$HOME_GOALS_HTML" ] || [ -n "$AWAY_GOALS_HTML" ]; then
    cat >> index.html << EOF
  <div class="gr">
    <div class="gs">${HOME_GOALS_HTML}</div>
    <div class="gx"></div>
    <div class="gs">${AWAY_GOALS_HTML}</div>
  </div>
EOF
  fi
  echo "</div>" >> index.html
else
  echo '<div class="mb"><div class="nd">-</div></div>' >> index.html
fi

echo '<hr class="sep">' >> index.html

if [ -n "$NEXT_DATE" ] && [ "$NEXT_HOME_NAME" != "?" ]; then
  cat >> index.html << EOF
<div class="mb">
  <div class="dt">${NEXT_DATE_FR}</div>
  <div class="mr">
    <div class="tm">
      <img src="${NEXT_HOME_LOGO}" alt="${NEXT_HOME_NAME}" onerror="this.style.display='none'">
      <span class="tn">${NEXT_HOME_NAME}</span>
    </div>
    <div class="ti">${NEXT_TIME_FR}</div>
    <div class="tm">
      <img src="${NEXT_AWAY_LOGO}" alt="${NEXT_AWAY_NAME}" onerror="this.style.display='none'">
      <span class="tn">${NEXT_AWAY_NAME}</span>
    </div>
  </div>
</div>
EOF
else
  echo '<div class="mb"><div class="nd">-</div></div>' >> index.html
fi

echo '</body></html>' >> index.html
