# Übergabe an die nächste Sitzung – RELIC RUSH fertigstellen

Diese Datei ist der komplette Arbeitsauftrag. Lies sie zuerst, danach `STATUS.md`, `BUGS.md`, `CHANGELOG.md` und `README.md`.

## Rolle und Arbeitsweise
- Du bist das komplette Entwicklungsteam für **RELIC RUSH: Treasure Hunters** (Roblox, Projektordner `E:\RELIC-RUSH`).
- Arbeite autonom. Frag nur bei Veröffentlichung, Geldausgaben, Logins, echten Käufen oder Kontoeinstellungen.
- Kommuniziere auf Deutsch. Code-Kommentare bleiben auf Englisch.
- Eine Funktion gilt erst als fertig, wenn sie im Studio-Playtest **nachweislich** funktioniert. Behaupte nie einen Test, der nicht gelaufen ist.
- Arbeite auf Branch `dev`. Commit nach jedem Teilziel, Push zu `origin` ist erlaubt (privates Repo `danilohuth888-create/relic-rush`).
- `STATUS.md`, `BUGS.md` und `CHANGELOG.md` nach jedem Block aktualisieren.

## Start-Checkliste (in dieser Reihenfolge)
1. `git log --oneline -5` auf `dev`, sauberer Arbeitsbaum.
2. PATH auffrischen, dann Rojo starten:
   `$env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine"); Set-Location E:\RELIC-RUSH; rojo serve default.project.json` (im Hintergrund)
3. Den Nutzer bitten, in Studio unter **Plug-ins → Rojo → Connect** zu klicken. Den Sync mit einer harmlosen Kommentarzeile testen und sie danach wieder entfernen.
4. `list_roblox_studios`: Die Studio-ID ändert sich bei jedem Studio-Neustart.
5. `get_addon_status` in Blender: Poly Pizza und Poly Haven sind aktiv.

## Technische Regeln (wichtig!)
- **Quelle der Wahrheit für Code ist `src/`.** Rojo überträgt nach Studio. Skripte nie direkt in Studio ändern.
- Weltgeometrie: `tools/world/BuildAetheria.luau`. Neue Welt-Teile auch dort ergänzen, damit sie reproduzierbar bleiben.
- Serverautoritativ: Clients senden nur Wünsche. Jede Remote braucht Typprüfung, Reichweitenprüfung und RateLimiter.
- Fortschritt über `Util/Progress.luau` melden, nicht über Querverweise zwischen Services.
- Neue Datenfelder → `SCHEMA_VERSION` erhöhen und eine Migration in `PlayerDataService` schreiben.
- Testen über `ServerStorage.DevTools` (nur in Studio): `inspect`, `grant`, `setPass`, `receipt`, `save`, `showcase` (speichert nie).
- `require` aus dem MCP-Kontext ergibt eine eigene Modul-Instanz. Echte Daten nur über DevTools lesen.
- UI: `UIGradient` färbt auch den Text des eigenen Objekts. Text gehört deshalb in ein Kind-Label. ViewportFrames schlucken Taps, also eine transparente Tap-Fläche darüberlegen.
- MCP-Mausklicks am zuverlässigsten per `instance_path`. Feste Button-Namen stehen in `BUGS.md`.
- Studio rendert nur, wenn das Fenster nicht minimiert ist (wichtig für Screenshots).
- Poly-Pizza-Modelle sind CC-BY: Namensnennung in `docs/CREDITS.md` und einen Credits-Bereich im Spiel ergänzen. Poly Haven ist CC0.
- Keine echten Robux-Käufe. Studio-Testkäufe nur mit ausdrücklicher Zustimmung des Nutzers.

## Ziel: Release-Qualität
Abarbeiten in dieser Reihenfolge. Jeder Block wird getestet, dokumentiert und committet.

### 1. Sound und Spielgefühl
- Musik pro Gebiet (Platz, Flüsterwald, Schatzkammer) aus dem lizenzierten Roblox-Katalog (`search_asset`/`insert_asset`), sanft überblenden.
- Sounds für Einsammeln (gestaffelt nach Seltenheit), Buttons, Ausbau, Abholen, Kauf und Fehler.
- Effekte: „+X“-Zahlen über ausgestellten Relikten, Funkenregen beim Ausbau, Glitzern bei seltenen Funden, kurzes Kamera-Feedback.
- Einstellungsmenü (Zahnrad): Lautstärke für Musik und Effekte, Lumi-Hinweise an/aus, Credits. Speicherung im Profil (Schema v3).
- **Fertig, wenn:** jede Aktion hörbar und sichtbar Feedback gibt und die Einstellungen einen Rejoin überstehen.

### 2. Expedition „Vergessene Ruinen“ (M4)
- Das Portal bei den Ruinen öffnet eine eigene Instanz/Zone: Teleport in einen separaten Bereich derselben Welt ist einfacher und robuster als ein Place-Teleport.
- Für 1–4 Spieler, Dauer 3–5 Minuten: drei Runenmechanismen (z. B. Druckplatten, Lichtstrahl umlenken, Rätselsteine), kleine Gefahren ohne Frust, am Ende ein Kristallwächter mit einfachem Muster.
- Belohnung: gemeinsame Truhe. Epische und legendäre Relikte aus der Quelle `Expedition`, Ruinen-Relikte aus der Quelle `Ruins`. Danach sind alle 25 Relikte erreichbar.
- Abklingzeit pro Spieler, damit niemand farmt. Gesamter Ablauf serverautoritativ.
- **Fertig, wenn:** ein Durchlauf solo und zu zweit (Studio „Clients and Servers“ mit dem Nutzer) funktioniert und die Belohnung gespeichert wird.

### 3. Optik auf Profi-Niveau
- Relikte als Blender-Modelle (Low-Poly, ein Stil, je 200–1500 Dreiecke), Upload als MeshPart über Studio **Import 3D**. Der Nutzer lädt hoch, weil die Assets auf sein Konto gehen. Fallback bleibt `RelicVisuals`.
- Welt: Felsen und Gras-Büschel, Wasserfälle an den Inselrändern, schwebende Partikel, schönere Grundstücke (Boden-Muster, Banner, Laternen), Deko aus Poly Pizza/Haven mit Credits.
- Lichtstimmung und Performance prüfen: Teile zählen, Lichter begrenzen, StreamingEnabled bleibt an.
- **Fertig, wenn:** die drei Gebiete auf Screenshots eigenständig und hochwertig wirken und die Bildrate in Studio stabil bleibt.

### 4. Reichweite und Langzeit
- Englische Fassung aller Spieltexte (LocalizationTable oder eine Texttabelle in `Shared`), Sprache automatisch nach Spielersprache.
- Bestenliste „Größte Sammlung“ (OrderedDataStore, aktualisiert sparsam) im Kristallplatz.
- Wöchentliches Ziel zusätzlich zu den Tagesaufgaben, ohne Druck.
- **Fertig, wenn:** ein Spieler mit englischem Client alles auf Englisch sieht und die Bestenliste mit mehreren Profilen funktioniert.

### 5. Release-Prüfung (M6)
- Mehrspieler-Test mit dem Nutzer (Studio *Test → Clients and Servers*, 3 Spieler): getrennte Grundstücke, Besuchsmeldung, keine fremden Relikte, Freigabe beim Verlassen.
- Mobile-Prüfung: Studio-Geräteemulation (kleines iPhone, Tablet). Den Nutzer bitten, einmal am echten Handy zu testen.
- Sicherheits-Durchgang aller Remotes (Spam, falsche Typen, fremde Slots), Duplikationstests erneut.
- Thumbnails und Icon aktualisieren, wenn sich die Optik deutlich verbessert hat (`tools/marketing/make-thumbnail.ps1`).
- `RELEASE_CHECKLIST.md` vollständig abhaken, Releasekandidat mit Freigabe des Nutzers nach `main` mergen und taggen.

## Grenzen
- Nichts veröffentlichen, nichts öffentlich/privat schalten, keine Preise ändern. Das macht der Nutzer im Creator Dashboard.
- Keine Geheimnisse ins Repo. API-Schlüssel nur als Umgebungsvariablen beim Nutzer.
- Wenn ein Block zu groß wird: einen fertigen, stabilen Teil abliefern statt viel Halbfertiges.

## Bekannter Stand (Kurzfassung)
- Live: private→öffentliche Experience, GameId 10774417779, PlaceId 125952423660999, Altersfreigabe „Minimal“.
- Shop-IDs sind eingetragen (4 Pässe, 2 Developer Products). Speichern, Rejoin und Session-Lock sind getestet.
- UI-Überarbeitung 0.3.0 ist fertig. Offen: Mehrspieler-Test, echtes Handy, Expedition, Sound.
