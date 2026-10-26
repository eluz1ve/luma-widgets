# With the user's key: PandaScore's running and upcoming matches and their teams' lineups,
# named and marked from the shared feed where it knows the match.
. as $replies
| [$settings.games[] as $game
   | $replies | ps_selected($game) | map(ps_match($game))
   | merge_maps($replies.shared[$game].matches // [])
   | .[]] as $matches
| (reduce $settings.games[] as $game ({}; . + ($replies.shared[$game] // {} | feed_rosters))) as $shared
| (reduce $settings.games[] as $game ({}; . + ($replies.teams[$game] // [] | ps_rosters))) as $teams
| ($teams | to_entries | map(.key as $id | .value |= merge_substitutes($shared[$id] // [])) | from_entries) as $marked
| document($matches; $shared + $marked; null)
  + {refresh: (if any($matches[]; .running) then [($settings.games | length) * 8, 30] | max else 300 end)}
