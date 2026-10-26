# Esports

Live and upcoming matches of Counter-Strike 2, Dota 2, League of Legends, Valorant, Rainbow Six
Siege, Overwatch 2, Rocket League and Call of Duty as scoreboard cards, with a match dialog:
the series, each map with its name, pick, winner and rounds, both lineups with their
substitutes and coach, and where it streams.

## Sources

- **Without a key** (`shared`): the shared feed of
  [eluz1ve/luma-feeds](https://github.com/eluz1ve/luma-feeds), rebuilt every 15 minutes on
  GitHub Actions from PandaScore's free plan and Liquipedia. It is test data, refreshed every
  5 minutes on the TV.
- **With your own free [PandaScore](https://pandascore.co) key** (`live`): running and
  upcoming matches straight from PandaScore every 30 s while a match is live (two lists per
  discipline, within the free plan's 1,000 requests an hour), the teams' lineups every 30
  minutes, and map names, round scores, picks and substitutes merged from the shared feed by
  match id. The key goes only to `api.pandascore.co`.

## Credits

Match data: PandaScore. Map names, round scores, picks, vetoes and substitutes:
[Liquipedia](https://liquipedia.net), CC-BY-SA 3.0, credited in the dialog whenever shown.
