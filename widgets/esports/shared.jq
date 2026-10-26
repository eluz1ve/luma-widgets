# Without a key: the shared feed of every chosen discipline, built every 15 minutes.
[$settings.games[] as $game | .feed[$game] // {} | .game = $game] as $feeds
| [$feeds[] | .game as $game | (.matches // [])[:20][] | .game = $game] as $matches
| (reduce $feeds[] as $feed ({}; . + ($feed | feed_rosters))) as $rosters
| ([$feeds[] | .updated | numbers] | min) as $updated
| document($matches; $rosters; $updated)
