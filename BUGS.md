# Bekannte Fehler und Blocker

| # | Titel | Priorität | Status |
|---|---|---|---|
| 1 | Persistenz nicht testbar: Place unveröffentlicht | Hoch (Blocker M2) | Offen – braucht Freigabe |
| 2 | AFK-Farmen: Stehen auf einem Spawn sammelt jedes Respawn ein | Mittel | Offen |
| 3 | „Infinite yield“-Warnung beim Beitritt, bevor die Grundstücke gestreamt sind | Niedrig | Offen |
| 4 | Unplace auf leerem, entferntem Podest meldet `too_far` statt `empty` | Niedrig | Offen |
| 5 | MCP-Bildschirmfoto im Edit-Modus schwarz | Werkzeug | Umgangen |
| 6 | MCP-Mausklick per Koordinate trifft die UI nicht | Werkzeug | Umgangen |

## 1 Persistenz nicht testbar
- **Reproduktion:** Playtest starten → Konsole: `Place is not published: profiles live in memory only`.
- **Ursache:** DataStores gibt es nur in veröffentlichten Places (`PlaceId = 0`).
- **Lösung:** Den Place als **private** Experience veröffentlichen und in Game Settings → Security „Enable Studio Access to API Services“ aktivieren. Beides braucht deine Zustimmung, bzw. du schaltest es selbst ein.

## 2 AFK-Farmen an Spawns
- **Reproduktion:** Auf `Plaza_Start` stehen bleiben → alle 30 s wird ein neues Relikt automatisch eingesammelt.
- **Folge:** Gewöhnliche Relikte ohne aktives Spielen. Wirtschaftlich klein, aber unerwünscht.
- **Lösung (M2):** Auto-Einsammeln nur beim Eintreten in den Radius auslösen, nicht im Stand.

## 3 Infinite-yield-Warnung
- **Reproduktion:** Playtest starten → `Infinite yield possible on 'Workspace.Aetheria.Plots:WaitForChild("Plot1")'`.
- **Ursache:** Persistente Modelle kommen erst kurz nach den Client-Skripten an. Der Prompt-Aufbau klappt danach korrekt.
- **Lösung:** WaitForChild mit Timeout in einer Schleife, ohne Warnung.

## 4 Fehlercode-Reihenfolge Unplace
- Die Reichweite wird vor „leer“ geprüft. Funktional korrekt (die Aktion wird abgewiesen), nur die Meldung passt nicht.

## 5 / 6 Werkzeug-Einschränkungen
- `screen_capture` liefert im Edit-Modus ein leeres Bild, im Play-Modus funktioniert es. Optische Prüfung deshalb im Playtest.
- `user_mouse_input` mit x/y traf die Buttons nicht; mit `instance_path` klappt es. Deshalb haben alle wichtigen Buttons feste Namen (`Nav.NavHome`, `Nav.NavCollection`, `Grid.Card_<relicId>`).
