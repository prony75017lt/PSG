#!/bin/bash
set -e
export TZ="Europe/Paris"

ESPN="https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1"
PSG_ID="160"
PSG_FDA_ID="524"

# =============================================
# DERNIER MATCH (via ESPN - buteurs + logos)
# =============================================
SCHEDULE=$(curl -sf "$ESPN/teams/$PSG_ID/schedule" || echo '{"events":[]}')
SCOREBOARD=$(curl -sf "$ESPN/scoreboard" || echo '{"events":[]}')

ALL_PSG=$(jq -n --arg pid "$PSG_ID" \
  --argjson s "$SCHEDULE" \
  --argjson sb "$SCOREBOARD" \
  '[$s.events[]?, $sb.events[]?]
   | [.[] | select(.competitions[0].competitors[]?.team.id == $pid)]
   | group_by(.id) | [.[] | .[0]]
   | sort_by(.date)')

LAST_EVENT=$(echo "$ALL_PSG" | jq '[.[] | select(.status.type.completed == true or .competitions[0].status.type.completed == true)] | last')
LAST_EVENT_ID=$(echo "$LAST_EVENT" | jq -r '.id // empty')
LAST_DATE=$(echo "$LAST_EVENT" | jq -r '.date // empty')

LAST_HOME=$(echo "$LAST_EVENT" | jq '.competitions[0].competitors[] | select(.homeAway == "home")' 2>/dev/null || echo '{}')
LAST_AWAY=$(echo "$LAST_EVENT" | jq '.competitions[0].competitors[] | select(.homeAway == "away")' 2>/dev/null || echo '{}')

LAST_HOME_NAME=$(echo "$LAST_HOME" | jq -r '.team.shortDisplayName // .team.displayName // "?"')
LAST_AWAY_NAME=$(echo "$LAST_AWAY" | jq -r '.team.shortDisplayName // .team.displayName // "?"')
LAST_HOME_LOGO=$(echo "$LAST_HOME" | jq -r '.team.logos[0].href // ""' 2>/dev/null || echo "")
LAST_AWAY_LOGO=$(echo "$LAST_AWAY" | jq -r '.team.logos[0].href // ""' 2>/dev/null || echo "")
LAST_HOME_SCORE=$(echo "$LAST_HOME" | jq -r '.score.displayValue // (.score.value | tostring) // "?"' 2>/dev/null || echo "?")
LAST_AWAY_SCORE=$(echo "$LAST_AWAY" | jq -r '.score.displayValue // (.score.value | tostring) // "?"' 2>/dev/null || echo "?")
LAST_HOME_ID=$(echo "$LAST_HOME" | jq -r '.team.id // ""')
LAST_AWAY_ID=$(echo "$LAST_AWAY" | jq -r '.team.id // ""')

# Buteurs
HOME_GOALS_HTML=""
AWAY_GOALS_HTML=""
if [ -n "$LAST_EVENT_ID" ]; then
  sleep 1
  SUMMARY=$(curl -sf "$ESPN/summary?event=$LAST_EVENT_ID" || echo '{}')

  HOME_GOALS_HTML=$(echo "$SUMMARY" | jq -r --arg hid "$LAST_HOME_ID" \
    '[.keyEvents[]? | select(.scoringPlay == true and .team.id == $hid) | "\(.participants[0].athlete.displayName // "?") \(.clock.displayValue // "")"] | join("<br>")' 2>/dev/null || echo "")

  AWAY_GOALS_HTML=$(echo "$SUMMARY" | jq -r --arg aid "$LAST_AWAY_ID" \
    '[.keyEvents[]? | select(.scoringPlay == true and .team.id == $aid) | "\(.participants[0].athlete.displayName // "?") \(.clock.displayValue // "")"] | join("<br>")' 2>/dev/null || echo "")
fi

# =============================================
# PROCHAIN MATCH (via football-data.org)
# =============================================
sleep 1
NEXT_FDA=$(curl -sf -H "X-Auth-Token: $API_KEY" \
  "https://api.football-data.org/v4/competitions/FL1/matches?status=SCHEDULED&limit=15" || echo '{"matches":[]}')

NEXT_MATCH=$(echo "$NEXT_FDA" | jq '[.matches[]? | select(.homeTeam.id == 524 or .awayTeam.id == 524)] | first')

NEXT_DATE=$(echo "$NEXT_MATCH" | jq -r '.utcDate // empty')
NEXT_HOME_NAME=$(echo "$NEXT_MATCH" | jq -r '.homeTeam.shortName // .homeTeam.name // "?"')
NEXT_AWAY_NAME=$(echo "$NEXT_MATCH" | jq -r '.awayTeam.shortName // .awayTeam.name // "?"')
NEXT_HOME_CREST=$(echo "$NEXT_MATCH" | jq -r '.homeTeam.crest // ""')
NEXT_AWAY_CREST=$(echo "$NEXT_MATCH" | jq -r '.awayTeam.crest // ""')

# --- Formatage dates ---
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

# --- Debug ---
echo "DEBUG LAST: $LAST_HOME_NAME $LAST_HOME_SCORE - $LAST_AWAY_SCORE $LAST_AWAY_NAME" >&2
echo "DEBUG GOALS: H=$HOME_GOALS_HTML | A=$AWAY_GOALS_HTML" >&2
echo "DEBUG NEXT: $NEXT_HOME_NAME vs $NEXT_AWAY_NAME | $NEXT_DATE_FR $NEXT_TIME_FR" >&2

# --- Generation HTML ---
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#000;color:#e0e0e0;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;display:flex;flex-direction:column;align-items:center;padding:5px}
.mb{width:100%;max-width:240px;margin-bottom:6px}
.dt{text-align:center;font-size:8px;color:#999;text-transform:capitalize;margin-bottom:3px;letter-spacing:.4px}
.mr{display:flex;align-items:center;justify-content:center;gap:6px}
.tm{display:flex;flex-direction:column;align-items:center;width:62px}
.tm img{width:24px;height:24px;object-fit:contain;margin-bottom:2px}
.tn{font-size:8px;color:#ccc;text-align:center;line-height:1.2}
.sc{font-size:20px;font-weight:700;color:#fff;letter-spacing:1px;min-width:42px;text-align:center}
.ti{font-size:13px;font-weight:600;color:#aaa;min-width:42px;text-align:center}
.gr{display:flex;justify-content:center;gap:6px;margin-top:3px}
.gs{width:62px;font-size:7px;color:#888;text-align:center;line-height:1.3}
.gx{min-width:42px}
hr.sep{width:42px;border:none;border-top:1px solid #333;margin:4px auto}
.nd{text-align:center;font-size:8px;color:#666}
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
      <img src="${NEXT_HOME_CREST}" alt="${NEXT_HOME_NAME}" onerror="this.style.display='none'">
      <span class="tn">${NEXT_HOME_NAME}</span>
    </div>
    <div class="ti">${NEXT_TIME_FR}</div>
    <div class="tm">
      <img src="${NEXT_AWAY_CREST}" alt="${NEXT_AWAY_NAME}" onerror="this.style.display='none'">
      <span class="tn">${NEXT_AWAY_NAME}</span>
    </div>
  </div>
</div>
EOF
else
  echo '<div class="mb"><div class="nd">-</div></div>' >> index.html
fi

echo '</body></html>' >> index.html
