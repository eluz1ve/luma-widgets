# With the user's key: PandaScore's running and upcoming matches and their teams' lineups,
# named from the shared feed where it knows the match. Lineups the shared feed has from
# Liquipedia are the tournament's own and win; PandaScore's are marked by them otherwise.
. as $replies
| [$settings.games[] as $game
   | $replies | ps_selected($game) | map(ps_match($game))
   | merge_maps($replies.shared[$game].matches // [])
   | .[]] as $matches
| all_rosters($settings.games[] as $game | $replies.shared[$game] // {}) as $shared
| (reduce $settings.games[] as $game ({}; . + ($replies.teams[$game] // [] | ps_rosters))) as $teams
| ($teams | to_entries
   | map(.key as $id | .value |= merge_substitutes($shared.players[$id] // []))
   | from_entries) as $marked
| ($shared.players + $marked
   + ($shared.players | with_entries(select($shared.liquipedia[.key])))) as $rosters
| document($matches; $rosters; $shared.liquipedia; null)
  + {refresh: (if any($matches[]; .running) then [($settings.games | length) * 8, 30] | max else 300 end)}
