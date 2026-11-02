# Status

Stand: 2026-11-02 · Branch `dev` · Experience: GameId 10774417779 / PlaceId 125952423660999 (**privat**)

## Aktueller Meilenstein

**M2 (Sammel-MVP) fertig, M3 (Inhalte und Langzeitmotivation) und M5 (Shop-Architektur) größtenteils fertig.**
Alles im Studio-Playtest geprüft. Offen ist vor allem der Speichertest: Der Studio-API-Zugriff ist noch aus (BUGS #1).

## Fertig

### M0 – Werkzeuge und Projekt
- Roblox-Studio-MCP und Blender-MCP funktionieren.
- Ausgangszustand gesichert (`backups/`, `ServerStorage.M0_Backup`).
- Git: `main` enthält die Baseline, entwickelt wird auf `dev`.
- Sync-Check Repo ↔ Studio (`tools/sync`).
- Place als private Experience veröffentlicht.

### M1 – Kernschleife
Einsammeln → Ausstellen → Münzen, persönliche Relikt-Spawns, 8 Grundstücke, HUD. Details siehe CHANGELOG 0.1.0.

### M2 – Sammel-MVP
- **Ausbaustufen:** Stufe 2 (8 Podeste, 500 Münzen) und Stufe 3 (12 Podeste, 5000 Münzen), gekauft am Ausbau-Stein durch Halten von E bzw. Antippen.
  - Gesperrte Podeste sind als Geister sichtbar, damit man sieht, was der Ausbau bringt.
  - Zusätzliche Deko pro Stufe: Runensäulen; bei Stufe 3 goldener Torbogen und schwebender Kristall.
- **Lumi:** Der Tutorial-Geist schwebt neben dem Spieler und zeigt mit einem Lichtstrahl zum nächsten Ziel. Die Schritte richten sich nach dem echten Fortschritt (Relikt → ausstellen → ausbauen → Flüsterwald). Abschluss und Überspringen werden auf dem Server gespeichert.
- **Schema v2** mit Migration von v1 (Sammelbuch aus vorhandenen Relikten nachgetragen).
- **Offline-Einnahmen:** 25 % der Rate, maximal 2 Stunden, mit Willkommensmeldung.
- **AFK-Lücke geschlossen:** Hineinlaufen sammelt nur beim Betreten des Radius.
- **Streaming:** Die Warnung beim Beitritt ist behoben.

### M3 – Langzeitmotivation
- **Sammelbuch:** alle 25 Relikte, unentdeckte als „?“ in Seltenheitsfarbe. Meilensteine bei 3/6/10/15/20/25 entdeckten Relikten (150 bis 40.000 Münzen).
- **Tägliche Aufgaben:** 3 pro Tag aus 6 Typen (sammeln, Flüsterwald, ausstellen, Münzen verdienen, seltene finden, fremde Schatzkammer besuchen). Ziel und Belohnung wachsen mit der Stufe, ein roter Hinweispunkt zeigt abholbare Belohnungen.
- **Soziales:** Wer eine fremde Schatzkammer besucht, meldet das dem Besitzer („X bewundert deine Schatzkammer!“). Die Besuchsaufgabe erscheint nur, wenn beim Beitritt mindestens 2 Spieler auf dem Server sind.
- **Glücksrune:** wiederholbare Münz-Ausgabe. 5 Minuten doppelte Chance auf alles über „gewöhnlich“, wartende Relikte werden sofort neu gewürfelt.

### M5 – Monetarisierung und Analytics (Architektur)
- **Shop** mit Glücksrune (Münzen) und Robux-Artikeln: Pässe Flügel, Sternenaura, VIP, Doppelte Münzen; Produkte Münzbeutel und Münzschatz. Alle sind optional, es gibt keine Zufallsboxen und keine Countdowns.
- **Kaufabwicklung:** `ProcessReceipt` ist idempotent (Kauf-IDs werden im Profil gespeichert) und meldet „gewährt“ erst nach dem Speichern. Pässe prüft der Server.
- **Kosmetik:** Flügel, Aura, VIP-Namensschild und goldene Schatzkammer werden am Charakter bzw. Grundstück angezeigt.
- **Analytics:** Onboarding-Funnel (Beitritt → erstes Relikt → erstes Ausstellen → erstes Upgrade → Wald → Tutorial fertig), Münzflüsse, Öffnen von Shop, Aufgaben und Sammlung, Tutorial übersprungen, Pass gekauft.
- **Artikel-IDs fehlen noch** (id = 0, im Shop steht „Bald verfügbar“). Du legst die Artikel im Creator Dashboard an.

## Verschoben
- **M4 Expedition „Vergessene Sternenkammer“:** wird ein Update nach dem Launch, so erlaubt es dein Masterprompt. Das Portal steht als „Bald geöffnet“. Episch/Legendär (5 Relikte) und Ruinen-Relikte (2) sind dadurch noch nicht erreichbar: **18 von 25 sind sammelbar**, Meilensteine bis 15 erreichbar.

## Nächste Aufgaben
1. Speichern/Rejoin/Session-Lock testen, sobald der Studio-API-Zugriff an ist (BUGS #1).
2. Shop-IDs eintragen, sobald du die Artikel angelegt hast.
3. 8-Spieler-Test mit Studio *Test → Clients and Servers*.
4. Mobile-Prüfung am echten Gerät.
5. Spielicon und Thumbnails, Beschreibung (M6).
6. Musik und mehr Soundeffekte.
7. Expedition (M4) als erstes Update.

## Verifizierter Teststatus

Alle Tests liefen am 2026-11-02 im Studio-Playtest der veröffentlichten Experience (1 Spieler, Server + Client) über MCP. Klicks und Tastendrücke kamen über echte Eingabesimulation, Serverdaten wurden über `ServerStorage.DevTools` gelesen (nur in Studio vorhanden).

| Test | Art | Ergebnis |
|---|---|---|
| Server startet fehlerfrei, Schema v2, 3 Tagesaufgaben erzeugt | automatisiert | ✅ |
| Speicher-Fallback bei gesperrtem API-Zugriff (403) greift, Spiel läuft weiter | automatisiert (Konsole) | ✅ |
| Lumi erscheint, Hinweis + Lichtstrahl zum Relikt, wechselt mit jedem Schritt | Playtest | ✅ |
| Einsammeln, Teleport „Schatzkammer“, Podest per E, Karte antippen → ausgestellt | Playtest (echte Klicks) | ✅ |
| Ausbau per gehaltenem E: Stufe 2, −500 Münzen, Podeste 5–8 aktiv, 9–12 Geister, Deko 2 sichtbar, Schild „Aetherhalle 5000“ | Playtest | ✅ |
| Ausbau ohne genug Münzen → `no_coins` | automatisiert | ✅ |
| Glücksrune: −1500, Timer 4:59 in der HUD, Relikte neu gewürfelt (2× selten), zweiter Kauf → `luck_active` | Playtest + automatisiert | ✅ |
| Flüsterwald betreten → besucht, Tutorial automatisch abgeschlossen | Playtest | ✅ |
| Aufgabe abholen per Klick: +900, zweites Abholen → `claimed`, unfertig → `not_done`, Index 99 → `bad_quest` | Playtest + automatisiert | ✅ |
| Sammelbuch-Meilenstein bei 3 entdeckten Relikten (+150) | Playtest | ✅ |
| „Überspringen“ beendet das Tutorial serverseitig | Playtest | ✅ |
| Kaufbeleg simuliert: gleiche Kauf-ID zweimal → nur einmal +3000 | automatisiert | ✅ |
| Pässe simuliert: Flügel, Aura, VIP-Schild, goldene Schatzkammer, Doppelte Münzen (Rate 1 → 2) | automatisiert + Screenshot | ✅ |
| Shop-Fenster: Glücksrune kaufbar, Robux-Artikel ohne ID gesperrt | Playtest + Screenshot | ✅ |
| Fenster offen → Prompts, Chat und Spielerliste ausgeblendet; beim Schließen zurück | Playtest | ✅ |
| M1-Tests (Manipulation, Duplikation, Rate-Limit, Plot-Freigabe) | vorher bestanden, Code unverändert | ✅ |
| Repo und Studio identisch (22 Skripte) | `tools/sync` | ✅ |

### Noch nicht getestet / manuell zu prüfen
- **Speichern, Rejoin, Offline-Einnahmen nach echter Pause, Session-Lock zwischen zwei Servern:** braucht Studio-API-Zugriff.
- **Echte Robux-Käufe:** bewusst nicht ausgelöst; nur die Gutschrift-Logik ist simuliert.
- **8 Spieler gleichzeitig, Besuchs-Meldung zwischen zwei echten Spielern.**
- **Smartphone-Bedienung** am Gerät.
- **3D-Vorschau in den Karten:** In den letzten Bildern war die ganze 3D-Ansicht schwarz, auch ohne offenes Fenster. Das liegt offenbar am Rendern von Studio, nicht am Spiel. Bitte einmal selbst ansehen.
