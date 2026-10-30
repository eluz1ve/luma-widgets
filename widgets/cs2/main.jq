# The shared Counter-Strike 2 feed, built from LiquipediaDB every 15 minutes: live matches first,
# then upcoming ones by start, then the latest results.
def nonempty: if . == "" or . == null then null else . end;
def map_score: "\(.[0]):\(.[1])";
def slots: [[.best_of // 1, 1] | max, 7] | min;
def major: .tier != null and .tier <= 2;

# Maps decided so far; the next one is the map being played.
def played: [.maps[] | select(.winner != null)] | length;
def live_map: .maps[played] // null;

def side($i):
  .teams[$i] as $team
  | if $team == null then null
    else {name: $team.name, short: $team.short}
      + (if .score != null
         then {score: (.score[$i] | tostring), lead: (.score[$i] >= .score[1 - $i])} else {} end)
    end;

def details:
  ["BO\(.best_of // 1)", (.stage | nonempty),
   (.tier as $tier | if $tier != null then $t.tier | fmt({number: $tier}) else null end)]
  | map(select(.)) | join(" · ");

def card:
  live_map as $live
  | (played + 1) as $number
  | {
      live: (.state == "live"),
      status: (if .state == "live" then null
               elif .state == "finished" then $t.final
               else {start: .begin_at} end),
      caption: .tournament,
      sides: [side(0), side(1)]
    }
  + if .state == "live" then {
      progress: {
        label: ([($t.map | fmt({number: $number})), ($live.map // null)] | map(select(.)) | join(" · ")),
        value: (if $live.score then $live.score | map_score else null end),
        steps: [range(1; slots + 1) as $p
                | if $p <= played then "done" elif $p == played + 1 then "live" else "next" end]
      }
    } else {footer: details} end;

def tile($p):
  . as $match
  | (.maps[$p - 1] // null) as $game
  | (if $game.winner != null then $match.teams[$game.winner] else null end) as $winner
  | {
      number: (if $p < 10 then "0\($p)" else "\($p)" end),
      title: ($game.map // null),
      placeholder: ($t.map | fmt({number: $p})),
      state: (if $game == null then "next"
              elif $game.winner != null then "done"
              elif $match.state == "live" then "live" else "next" end),
      value: (if $game.score then $game.score | map_score else null end),
      result: (if $winner then {name: $winner.short, text: $winner.short} else null end)
    };

def lineup($i):
  .teams[$i] as $team
  | (.lineups[$i] // []) as $players
  | {
      title: ($t.lineup | fmt({team: ($team.short // "TBD")})),
      name: ($team.short // null),
      rows: [$players[:12][] | {title: .name, meta: (.flag // null)}],
      empty: $t.noLineup
    };

def dialog($updated):
  live_map as $live
  | (played + 1) as $number
  | {
      header: {
        title: .tournament,
        subtitle: (["Counter-Strike 2", (.stage | nonempty)] | map(select(.)) | join(" · ")),
        chips: [{text: "BO\(.best_of // 1)"},
                (.tier as $tier | major as $major
                 | if $tier != null
                   then {text: ($t.tier | fmt({number: $tier}))} + (if $major then {tone: "gold"} else {} end)
                   else empty end)]
      },
      hero: {
        live: (.state == "live"),
        sides: [side(0), side(1)],
        lines: (if .state == "live" then
                  [([($t.map | fmt({number: $number})), ($live.map // null),
                     (if $live.score then $live.score | map_score else null end)]
                    | map(select(.)) | join(" · ")),
                   {as_of: $updated}]
                elif .state == "finished" then [$t.final, {start: .begin_at}]
                else [{start: .begin_at}] end)
      },
      tiles: {title: $t.maps, slots: slots, items: [range(1; slots + 1) as $p | tile($p)]},
      lists: [lineup(0), lineup(1)],
      footer: {credit: $t.credit, note: $t.note}
    };

(.feed.updated // null) as $updated
| [(.feed.matches // [])[]
   | select(($settings.major_only | not) or major)
   | select($settings.results or .state != "finished")]
| {
    updated: $updated,
    empty: (if $settings.major_only then $t.noMajor else $t.none end),
    items: [.[:12][] | {id, card: card, dialog: dialog($updated)}]
  }
