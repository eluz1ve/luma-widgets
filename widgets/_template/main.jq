# `.quote` holds one reply per chosen symbol; give one ticker card each.
{
  empty: $t.empty,
  items: [
    .quote | to_entries[] | select(.value != null) | {
      id: .key,
      card: {
        label: (.key | ascii_upcase),
        value: (.value.price | tostring),
        change: {
          text: "\(if .value.change >= 0 then "+" else "" end)\(.value.change)%",
          tone: (if .value.change >= 0 then "up" else "down" end)
        }
      }
    }
  ]
}
