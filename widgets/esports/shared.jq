# Without a key: the shared feed of every chosen discipline, built every 15 minutes.
[$settings.games[] as $game | .feed[$game] // {} | .game = $game] as $feeds
| [$feeds[] | .game as $game | (.matches // [])[:20][] | .game = $game] as $matches
| all_rosters($feeds[]) as $rosters
| ([$feeds[] | .updated | numbers] | min) as $updated
| document($matches; $rosters.players; $rosters.liquipedia; $updated)
