#!/bin/bash
set -e
export TZ="Europe/Paris"

FINISHED=$(curl -sf -H "X-Auth-Token: $API_KEY" \
  "https://api.football-data.org/v4/competitions/FL1/matches?status=FINISHED&limit=15" || echo '{"matches":[]}')

SCHEDULED=$(curl -sf -H "X-Auth-Token: $API_KEY" \
  "https://api.football-data.org/v4/competitions/FL1/matches?status=SCHEDULED&limit=15" || echo '{"matches":[]}')

LAST_MATCH=$(echo "$FINISHED" | jq '[.matches[] | select(.homeTeam.id == 524 or .awayTeam.id == 524)] | last')
MATCH_ID=$(echo "$LAST_MATCH" | jq -r '.id // empty')

GOALS_JSON="[]"
if [ -n "$MATCH_ID" ]; then
  sleep 1
  DETAIL=$(curl -sf -H "X-Auth-Token: $API_KEY" \
    "https://api.football-data.org/v4/matches/$MATCH_ID" || echo '{}')
  GOALS_JSON=$(echo "$DETAIL" | jq '[.goals[]? | {name: .scorer.name, minute: .minute, team_id: .team.id}]' 2>/dev/null || echo "[]")
fi

NEXT_MATCH=$(echo "$SCHEDULED" | jq '[.matches[] | select(.homeTeam.id == 524 or .awayTeam.id == 524)] | first')

LAST_DATE=$(echo "$LAST_MATCH" | jq -r '.utcDate // empty')
LAST_HOME_NAME=$(echo "$LAST_MATCH" | jq -r '.homeTeam.shortName // .homeTeam.name // "?"')
LAST_AWAY_NAME=$(echo "$LAST_MATCH" | jq -r '.awayTeam.shortName // .awayTeam.name // "?"')
LAST_HOME_CREST=$(echo "$LAST_MATCH" | jq -r '.homeTeam.crest // ""')
LAST_AWAY_CREST=$(echo "$LAST_MATCH" | jq -r '.awayTeam.crest // ""')
LAST_HOME_SCORE=$(echo "$LAST_MATCH" | jq -r '.score.fullTime.home // "?"')
LAST_AWAY_SCORE=$(echo "$LAST_MATCH" | jq -r '.score.fullTime.away // "?"')
LAST_HOME_ID=$(echo "$LAST_MATCH" | jq -r '.homeTeam.id')
LAST_AWAY_ID=$(echo "$LAST_MATCH" | jq -r '.awayTeam.id')

NEXT_DATE=$(echo "$NEXT_MATCH" | jq -r '.utcDate // empty')
NEXT_HOME_NAME=$(echo "$NEXT_MATCH" | jq -r '.homeTeam.shortName // .homeTeam.name // "?"')
NEXT_AWAY_NAME=$(echo "$NEXT_MATCH" | jq -r '.awayTeam.shortName // .awayTeam.name // "?"')
NEXT_HOME_CREST=$(echo "$NEXT_MATCH" | jq -r '.homeTeam.crest // ""')
NEXT_AWAY_CREST=$(echo "$NEXT_MATCH" | jq -r '.awayTeam.crest // ""')

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

HOME_GOALS_HTML=$(echo "$GOALS_JSON" | jq -r --arg tid "$LAST_HOME_ID" \
  '[.[] | select(.team_id == ($tid | tonumber))] | if length == 0 then "" else [.[] | "\(.name) \(.minute)&#39;"] | join("<br>") end')

AWAY_GOALS_HTML=$(echo "$GOALS_JSON" | jq -r --arg tid "$LAST_AWAY_ID" \
  '[.[] | select(.team_id == ($tid | tonumber))] | if length == 0 then "" else [.[] | "\(.name) \(.minute)&#39;"] | join("<br>") end')

# --- Generation du HTML statique ---
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:transparent;color:#e0e0e0;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;display:flex;flex-direction:column;align-items:center;padding:8px}
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
      <img src="${LAST_HOME_CREST}" alt="${LAST_HOME_NAME}" onerror="this.style.display='none'">
      <span class="tn">${LAST_HOME_NAME}</span>
    </div>
    <div class="sc">${LAST_HOME_SCORE} - ${LAST_AWAY_SCORE}</div>
    <div class="tm">
      <img src="${LAST_AWAY_CREST}" alt="${LAST_AWAY_NAME}" onerror="this.style.display='none'">
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
