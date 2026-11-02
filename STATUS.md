# Status

Stand: 2026-11-02 · Branch `dev`

## Aktueller Meilenstein

**M1 – Erste spielbare Kernschleife: abgeschlossen und im Studio-Playtest nachgewiesen.**
Nächster Meilenstein: **M2 – Vollständiger Sammel-MVP.**

## Fertig

### M0 – Werkzeuge und Projekt
- Roblox-Studio-MCP und Blender-MCP geprüft und funktionsfähig.
- Ausgangszustand gesichert: `backups/m0-studio-baseline.json`; Originalobjekte nach `ServerStorage.M0_Backup` verschoben, nicht gelöscht.
- Git-Repo, Baseline-Commit auf `main`, Entwicklung auf `dev`.
- Rojo-kompatible Struktur, Sync-Check Repo ↔ Studio (`tools/sync`).

### M1 – Kernschleife
- Kompakte Insel Aetheria (707 Parts): Kristallplatz mit schwebendem Aetherkristall, 4 Spawnpads, 8 Schatzkammern, Wege, Flüsterwald-Vorschau, versiegeltes Ruinenportal, schwebende Nebeninseln, Lichtstimmung.
- 25 Relikte datengetrieben definiert, alle mit prozeduralem Modell. Im Spiel erreichbar sind bisher Plaza und Flüsterwald; Ruinen und Expedition sind für M4 reserviert.
- Persönliche Relikt-Spawns (11 Punkte) mit garantiertem Start-Relikt (Mondstein), Respawn 30–60 s.
- Einsammeln per Prompt (Taste E / Tippen) oder durch Hineinlaufen, mit Lichtsäule, Sound und Animation.
- Inventar, Sammlungsfenster mit 3D-Vorschau pro Relikt.
- Automatische Grundstückszuweisung mit Besitzerschild und Leuchtakzenten, Freigabe beim Verlassen.
- Ausstellen, Tauschen und Zurücklegen auf 4 Podesten (Stufe 1), sichtbar für alle Spieler.
- Münzproduktion serverseitig pro Sekunde, Anzeige in HUD und Leaderstats.
- HUD: Münzzähler mit Rate, Zielhinweis für die ersten Schritte, Navigation „Sammlung“ / „Schatzkammer“ (Teleport nach Hause), Toasts.
- Speicherschicht mit Session-Lock, Retries, Autosave und Migrationsgerüst. Im unveröffentlichten Place läuft sie nur im Speicher-Fallback.

## In Arbeit
- nichts

## Nächste Aufgaben (M2)
1. Schatzkammer-Upgrades Stufe 2/3 kaufen (UpgradeService, Preise aus `Config.Tiers`), gesperrte Podeste sichtbar andeuten.
2. Tutorial-Geist Lumi mit gespeichertem Fortschritt, überspringbar.
3. Persistenz echt testen. Blockiert: Der Place muss veröffentlicht werden (privat), siehe BUGS #1.
4. Mobile-Test der UI bei mehreren Auflösungen (Studio-Geräteemulation).
5. Auto-Einsammeln nur beim Hineinlaufen, nicht beim Stehenbleiben (BUGS #2).
6. Offline-Einnahmen (gedeckelt) entscheiden.

## Verifizierter Teststatus

Alle Tests liefen im Studio-Playtest (1 Spieler, Server + Client) über MCP am 2026-11-02.

| Test | Art | Ergebnis |
|---|---|---|
| Server startet fehlerfrei, Speicher-Fallback meldet sich | automatisiert (Konsole) | ✅ |
| Grundstück wird beim Beitritt zugewiesen, Schild zeigt Besitzer | automatisiert | ✅ |
| 11 persönliche Relikte erscheinen beim Client | automatisiert | ✅ |
| Start-Relikt per Hineinlaufen einsammeln → Inventar `moonstone:1` | Playtest mit Figur-Navigation | ✅ |
| Button „Schatzkammer“ (echter Klick) teleportiert zum eigenen Grundstück | Playtest | ✅ |
| Podest-Prompt per Taste E öffnet Auswahl, Klick auf Karte stellt aus | Playtest | ✅ |
| Münzen steigen mit 1/s (Mondstein), Leaderstats stimmen | automatisiert | ✅ |
| Tauschen gibt altes Relikt zurück, Zurücklegen funktioniert | automatisiert über Remotes | ✅ |
| Gegenstände bleiben erhalten (Inventar + Ausstellung vor/nach = 3/3) | automatisiert | ✅ |
| Manipulierte Remotes abgewiesen: unbekannte Spawn-ID, Tabelle statt String, ferner Spawn, nicht besessenes / unbekanntes Relikt, gesperrtes Podest, Slot 1.5 / "1" / 999 / NaN / ∞ | automatisiert | ✅ |
| Rate-Limit greift (16 von 20 Spam-Aufrufen abgewiesen) | automatisiert | ✅ |
| 8 Spieler → 8 verschiedene Grundstücke, 9. bekommt keins, freies wird wiederverwendet | Logiktest (`pickFreeIndex`) | ✅ |
| Verlassen gibt Grundstück frei (Schild, Ausstellung, Akzente zurückgesetzt) | Playtest (Kick) | ✅ |
| Münzraten-Berechnung inkl. unbekannter IDs | Logiktest | ✅ |
| Repo und Studio identisch (16 Skripte) | `tools/sync` | ✅ |

### Noch nicht getestet / manuell zu prüfen
- **Speichern und Rejoin** (Inventar, Münzen, Ausstellung, Upgrades): erst möglich, wenn der Place veröffentlicht ist und Studio-API-Zugriff aktiv ist.
- **Echte 8-Spieler-Sitzung** (Studio „Local Server“ mit mehreren Clients) – bisher nur Logiktest.
- **Touch auf echtem Smartphone** und kleine iPhones; UI skaliert per UIScale (0,62–1,15), aber nicht auf Geräten geprüft.
- **Seltenheitsverteilung der Spawn-Würfe** statistisch.
- **Performance** auf schwachen Geräten (707 Parts, ~10 PointLights).
