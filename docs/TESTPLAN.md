# Testplan für die gemeinsame Sitzung

Ziel: alles prüfen, was ich allein nicht testen kann. Reihenfolge so gewählt, dass du nur so oft wie nötig klicken musst. Geschätzt 30–40 Minuten.

## 0. Vorbereitung (5 min, du)
1. Roblox Studio öffnen, Place „Relik-Rausch: Schatzjäger“ laden.
2. **Studio-Fenster im Vordergrund lassen, nicht minimieren.** Sonst sehe ich nichts und Klicks kommen nicht an.
3. Rojo verbinden: *Plug-ins → Rojo → Connect* (ich starte vorher `rojo serve`).
4. Mir Bescheid geben – ich prüfe den Sync und starte die Tests.

## 1. Allein, ich steuere (10 min, du schaust zu)
Ich mache Screenshots und klicke selbst. Du musst nur hinsehen und sagen, was dir nicht gefällt.

| # | Was | Worauf achten |
|---|---|---|
| 1.1 | Haus vom Relikt-Raum bis zum Vollausbau (Testmodus, wird nicht gespeichert) | Wirkt es wie ein Haus? Treppe zur Empore gut begehbar? |
| 1.2 | Bau-Tasten an den Seiten | Lesbar, grün/grau verständlich? |
| 1.3 | Wächter-Geister auf Platz und im Wald | Sichtbar? Niedlich oder gruselig? |
| 1.4 | Kartenfenster („Karte“) und Reise zur Schatzinsel | Verständlich? Macht die Suche nach versteckten und geheimen Schätzen Spaß? |
| 1.5 | Einstellungen, Credits, Aufgaben mit Wochenziel | Layout ok? |
| 1.6 | Expedition solo durchspielen | Räume verständlich? Wächter fair? |
| 1.7 | Englisch (Testschalter) | Texte passen in die Knöpfe? |

## 2. Du spielst selbst (10 min)
1. **Geister jagen** mit WASD (oder Touch-Emulation): Fühlt sich das Fangen gut an? Zu schnell, zu langsam?
2. **Eine Bau-Taste** draufstellen: Kauf verständlich?
3. **Schatzinsel:** einmal hinreisen, den geheimen Schatz suchen (Wasserfall, Adlerfels, hohler Baum, Wrack) und den Meister-Geist jagen. Zu schwer, zu leicht?
4. **Hören:** Musik pro Gebiet, Einsammel-Sound, Ausbau-Fanfare. Gefällt dir die Auswahl? (Austausch = eine Zeile in `Shared/Sounds.luau`.)

## 3. Mehrspieler (10 min, *Test → Clients and Servers*)
Einstellung: **3 Spieler**. Studio öffnet einen Server und 3 Client-Fenster; ich steuere über MCP, du musst ggf. ein Client-Fenster anklicken.

| # | Test | Erwartung |
|---|---|---|
| 3.1 | Drei Spieler treten bei | 3 verschiedene Schatzkammern, eigene Schilder |
| 3.2 | Spieler 2 besucht Spieler 1 | Meldung „… bewundert deine Schatzkammer!“ bei Spieler 1 |
| 3.3 | Spieler 2 steht auf Bau-Taste von Spieler 1 | Nichts passiert (nur der Besitzer kauft) |
| 3.4 | Jeder sieht nur seine eigenen Geister | Ja |
| 3.5 | Expedition zu zweit | Beide in derselben Arena, Wächter braucht 6 Treffer, beide bekommen Truhe |
| 3.6 | Spieler 3 verlässt das Spiel | Grundstück wird frei („Freie Schatzkammer“) |

## 4. Mobil (5 min)
1. Studio *Test → Device* (Geräte-Emulation): kleines iPhone und ein Tablet. Ich prüfe, ob Knöpfe und Fenster passen.
2. **Später einmal am echten Handy:** Spiel öffnen, Geist fangen, Relikt ausstellen, eine Bau-Taste kaufen. Kurze Rückmeldung reicht.

## 5. Danach (du, ohne mich)
- Place **speichern und veröffentlichen** (*File → Publish to Roblox*). Erst dann sind Expeditions-Arena und Weltänderungen live.
- Optional: die Relikt-Modelle aus `assets/relics/` über *Import 3D* hochladen (Anleitung in `assets/relics/README.md`).
