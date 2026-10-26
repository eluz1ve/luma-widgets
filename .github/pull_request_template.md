## Widget

<!-- What it shows and where the data comes from. -->

## Checklist

- [ ] `luma-widget check` and `luma-widget test` pass for the widget's folder.
- [ ] `origins` lists only the data's real sources (every TV with the widget will contact them).
- [ ] Secrets are sent only to the API they belong to (`send_to`).
- [ ] The data's licence allows this use; the widget credits it where required.
- [ ] Refresh intervals respect the API's rate limits for one user.
- [ ] `preview.png` shows the row and the dialog from `luma --widget-dev`.
- [ ] For an update: `version` is higher, and new origins or secret destinations are explained.
