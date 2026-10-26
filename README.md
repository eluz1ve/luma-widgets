# Luma widgets

The widget store of [Luma](https://github.com/eluz1ve/lg-luma), the native launcher for rooted LG
webOS TVs. Luma's Home lists these widgets under **Add widget → Widget store…**; this
repository is the catalog, published to <https://eluz1ve.github.io/luma-widgets/> and signed on
every merge.

A widget is **data, not code**: a JSON manifest that says where its data comes from, a few jq
programs that turn replies into Luma's widget document, and one of Luma's fixed templates to
draw it. Nothing in a widget runs as code on a TV. The full reference is
[docs/widgets.md](https://github.com/eluz1ve/lg-luma/blob/main/docs/widgets.md) in Luma; this
page is the short way through it.

## How a widget works

```
your widget's origins ──GET──► replies ──jq transform──► widget document ──► Luma's templates
```

- **Origins.** A widget declares the HTTPS origins it may reach (`https://api.example.com`).
  The TV refuses every request and image anywhere else, and the store shows the list before
  anyone installs it.
- **Settings.** Toggles, choices, a checklist (`choices`, e.g. which leagues), short text, and
  `secret`s such as a personal API key. A secret is typed with the remote or sent from a phone,
  stays on the TV, goes only into request headers to the origins in its `send_to`, and is never
  shown to your jq.
- **Sources.** One or more ways to get data, each a chain of GET requests and a jq transform.
  The first source whose condition holds runs: e.g. a shared feed without a key, the live API
  with one. A step can fan out over a checklist setting (`for_each`) and compute parts of its
  URL from earlier replies (`vars`).
- **The document.** Your transform returns `{title, updated, refresh, empty, items}`; each item
  has an `id`, a `card` for the row and optionally a `dialog` for OK. The templates are
  `scoreboard` (two sides with scores), `media` (a poster) and `ticker` (a figure that changes);
  the dialog has a header with chips, a two-sided hero, tiles, two lists and a footer.
- **Limits.** Transforms run in a separate process with 2 s of CPU, 256 MiB and a 3 s wall
  clock; replies are at most 1 MiB; a refresh makes at most 32 requests and waits at least
  30 s before the next. A widget that breaks a limit shows "stopped working" — never more.

## Make one

1. Install the authors' tool (Rust 1.88+):

   ```sh
   cargo install --locked --git https://github.com/eluz1ve/lg-luma luma-widgets
   ```

2. Copy [`widgets/_template`](widgets/_template) to `widgets/<your-id>/` and edit
   `manifest.json`: `id` (lower case, the folder's name), `name` and `description` (English
   required, Luma's other languages optional), `origins`, `settings`, `sources`, `card`.
   [`widgets/esports`](widgets/esports) is a complete example with a shared feed, a live API
   with a personal key, fan-out, `vars` and the full dialog.

3. Write the transforms in `.jq` files next to the manifest (`"transform": {"file": "main.jq"}`).
   They see the replies as `.` (by step id, and by value for fanned-out steps) and `$settings`,
   `$t` (your `strings` in the TV's language), `$lang`, `$now` and `$source`. `fmt` fills
   placeholders: `$t.map | fmt({number: 3})`. Filters that read the outside world (`input`,
   `env`, `now`, `debug`…) do not exist.

4. Add fixtures and expected output, so the widget is tested without the network:

   ```
   fixtures/<case>/context.json   {"settings": {...}, "secrets": {"key": "fixture"}, "lang": "en", "now": 1793043100}
   fixtures/<case>/index.json     {"<exact URL>": "<reply file>"}
   fixtures/<case>/<reply>.json   a real reply, trimmed
   expected/<case>.json           what the transform must give
   ```

   A case runs the source its context's `"source"` names, or the one named like the case.

5. Check it:

   ```sh
   luma-widget check widgets/<id>          # manifest, origins, limits, jq without forbidden filters
   luma-widget run widgets/<id> <case>     # print a case's document
   luma-widget run widgets/<id> <case> --network   # the same against the real origins
   luma-widget test widgets/<id>           # every case against expected/
   luma-widget eval '<jq>' '<json>'        # try an expression with Luma's jq
   ```

   With `--network`, a secret comes from `LUMA_WIDGET_SECRET_<SETTING>` (e.g.
   `LUMA_WIDGET_SECRET_KEY`); it is never written anywhere.

6. See it as a TV will: run Luma on your computer with `luma --widget-dev widgets/<id>`
   (add `--fixtures` for no network). Save a screenshot of the row and the dialog as
   `preview.png`.

## Submit it

Fork this repository, add `widgets/<id>/` with a `README.md` (what it shows, where the data
comes from, its licence and credits) and `preview.png`, and open a pull request. The check
workflow validates and tests it; it needs no secrets, so it runs the same on forks.

A maintainer then looks at what Luma cannot judge for itself:

- **Origins**: every TV with the widget will contact them; they should be the data's real
  sources.
- **Secrets**: sent only to the API they belong to.
- **Licence and credit**: the data may be used this way, and the widget credits it (e.g.
  Liquipedia's CC-BY-SA).
- **Rate limits**: refresh intervals within what the API allows one user.
- **Name and description**: not misleading, not someone else's brand.

New widgets, and updates that add origins or secret destinations, need a maintainer's approval.
Other updates need one of the widget's own authors (`.github/CODEOWNERS`), and TVs install them
on their own. Updates that widen access wait on each TV for its owner's consent.

## Publishing

Merging to `main` runs [`publish.yml`](.github/workflows/publish.yml): it checks every widget,
packs them into `manifests/<id>-<version>.json`, writes `index.json` with each manifest's size
and SHA-256 and a new `sequence`, signs it with the catalog key (an Actions secret of the
protected `publish` environment) and deploys GitHub Pages. Luma verifies the signature with the
public key it was built with ([`catalog.pub`](catalog.pub)), refuses an index older than one it
has seen, and checks each manifest against the index before installing it.

## Licence

The catalog's tooling and widgets are MIT-licensed unless a widget's README says otherwise.
Data a widget shows belongs to its sources.
