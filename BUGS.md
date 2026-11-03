# Bekannte Fehler und Blocker

| # | Titel | Priorität | Status |
|---|---|---|---|
| 1 | Speichern nicht testbar: Studio-API-Zugriff aus | Hoch | ✅ Erledigt, Speichern/Rejoin/Lock getestet |
| 11 | Studio-Stopp verliert den letzten Speichervorgang | Mittel | Abgemildert (Autosave 60 s, Lock-Ablauf 180 s) |
| 2 | AFK-Farmen an Spawns | Mittel | ✅ Behoben (M2) |
| 3 | „Infinite yield“-Warnung beim Beitritt | Niedrig | ✅ Behoben (M2) |
| 4 | Unplace auf leerem Podest meldete `too_far` | Niedrig | ✅ Behoben (M2) |
| 5 | MCP-Bildschirmfoto zeitweise schwarz | Werkzeug | Umgangen |
| 6 | MCP-Mausklick per Koordinate | Werkzeug | Geklärt |
| 7 | 3D-Vorschau (ViewportFrame) schluckte Taps auf Relikt-Karten | Hoch | ✅ Behoben |
| 8 | Roblox-Chat und Spielerliste lagen über dem Fenster | Mittel | ✅ Behoben |
| 9 | Aufgabe „Stelle N Relikte aus“ lässt sich durch Tauschen erfüllen | Niedrig | Offen (bewusst) |
| 10 | Kristall-Licht überstrahlte den Platz | Niedrig | ✅ Behoben |
| 12 | Einsammel-Sound im Live-Client stumm (Datei nur in Studio vorhanden) | Mittel | ✅ Behoben (Block 1) |
| 13 | Zahnrad oben links lag unter Roblox' neuem Menüknopf | Niedrig | ✅ Behoben, jetzt unter „Shop“ |
| 15 | Prompts per MCP-Tastendruck reagieren nicht, Screenshots laufen ins Timeout | Werkzeug | Studio-Fenster rendert nicht (minimiert/verdeckt). Umgehung: `DevTools prompt` |
| 14 | Konsole: `ContentId rbxassetid://203785492 … Asset type does not match` | Werkzeug | Nicht aus unserem Place (Suche ergab 0 Treffer), ignorierbar |

## 1 Speichern nicht testbar
- **Reproduktion:** Playtest → Konsole: `StudioAccessToApisNotAllowed … API access is not enabled`. Das Spiel fällt korrekt auf den Arbeitsspeicher zurück.
- **Lösung:** In Studio *Home → Game Settings → Security → „Enable Studio Access to API Services“* einschalten und speichern. Das ist eine Sicherheitseinstellung, deshalb machst du das selbst. Live-Server sind davon nicht betroffen, dort funktionieren DataStores ohnehin.

## 5 / 6 Werkzeug-Einschränkungen
- `screen_capture` liefert manchmal eine schwarze 3D-Ansicht, vermutlich wenn das Studio-Fenster gerade nicht rendert. Die UI wird trotzdem korrekt erfasst.
- `user_mouse_input` mit x/y erwartet GUI-Koordinaten **ohne** Topbar-Inset. Mit `instance_path` klappt es immer. Wichtige Buttons haben deshalb feste Namen: `Nav.NavHome`, `Nav.NavCollection`, `Side.NavQuests`, `Side.NavShop`, `Guide.Skip`, `Side.GearSlot.Gear.Button`, `…Grid.Setting_music.Controls.Minus|Plus`, `…Grid.Setting_hints.Toggle`, `…Grid.Setting_credits.Open`, `PanelHost.RelicPanel.Close`, `PanelHost.RelicPanel.Grid.Card_<relicId>.Pick`, `…Grid.Item_<key>.Buy`, `…Grid.Quest<n>.Claim`.
- `screen_capture` liefert manchmal ein Bild, das einen Moment alt ist. Den Zustand deshalb zusätzlich per Abfrage prüfen.
- Aus dem MCP-Kontext ergibt `require` eine **eigene** Modul-Instanz. Echte Serverdaten deshalb nur über `ServerStorage.DevTools` lesen.

## 7 ViewportFrame schluckt Taps
- Ein Klick oder Tap auf die 3D-Vorschau einer Karte kam nie beim Button an, obwohl die Vorschau `Active = false` hat.
- **Fix:** Über jeder wählbaren Karte liegt jetzt eine transparente Tap-Fläche (`Pick`).

## 9 Aufgabe „Ausstellen“ per Tauschen
- Jedes Ausstellen zählt, auch wenn man dasselbe Relikt hin- und hertauscht. Das betrifft nur eine kleine Tagesaufgabe pro Tag und schadet niemandem. Falls gewünscht: nur neu belegte Podeste zählen.
