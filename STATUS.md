# Status

Stand: 2026-11-03 · Branch `dev` · Experience: GameId 10774417779 / PlaceId 125952423660999 (live, Altersfreigabe „Minimal“)

## Aktueller Meilenstein

**Release-Qualität nach `docs/NEXT_SESSION.md`.** Blöcke:

| Block | Inhalt | Stand |
|---|---|---|
| 1 | Sound und Spielgefühl, Einstellungen (Schema v3) | ✅ fertig, im Playtest geprüft |
| 2 | Expedition „Vergessene Ruinen“ (M4) | ✅ solo im Playtest geprüft; Zweier-Test mit dir offen |
| 2b | Tycoon-Ausbau mit Kauftasten (dein Wunsch) | ✅ im Playtest geprüft |
| 2c | Wächter-Geister fangen (ersetzt die Lichtsäulen) | ✅ serverseitig geprüft; Live-Lauftest mit dir offen |
| 2d | Schatzkarten-Rätsel | ✅ Logik geprüft; Kartenfenster noch nicht gesehen |
| 3 | Optik auf Profi-Niveau | Welt-Deko ✅ (Screenshots, 60 FPS im Playtest); Relikt-Modelle warten auf deinen Upload (*Import 3D*) |
| 4 | Englisch, Bestenliste, Wochenziel | ✅ im Playtest geprüft (Englisch per Testschalter) |
| 5 | Release-Prüfung (M6) | offen |

### Block 1 – Sound und Spielgefühl
- **Musik pro Gebiet** (Kristallplatz, Flüsterwald, Schatzkammer, Ruinen) mit 1,8 s Überblendung; ausgeblendete Stücke pausieren und laufen später weiter.
- **Soundeffekte** für Einsammeln (Tonhöhe nach Seltenheit, ab „selten“ Glitzern, ab „episch“ Fanfare), Buttons, Fenster, Ausstellen/Zurücklegen, Ausbau, Abholen, Kauf, Fehler, Besuch. Nur lizenzierte Roblox-Audiobibliothek (APM, Pro Sound Effects), siehe `docs/CREDITS.md`.
- **Effekte:** goldene „+X“-Zahlen über ausgestellten Relikten der eigenen Schatzkammer (alle 3 s, versetzt), Funkenregen und Kamera-Kick beim Ausbau, Glitzerwolke in Reliktfarbe bei seltenen Funden, Kamera-Kick ab „episch“.
- **Einstellungen (Zahnrad unter „Shop“):** Lautstärke Musik und Effekte in 10 %-Schritten, Lumi-Hinweise an/aus, Credits. Gespeichert im Profil (**Schema v3**, Migration von v2), serverseitig geprüft und rate-limitiert.

### Block 2 – Expedition „Vergessene Ruinen“
- **Start am Ruinenportal** (E halten): 8 s Sammelphase, bis zu 4 Spieler, dann Teleport in eine eigene Kopie der Arena weit weg von der Insel (bis zu 3 Gruppen gleichzeitig).
- **Raum 1 Druckplatten:** Reihenfolge von der Tafel, falsche Platte setzt zurück.
- **Raum 2 Spiegelsaal:** drei Spiegel drehen, bis der Lichtstrahl den Kristall trifft; ein Irrlicht schickt Berührte zum Raumeingang zurück (kein Schaden).
- **Raum 3 Rätselsteine:** drei Steine auf die Symbole über dem Tor drehen.
- **Kristallwächter:** leuchtende Runensäule entfesseln (5 Treffer, +1 je weiterem Spieler); der Wächter stampft mit roter Vorwarnung und schubst Getroffene weg.
- **Truhe:** pro Spieler 1 episches/legendäres Relikt (20 % legendär), 1 Ruinen-Relikt, Münzen nach Stufe; bevorzugt noch nicht entdeckte Relikte. **Damit sind alle 25 Relikte erreichbar.**
- **Abklingzeit 10 min pro Spieler** (im Profil, Schema v4). Wer sie noch hat, kann als Begleiter helfen und bekommt 25 % der Münzen, keine Relikte.
- Zeitlimit 8 min, Stürze und Respawns bringen zum letzten Kontrollpunkt, „Verlassen“-Knopf in der Ziel-Leiste.
- Arena-Vorlage: `ServerStorage.ExpeditionArena`, gebaut von `tools/world/BuildExpedition.luau`.

### Block 2b – Tycoon-Ausbau
- Statt drei großer Ausbaustufen kauft man die Schatzkammer **Stück für Stück an leuchtenden Bau-Tasten** (6 Tasten an den Seiten des Grundstücks; draufstellen = kaufen, grün = bezahlbar). Danach erscheinen die nächsten Tasten.
- **22 Bauteile** (`Shared/Builds.luau`, zusammen 131.090 Münzen): Podeste 5–12, Laternen, Goldteppich, Münzbrunnen, Wächterstatuen, Glasvitrinen, Kristalllüster, Schatzkrone, die Hallen „Runensaal“ und „Aetherhalle“ (= Stufe 2 und 3) und eine **Galerie mit 4 Extra-Podesten (13–16)**.
- **Einkommens-Boni** von Laternen, Teppich, Brunnen, Statuen, Vitrinen, Lüster, Krone: zusammen bis ×1,75.
- Bauteile wachsen mit Animation, Funkeln und Sound ins Bild; der alte Ausbau-Stein zeigt jetzt „Bauplan x / 22 gebaut“.
- **Schema v5:** Wer schon Stufe 2/3 hatte, behält alle Podeste und Hallen.
- Kaufen läuft komplett auf dem Server (Positionsprüfung), es gibt keine Kauf-Remote mehr.

### Block 2c – Wächter-Geister
- Die Lichtsäulen sind weg. An jedem Fundort schwebt ein **eigener Wächter-Geist** (schimmernder Körper, Augen, Schweif) und trägt ein Relikt.
- Kommt man näher als 18 Studs, **flieht** er („!“), weicht als seltener Geist kurz vor dem Fangen seitlich aus und bleibt an seinem Fundort (Leine 22 Studs). Nach 2,5–6 s Flucht ist er **erschöpft** („💤“, 30 % Tempo).
- **Fangen = hineinlaufen.** Seltenere Geister sind schneller und ausdauernder (6,5 bis 13,5 Studs/s, Spieler laufen 16).
- Lumis erster Geist ist extra langsam. Glücksrune würfelt die getragenen Relikte neu.
- Alles läuft auf dem Server (5×/s); der Client zeichnet nur. Die Einsammel-Remote gibt es nicht mehr, Stillstehen fängt nichts.

### Block 2d – Schatzkarten
- Gefangene Geister verlieren mit 20 % (bis zum ersten Schatz 45 %) ein **Kartenteil** (nach dem Tutorial).
- Mit **3 Teilen** ist die Karte lesbar: unten gibt es den neuen Knopf **„Karte“** (rotes „!“ bei offener Karte). Das Fenster zeigt die gezeichnete Insel mit Platz, Wald, Ruinen, Schatzkammern, deiner Position, dem **roten X** und einem **Rätselhinweis** („Im Südwesten, auf der stillen Wiese“).
- Am Ziel erscheint nur für dich ein Erdhügel mit rotem Kreuz und Funkeln: **E halten (1,2 s) = graben**.
- Schatz: mindestens ungewöhnliches Relikt (Glück ×4) und Münzen nach Stufe (400/1.600/6.000). 8 Verstecke auf der Insel (`Config.Maps.spots`).
- **Schema v6.** Graben prüft der Server (Karte offen, Entfernung, Rate-Limit).

### Block 4 – Reichweite und Langzeit
- **Wochenziel** (Montag 00:00 UTC): eins aus 4 Arten (Geister fangen, Schätze, Expeditionen, Münzen), Ziel nach Stufe, Belohnung 1.500/6.000/20.000 Münzen **plus ein Kartenteil**. Steht als lila Karte oben im Aufgaben-Fenster, ohne Ablaufdruck innerhalb der Woche. Schema v7.
- **Englische Fassung:** Wer Roblox nicht auf Deutsch nutzt, sieht alles auf Englisch (HUD, Lumi, Meldungen, Prompts, Schilder, Bau-Tasten, Bestenliste, Zahlen mit „1,100“). Texte stehen deutsch im Code; `Shared/LocaleEN.luau` enthält 248 Übersetzungen, `python tools/i18n/check.py` meldet fehlende. Server-Meldungen werden pro Spieler übersetzt, Welttexte übersetzt jeder Client selbst (`LocalizeController`, `Util/WorldText`). Test in Studio: Workspace-Attribut `TestLanguage = "en"` vor dem Start setzen.
- **Bestenliste „Größte Sammlung“** als Tafel am Kristallplatz: Top 10 nach entdeckten Relikten (Gleichstand: mehr Relikte im Besitz). Schreibt höchstens alle 90 s pro Spieler und beim Verlassen, liest alle 2 min. Studio nutzt einen eigenen Store, Tests verfälschen die Live-Liste nicht.

### Vorbereitet für die nächste gemeinsame Sitzung
- **`docs/TESTPLAN.md`:** Ablauf für 30–40 Minuten (Optik, selbst spielen, 3-Spieler-Test, Mobil).
- **`assets/relics/`:** 15 Low-Poly-Formen (66–476 Dreiecke, einheitlicher Stil) als FBX + `relics.blend` + Vorschau. Hochladen per *Import 3D* in `ReplicatedStorage.RelicMeshes` (Anleitung im README). `RelicVisuals` färbt und skaliert sie automatisch; ohne Upload bleibt alles wie bisher. Mit Platzhaltern in Studio getestet.

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
| **Echter DataStore:** Speichern (`persistent=true`), Daten + Sperre im Store nachgelesen | automatisiert | ✅ |
| **Rejoin:** Stufe 2, ausgestellter Mondstein, Sammelbuch, Münzen wieder da (+10 Offline-Münzen) | Playtest | ✅ |
| **Session-Lock:** fremder, frischer Lock → Spieler nach ~20 s mit Hinweis abgewiesen, fremde Daten unverändert | automatisiert | ✅ |
| **Veralteter Lock** (Absturz vor 4 min) → übernommen, Daten vollständig | automatisiert | ✅ |
| **Shop mit echten IDs:** alle 6 Preise live von Roblox, Pass-Besitz erkannt | Playtest | ✅ |
| **Block 1:** Migration v2 → v3 auf echtem gespeicherten Profil (Einstellungen mit Standardwerten) | automatisiert | ✅ |
| **Block 1:** 17 Audio-Assets laden in Studio (Länge > 0) | automatisiert | ✅ |
| **Block 1:** Platz-Musik läuft; Wechsel zu Wald und Schatzkammer blendet über (alte Spur 0 und pausiert) | Playtest | ✅ |
| **Block 1:** Zahnrad → Einstellungen; Musik −2, Effekte −1, Lumi aus per echten Klicks → Lautstärken 0,4/0,7, Lumi weg, Server hat die Werte | Playtest (echte Klicks) | ✅ |
| **Block 1:** Einstellungen nach Speichern + Neustart (Rejoin) unverändert | Playtest | ✅ |
| **Block 1:** `SaveSettings` mit String, NaN, 5, −1, `hints="yes"`, fehlenden Feldern → `bad_settings`; 10× Spam → `rate` | automatisiert (Client-Remote) | ✅ |
| **Block 1:** Einsammeln eines ungewöhnlichen Relikts → Triangel mit Tonhöhe 1,12 + Meldung | Playtest (Hineinlaufen) | ✅ |
| **Block 1:** „+22“ über dem Silberkelch (3,6/s × 2 Pass × 3 s) | Playtest | ✅ |
| **Block 1:** Ausbau-Meldung → Fanfare, Funkenregen über dem Grundstück, Kamera-Kick | Playtest | ✅ |
| **Block 1:** Credits-Ansicht und Zurück | Playtest (echte Klicks) + Screenshot | ✅ |
| **Block 2:** Schema v4 migriert (Expedition: Abklingzeit, Läufe, Siege) | automatisiert | ✅ |
| **Block 2:** Portal → Lobby-Countdown 8 s → Teleport in Arena, Musik „Ruinen“, Ziel-Leiste mit Timer | Playtest | ✅ |
| **Block 2:** Druckplatten: falsche Platte löscht alle, richtige Reihenfolge öffnet Tor 1 | Playtest | ✅ |
| **Block 2:** Irrlicht berührt → zurück zum Raumeingang; 3 Spiegel gedreht → Strahl trifft, Tor 2 offen | Playtest | ✅ |
| **Block 2:** Rätselsteine eingestellt → Tor 3 offen | Playtest | ✅ |
| **Block 2:** Nicht geladene Säule bewirkt nichts; 5 Treffer → Wächter zerfällt, Truhe und Portal erscheinen | Playtest | ✅ |
| **Block 2:** Wächter-Stampfer: 2 Rückstöße in 12 s auf einen stehenden Spieler | Playtest | ✅ |
| **Block 2:** Truhe: Zeitenspiegel (episch) + Schattenmaske (Ruinen) + 2.500 Münzen, Abklingzeit 600 s; zweites Öffnen zahlt nicht | Playtest | ✅ |
| **Block 2:** Nach allen Truhen → Rückkehr zum Portal, Arena gelöscht, Attribute leer | Playtest | ✅ |
| **Block 2:** „Verlassen“ per Client-Remote mitten im Kampf → Portal, Arena gelöscht | automatisiert (Client-Remote) | ✅ |
| **Block 2:** Begleiter während Abklingzeit: 0 Relikte, 625 Münzen (25 %), Abklingzeit unverändert | Playtest | ✅ |
| **Tycoon:** Migration v4 → v5 (Stufe 2 → Podeste 5–8 + Runensaal), 8 Podeste aktiv, 3 Tasten mit Angeboten | automatisiert | ✅ |
| **Tycoon:** Auf Taste stellen → genau ein Kauf (Laternen −220, Rate 9,2 → 9,66); erst nach Runtergehen kauft die Taste wieder | Playtest | ✅ |
| **Tycoon:** Krone ohne Voraussetzungen → `locked_build`, falsche ID → `bad_build`, doppelt → `owned` | automatisiert | ✅ |
| **Tycoon:** Alle 22 Bauteile nacheinander (Testmünzen, Profil nicht gespeichert): Stufe 3, 16/16 Podeste, Rate ×1,75 | automatisiert | ✅ |
| **Tycoon:** Relikt auf Galerie-Podest 13 ausgestellt, 16 Client-Prompts aktiv | Playtest | ✅ |
| **Geister:** 11 Geister pro Spieler erscheinen auf dem Client | Playtest | ✅ |
| **Geister:** Verfolgung mit Laufgeschwindigkeit → ungewöhnlicher Geist nach 1,6 s gefangen, Relikt im Inventar, Meldung + Glitzer | Playtest (serverseitig bewegt) | ✅ |
| **Geister:** In 9 Studs Abstand hinterherlaufen → Zustände flee 23 / tired 16 | Playtest | ✅ |
| **Geister:** 8 s regungslos auf dem Fundort: neuer Geist erscheint 17,6 Studs entfernt, nichts gefangen | Playtest | ✅ |
| **Karten:** Schema v6; 3 Teile → Versteck 8, 4. Teil bei offener Karte ignoriert | automatisiert | ✅ |
| **Karten:** Badge „!“ am Karten-Knopf, Erdhügel an (−125, 118) nur beim Spieler | Playtest | ✅ |
| **Karten:** Graben zu weit weg → `too_far`; am Ort → Mondstein + 1.600; nochmal → `no_map`, Hügel und Badge weg | Playtest (Client-Remote) | ✅ |
| **Karten:** Nach Fix nie „gewöhnlich“: Frostkrone (selten) + 1.600 | Playtest | ✅ |
| **Wochenziel:** v7, Ziel „70 Geister“ gewählt, Fang zählt mit (1/70); fertig → +6.000 + Kartenteil, nochmal → `claimed` | Playtest | ✅ |
| **Bestenliste:** 4 Testprofile + eigenes: Reihenfolge 25 / 12 (120009) / 12 (120003) / 5 / 3, Tafel zeigt Namen; Testeinträge entfernt | automatisiert | ✅ |
| **Englisch:** mit `TestLanguage=en`: Navigation, Seitenmenü, Meldung „A map piece! (1 of 3)“, Münzen „39,487“, eigenes Schild „…'s Treasury“, Bauplan, Bau-Tasten („Lanterns (220 coins · +5 %)“), Reliktschild, Platzschild, Bestenliste, Portal- und Podest-Prompts | Playtest | ✅ |
| **Englisch:** Gegenprobe Deutsch: Server-Texte unverändert deutsch, keine Steuerzeichen | Playtest | ✅ |
| **Englisch:** `tools/i18n/check.py`: 248 Texte, 0 fehlend | automatisiert | ✅ |

| **Welt-Deko:** `tools/world/BuildDecor.luau` baut `Workspace.Aetheria.Decor` (1.854 Teile, 11 Lichter): Randfelsen, 4 Wasserfälle mit Gischt, Wiesenflecken, Gras, Blumen, Büsche, Blütenbäume, 26 Weglaternen, Hecken um die Schatzkammern, Blumenbeete am Platz, dichterer Flüsterwald mit Glühwürmchen, Ruinenhof mit Bodenplatten, Säulenresten und blauen Fackeln, Kristalle und Ranken an der Inselunterseite | Screenshots Edit-Modus | ✅ |
| **Welt-Deko:** hält Abstand zu Plätzen, Wegen, Schatzkammern, Grab-Verstecken, Geister-Spawns und Hügeln (liest das Layout live) | Code + Screenshots | ✅ |
| **Performance:** Playtest-Client 60 FPS (Heartbeat und Rendern), 2.741 gestreamte Teile, keine Skriptfehler | Playtest | ✅ |

### Noch nicht getestet / manuell zu prüfen
- **Letztes Speichern beim Verlassen in Studio:** Beim Stoppen beendet Studio den Server so schnell, dass der letzte Schreibvorgang fehlte (bis zu einem Autosave-Intervall Fortschritt). Live-Server geben `BindToClose` 30 s. Abgemildert durch Autosave alle 60 s; der echte Test geht nur auf Live-Servern.
- **Echte Robux-Käufe:** bewusst nicht ausgelöst; die Gutschrift-Logik ist simuliert. Als Ersteller besitzt du deine Pässe automatisch, deshalb zeigt dein Shop „Besitzt du“, und deine Rate ist mit „Doppelte Münzen“ verdoppelt.
- **8 Spieler gleichzeitig, Besuchs-Meldung zwischen zwei echten Spielern.**
- **Smartphone-Bedienung** am Gerät.
- **Expedition zu zweit** (Studio *Clients and Servers*) und echte Tasten-/Touch-Bedienung der Prompts: Mein Studio-Fenster rendert gerade nicht, deshalb habe ich die Prompts serverseitig über `DevTools prompt` ausgelöst (gleiche Reichweiten-, Mitglieds- und Rate-Prüfung wie echte Eingaben).
- **Geister mit echter Steuerung fangen** (Tastatur/Touch): Bei verdecktem Studio-Fenster bewegt sich die Spielfigur nur per Teleport; ein Versuch mit Client-Teleports fing nichts. Serverseitig bewegt klappt es. Bitte einmal live jagen – wenn es zäh ist, stelle ich die Tempos in `Config.Spirits` ein.
- **Kartenfenster ansehen:** Klicks liefen bei verdecktem Fenster ins Timeout, daher ist das gezeichnete Kartenfenster noch nicht auf einem Bild geprüft.
- **Tycoon-Optik:** Bauteile nur per Abfrage geprüft, Screenshots liefen ins Timeout (Studio-Fenster nicht sichtbar). Sieht sich in Block 3 an.
- **Relikt-Modelle aus Blender:** Selbst hochladen ging nicht (`AssetService:CreateAssetAsync` ist in Studio gesperrt; EditableMesh im Live-Spiel bräuchte deine Ausweis-Verifizierung und einen Sicherheitsschalter). Upload über *Import 3D* nach `assets/relics/README.md`.
- **Bildrate auf schwachem Handy** mit der neuen Deko.
- **Zeitlimit 8 min** nicht abgewartet (Logik geprüft, nicht ausgelöst).
- **Glitzern bei seltenen Funden** im Spiel gesehen: Code-Pfad identisch zum Ausbau-Effekt, ein seltener Fund kam im Test nicht vor (wird mit der Expedition geprüft).
- **Klang selbst anhören:** Ich kann Sounds nur technisch prüfen (lädt, spielt, Tonhöhe). Ob dir Auswahl und Lautstärken gefallen, hörst nur du. Austausch = eine Zeile in `Shared/Sounds.luau`.
- **3D-Vorschau in den Karten:** In den letzten Bildern war die ganze 3D-Ansicht schwarz, auch ohne offenes Fenster. Das liegt offenbar am Rendern von Studio, nicht am Spiel. Bitte einmal selbst ansehen.
