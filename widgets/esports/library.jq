# Esports: matches from the shared feed (eluz1ve/luma-feeds) or PandaScore, as scoreboard
# cards and match dialogs. Both sources normalise to the shared feed's match shape first:
# {id, game, running, begin_at, teams: [team|null, team|null], score, best_of, games, event,
#  league_image, stage, tier, prizepool, online, streams, maps_source}.

def game_name($path): {
  "csgo": "Counter-Strike 2", "dota2": "Dota 2", "lol": "League of Legends",
  "valorant": "Valorant", "r6siege": "Rainbow Six Siege", "ow": "Overwatch 2",
  "rl": "Rocket League", "codmw": "Call of Duty"
}[$path] // "";

def nonempty: if . == "" or . == [] then null else . end;
def logo_url: if type == "string" and startswith("https://cdn-api.pandascore.co/") then . else empty end;

# "13:11"; Overwatch's Push distances keep one decimal.
def points: if . == floor then floor | tostring else (. * 10 | round) / 10 | tostring end;
def map_score: "\(.[0] | points):\(.[1] | points)";

# "1000000 United States Dollar" → "$1 000 000".
def group3: if length > 3 then (.[:-3] | group3) + " " + .[-3:] else . end;
def prize:
  . as $text
  | split(" ") as $parts
  | ($parts[0] | gsub(","; "")) as $amount
  | ($parts[1:] | join(" ")) as $currency
  | if ($amount | test("^[0-9]+$")) | not then $text
    else ($amount | group3) as $grouped
    | if $currency == "United States Dollar" then "$" + $grouped
      elif $currency == "Euro" then "€" + $grouped
      elif $currency == "" then $grouped
      else "\($grouped) \($currency)" end
    end;

# PandaScore → the shared feed's shape.

def ps_team:
  if type == "object" and (.id | type) == "number" then {
    id,
    name: (.name // ""),
    short: (first(.acronym, .name | select(type == "string" and . != "")) // ""),
    image: (first(.dark_mode_image_url, .image_url | logo_url) // null),
    location: (.location // "")
  } else null end;

def ps_stream:
  ((.raw_url // "") | (capture("^[a-z]+://(?<host>[^/?:#]+)").host // "") | ltrimstr("www.")) as $host
  | {
      language: (.language // ""),
      platform: ({"twitch.tv": "Twitch", "kick.com": "Kick", "youtube.com": "YouTube",
                  "youtu.be": "YouTube"}[$host] // $host),
      official: (.official == true),
      main: (.main == true)
    };

def ps_match($game):
  . as $m
  | ([(.opponents // [])[:2][] | .opponent | ps_team] + [null, null])[:2] as $teams
  | {
      id,
      game: $game,
      running: (.status == "running"),
      begin_at: (.begin_at // .scheduled_at // ""),
      teams: $teams,
      score: [$teams[] | if . == null then 0
                         else .id as $id | (first($m.results[]? | select(.team_id == $id) | .score) // 0) end],
      best_of: (.number_of_games // 1),
      games: ([(.games // [])[] | select((.position | type) == "number") | {
                 position,
                 state: (if .status == "running" then "running"
                         elif .status == "finished" then "finished" else "waiting" end),
                 winner: (.winner | if type == "object" then .id elif type == "number" then . else null end),
                 begin_at: (.begin_at // ""),
                 length
               }] | sort_by(.position)),
      event: ("\(.league.name // "") \(.serie.full_name // "")" | trim),
      league_image: (first(.league.image_url | logo_url) // null),
      stage: (.tournament.name // ""),
      tier: (.tournament.tier // "" | ascii_downcase),
      prizepool: (.tournament.prizepool // ""),
      online: (.tournament.type | if . == "online" then true elif . == "offline" then false else null end),
      streams: [(.streams_list // [])[:6][] | ps_stream],
      maps_source: ""
    };

# Running matches first, then upcoming by start, twenty at most (as PandaScore lists them).
def ps_selected($game):
  ((.running[$game] // []) + ((.upcoming[$game] // []) | sort_by(.begin_at // .scheduled_at)))[:20];

def ps_player:
  select(type == "object" and (.name // "") != "")
  | {
      name,
      real_name: (if (.real_name // "") != "" then .real_name
                  else "\(.first_name // "") \(.last_name // "")" | trim end),
      nationality: (.nationality // ""),
      role: (.role // ""),
      image: (first(.image_url, .image | logo_url) // null),
      substitute: false
    };

# Team id → its active players, from PandaScore's teams.
def ps_rosters:
  [.[]? | select((.id | type) == "number")
   | {key: (.id | tostring), value: ([(.players // [])[] | select(.active != false) | ps_player][:7])}]
  | from_entries;

# The shared feed's lineups by team id, and which of them are Liquipedia's own: a team in several
# matches keeps Liquipedia's lineup, else the one with its substitutes marked.
def feed_player:
  (if type == "string" then {name: .} else . end)
  | select((.name // "") != "")
  | {
      name,
      real_name: (.real_name // ""),
      nationality: (.nationality // ""),
      role: (.role // ""),
      image: (first(.image | logo_url) // null),
      substitute: (.substitute == true)
    };

def feed_rosters:
  reduce (.matches // [])[:20][] as $m ({players: {}, liquipedia: {}};
    reduce (0, 1) as $side (.;
      $m.teams[$side] as $team
      | ([($m.lineups[$side] // [])[] | feed_player][:10]) as $players
      | ((($m.lineups_source // [])[$side] // "") == "Liquipedia") as $own
      | if $team == null or ($players | length) == 0 then .
        else ($team.id | tostring) as $id
        | if .liquipedia[$id] then .
          elif $own then .players[$id] = $players | .liquipedia[$id] = true
          elif any(.players[$id][]?; .substitute) then .
          else .players[$id] = $players end
        end));

# Several disciplines' lineups together.
def all_rosters(feeds):
  reduce feeds as $feed ({players: {}, liquipedia: {}};
    ($feed | feed_rosters) as $r
    | .players += $r.players | .liquipedia += $r.liquipedia);

# PandaScore's lineup marked as the shared feed marks the team's, by nickname.
def merge_substitutes($shared):
  if any($shared[]?; .substitute) | not then .
  else map(. as $player
    | (first($shared[] | select((.name | ascii_downcase) == ($player.name | ascii_downcase))) // null) as $found
    | if $found == null then .
      else .substitute = $found.substitute
      | if .role == "" then .role = $found.role else . end
      end)
  end;

# Map names, round scores and picks from the shared feed, by match id and map position; the live
# state, winners and series score stay PandaScore's.
def merge_maps($shared):
  map(. as $match
    | (first($shared[]? | select(.id == $match.id)) // null) as $named
    | if $named == null then .
      else .games |= map(. as $game
          | (first($named.games[]? | select(.position == $game.position)) // null) as $from
          | if $from == null then .
            else .map = ($from.map // "") | .score = ($from.score // null)
            | .picked_by = ($from.picked_by // null) | .decider = ($from.decider == true)
            end)
      | if any(.games[]; (.map // "") != "" or .score != null or .picked_by != null or .decider)
        then .maps_source = ($named.maps_source // "") else . end
      end);

# What a widget shows: its filter, live first, then by start; twelve at most.
def shown:
  [.[] | select(($settings.major_only | not) or .tier == "s" or .tier == "a")]
  | sort_by([(if .running then 0 else 1 end), .begin_at])
  | .[:12];

# The live map's number: the running one's, else the first not finished.
def live_number:
  (first(.games[] | select(.state == "running") | .position)
   // ([.games[] | select(.state == "finished")] | length) + 1);

def side($i):
  .teams[$i] as $team
  | if $team == null then null
    else {name: $team.name, short: $team.short, image: $team.image}
      + (if .running or .score != [0, 0]
         then {score: (.score[$i] | tostring), lead: (.score[$i] >= .score[1 - $i])} else {} end)
    end;

def card($several):
  (first(.games[] | select(.state == "running")) // null) as $live
  | live_number as $number
  | {
      live: .running,
      status: (if .running then null else {start: .begin_at} end),
      logo: .league_image,
      caption: (if $several then "\(game_name(.game)) · \(.event)" else .event end),
      sides: [side(0), side(1)]
    }
  + if .running then {
      progress: {
        label: ([($t.map | fmt({number: $number})), ($live.map // "" | nonempty)] | map(select(.)) | join(" · ")),
        value: (if $live.score then $live.score | map_score else null end),
        steps: [range(1; ([[.best_of, 1] | max, 7] | min) + 1) as $p
                | (first(.games[] | select(.position == $p) | .state) // "waiting")
                | if . == "running" then "live" elif . == "finished" then "done" else "next" end]
      }
    } else {
      footer: (["BO\(.best_of)", .stage] | map(select(. != "")) | join(" · "))
    } end;

def tile($p):
  . as $match
  | (first(.games[] | select(.position == $p)) // null) as $game
  | ($match.teams | map(select(. != null))) as $teams
  | {
      number: (if $p < 10 then "0\($p)" else "\($p)" end),
      title: ($game.map // "" | nonempty),
      placeholder: ($t.map | fmt({number: $p})),
      note: (if $game == null then null
             elif $game.decider then $t.decider
             else (first($teams[] | select(.id == $game.picked_by) | .short) // null) as $team
             | if $team then $t.pick | fmt({team: $team}) else null end end),
      state: ($game.state // "waiting" | if . == "running" then "live" elif . == "finished" then "done" else "next" end),
      value: (if $game.score then $game.score | map_score else null end),
      result: (if $game == null then null
               elif $game.state == "running" then
                 (if ($game.begin_at // "") != "" then {text: {elapsed: $game.begin_at}} else null end)
               else (first($teams[] | select(.id == $game.winner)) // null) as $winner
               | if $winner == null then null
                 else {image: $winner.image, name: $winner.short,
                       text: ([$winner.short,
                               (if $game.length then $t.minutes | fmt({number: ($game.length / 60 | floor)}) else null end)]
                              | map(select(.)) | join(" · "))}
                 end
               end)
    };

def lineup($team; $players):
  if $team == null then {title: ($t.lineup | fmt({team: "TBD"})), empty: $t.noLineup}
  else ($players | map(select(.substitute | not))) as $starters
  | ($players | map(select(.substitute))) as $bench
  | ($bench | map(select(.role | ascii_downcase == "coach"))) as $coaches
  | ($bench | map(select(.role | ascii_downcase != "coach"))) as $subs
  | {
      title: ($t.lineup | fmt({team: $team.short})),
      image: $team.image,
      name: $team.short,
      rows: [$starters[] | {
        image,
        title: .name,
        subtitle: (.real_name | nonempty),
        meta: ([.nationality, (.role | ascii_upcase)] | map(select(. != "")) | join(" · ") | nonempty)
      }],
      extra: ([if $subs != [] then {label: $t.bench, text: ($subs | map(.name) | join(" · "))} else empty end,
               if $coaches != [] then {label: $t.coach, text: ($coaches | map(.name) | join(" · "))} else empty end]),
      empty: $t.noLineup
    }
  end;

def streams_text:
  sort_by([(.official | not), (.main | not)])
  | reduce .[] as $stream ([];
      if ($stream.platform // "") == "" or any(.[]; .language == $stream.language and .platform == $stream.platform)
      then . else . + [$stream] end)
  | .[:4]
  | map(("\(.language | ascii_upcase) \(.platform)" | trim)
        + (if .official then " (\($t.official))" else "" end))
  | join(" · ");

def dialog($rosters; $liquipedia; $updated):
  . as $match
  | (first(.games[] | select(.state == "running")) // null) as $live
  | live_number as $number
  | [.teams[] | if . == null then null else ($rosters[.id | tostring] // []) end] as $players
  | ([$players[] | select(. != null)[]] | any(.substitute)
     or any($match.teams[] | select(. != null); $liquipedia[.id | tostring] == true)) as $lineups
  | (.streams | streams_text) as $streams
  | {
      header: {
        logo: .league_image,
        title: .event,
        subtitle: ([game_name(.game), .stage] | map(select(. != "")) | join(" · ")),
        chips: ([{text: "BO\(.best_of)"},
                 (if .tier != "" then {text: "Tier \(.tier | ascii_upcase)"} else empty end),
                 (if .online == true then {text: $t.online} elif .online == false then {text: "LAN"} else empty end),
                 (if .prizepool != "" then {text: (.prizepool | prize), tone: "gold"} else empty end)])
      },
      hero: {
        live: .running,
        sides: [range(0; 2) as $i | .teams[$i] as $team
                | if $team == null then null
                  else side($i) + {caption: ($team.location | nonempty)} end],
        lines: (if .running then
                  [([($t.map | fmt({number: $number})), ($live.map // "" | nonempty),
                     (if $live.score then $live.score | map_score else null end)]
                    | map(select(.)) | join(" · ")),
                   (if $updated then {as_of: $updated} else empty end)]
                else [{start: .begin_at}] end)
      },
      tiles: {
        title: $t.maps,
        slots: ([[.best_of, 1] | max, 7] | min),
        items: [range(1; ([[.best_of, 1] | max, 7] | min) + 1) as $p | $match | tile($p)]
      },
      lists: [lineup(.teams[0]; $players[0] // []), lineup(.teams[1]; $players[1] // [])],
      footer: {
        label: (if $streams != "" then $t.streams else null end),
        text: ($streams | nonempty),
        credit: (if .maps_source != "" and $lineups then $t.mapsLineupsCredit
                 elif .maps_source != "" then $t.mapsCredit
                 elif $lineups then $t.lineupsCredit else null end),
        note: (if $source == "shared" then $t.sharedNote else $t.freeNote end)
      }
    };

def document($matches; $rosters; $liquipedia; $updated):
  ($settings.games | length > 1) as $several
  | {
      title: ($settings.games | map(game_name(.)) | join(", ")),
      updated: $updated,
      empty: $t.none,
      items: [$matches | shown[] | {id: (.id | tostring), card: card($several), dialog: dialog($rosters; $liquipedia; $updated)}]
    };
