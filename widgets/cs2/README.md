# Counter-Strike 2

Live, upcoming and just-finished Counter-Strike 2 matches as scoreboard cards: the tournament,
both teams and the maps won, and for a live match the map being played with its rounds. OK opens
a match dialog with the series, each map with its rounds and winner, and both lineups.

## Settings

- **Tier 1–2 events only** (on by default): Liquipedia's biggest events, listed a week ahead.
  Off, every tier shows, three days ahead.
- **Recent results** (on by default): the latest finished matches after the live and upcoming
  ones.

## Source

The shared feed `cs2/matches.json` of [eluz1ve/luma-feeds](https://github.com/eluz1ve/luma-feeds),
rebuilt every 15 minutes on GitHub Actions from [LiquipediaDB](https://api.liquipedia.net). The
LiquipediaDB key lives only in that repository's secrets: the widget needs no key, and the TV
contacts nothing but `eluz1ve.github.io`, every 5 minutes. Scores are as fresh as the last
build, which the row's header shows ("Data as of …").

## Credits

Match data, maps and lineups: [Liquipedia](https://liquipedia.net), CC-BY-SA 3.0, credited in
every match dialog.
