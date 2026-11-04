# Changelog

## 0.4.0 – Sound, Spielgefühl und Expedition (in Arbeit)
- Expedition „Vergessene Ruinen“ für 1–4 Spieler: Druckplatten, Spiegelsaal mit Irrlicht, Rätselsteine, Kristallwächter, gemeinsame Truhe. Alle 25 Relikte sind jetzt erreichbar.
- Abklingzeit 10 min pro Spieler, Begleiter bekommen Münzen. Datenschema v4.
- Die Schatzkammer ist ein Haus, das mit den Podesten wächst: Start im Relikt-Raum (Podeste 1–4), dann Westzimmer (5–6), Ostzimmer (7–8), Große Halle (9–12) und Galerie-Empore als Obergeschoss mit zwei Treppen (13–16). Dazu Buntglasfenster, Ecktürme, Glaskuppel, Brunnen, Statuen, Vitrinen, Kronleuchter und Krone. Bau-Tasten stehen im Vorhof, Dächer blenden sich aus, solange man drinnen steht. Datenschema v9 gibt bestehenden Spielern die Räume zu ihren Podesten.
- Schatzkarten führen jetzt zur **Schatzinsel**: 3 Kartenteile = eine Karte = ein Besuch von 4 Minuten (Reise über das Kartenfenster). Auf der Insel liegen pro Besuch 9 Schätze: 5 leichte im Freien (Lichtstrahl), 3 versteckte hinter Felsen, Ruinen und Büschen, 1 geheimer (hinter dem Wasserfall, auf dem Adlerfels, im hohlen Baum oder im Schiffswrack). Je versteckter, desto seltener das Relikt (bis Legendär). Dazu Insel-Geister: leichte, flinke mit Sprint und ein Meister-Geist, der wegspringt – alle bleiben fangbar. Datenschema v10.
- Schatzinsel aufgewertet: Sandwege zu allen Sehenswürdigkeiten, Tiki-Fackeln, doppelt so viele Palmen, Gras, Farne, Blumen, Felsen, Muscheln und Seesterne am Strand, Treibholz, ein Schatzsucher-Lager mit Lagerfeuer und Zelt, ein Holzsteg über den Inselrand und Schmetterlinge.
- Reliktnamen über den Podesten sind kleiner und nur aus der Nähe sichtbar, damit sie sich im Saal nicht überlagern.
- Neues Aussehen der Wächter-Geister: runde Pastell-Geister mit Gesicht, Wangen, Ärmchen und wehendem Schweif, Leuchtrand in Seltenheitsfarbe; Augen zeigen den Zustand (ruhig, erschrocken, müde).
- Welt-Optik: Wasserfälle am Inselrand, Randfelsen, Wiesen mit Gras, Blumen, Büschen und Blütenbäumen, Weglaternen, Hecken um die Schatzkammern, dichterer Flüsterwald mit Glühwürmchen, eigener Ruinenhof mit Fackeln, Kristalle und Ranken unter der Insel, schwebende Lichtpunkte am Kristallplatz.
- Relikt-Modelle aus Blender vorbereitet (werden automatisch genutzt, sobald sie hochgeladen sind).
- Englische Fassung aller Spieltexte, automatisch nach Spielersprache.
- Wochenziel mit Münzen und Kartenteil (Schema v7) und Bestenliste „Größte Sammlung“ am Kristallplatz.
- Kartenteile: Geister verlieren manchmal ein Teil, neuer Knopf „Karte“. Datenschema v6.
- Wächter-Geister ersetzen die Lichtsäulen: Relikte fliehen, ermüden und werden durch Hineinlaufen gefangen (serverseitig simuliert, AFK-sicher).
- Tycoon-Ausbau: Bauteile an Kauftasten statt drei Ausbaustufen, Einkommens-Boni bis ×1,85. Datenschema v5 übernimmt bisherige Stufen.
- Musik pro Gebiet (Kristallplatz, Flüsterwald, Schatzkammer, Ruinen) mit sanfter Überblendung.
- Soundeffekte für Einsammeln (nach Seltenheit gestaffelt), Buttons, Fenster, Ausstellen, Ausbau, Abholen, Kauf, Fehler und Besuche. Nur lizenzierte Roblox-Audiobibliothek.
- „+X“-Münzzahlen über ausgestellten Relikten, Funkenregen beim Ausbau, Glitzern bei seltenen Funden, kurzer Kamera-Kick.
- Einstellungen (Zahnrad): Lautstärke Musik/Effekte, Lumi-Hinweise an/aus, Credits. Gespeichert im Profil.
- Datenschema v3 mit Migration.
- Behoben: Der alte Einsammel-Sound (`rbxasset://sounds/electronicpingshort.wav`) existiert im Live-Client nicht und war dort stumm.

## 0.3.0 – UI-Überarbeitung (2026-11-03)
- Einheitlicher Stil: warme Karten, violette Kopfleisten, Gold für Münzen, weiche Schatten, Farbverläufe.
- Icons auf allen Navigations-Buttons, Seitenmenü als große quadratische Kacheln, Hinweis-Badge „!“.
- Druck-Animation auf allen Buttons, Fenster öffnen mit kurzer Pop-Animation, Meldungen ploppen auf.
- Münzanzeige mit gezeichneter Münze, Raten-Chip und Glücksrunen-Timer.
- Relikt-Karten mit Seltenheits-Farbverlauf, Anzahl-Chip und Seltenheits-Badge; Aufgaben mit Icon, Balken und Belohnung; Shop-Karten mit Icon-Banner und Robux-Symbol.
- Solange ein Fenster offen ist, werden Navigation und Lumi-Hinweis ausgeblendet (Platz auf kleinen Handys).
- Ausgestellte Relikte 1,6× größer und auf dem Podest statt darüber, Relikt-Lichter sanfter.
- Behoben: Farbverlauf färbte die Schrift von Pill-Buttons ein (Text unsichtbar), „✕“ wurde in der Schrift nicht angezeigt.
- Launch-Material: Spielicon, 3 Thumbnails, Store-Texte DE/EN.

## 0.2.0 – Sammel-MVP, Langzeitziele, Shop-Architektur (2026-11-02)
- Schatzkammer-Stufen 2 und 3 am Ausbau-Stein, Geister-Podeste, Deko pro Stufe.
- Tutorial-Geist Lumi mit Lichtstrahl-Führung, Abschluss und Überspringen gespeichert.
- Sammelbuch mit allen 25 Relikten und Meilenstein-Belohnungen.
- Tägliche Aufgaben (3 pro Tag) inklusive Besuch fremder Schatzkammern mit Benachrichtigung an den Besitzer.
- Glücksrune als wiederholbare Münz-Ausgabe.
- Offline-Einnahmen (25 %, max. 2 h).
- Shop: Glücksrune, Pässe (Flügel, Aura, VIP, Doppelte Münzen), Münzprodukte; idempotente Kaufabwicklung. Artikel-IDs stehen noch aus.
- Roblox-Analytics: Onboarding-Funnel, Münzflüsse, UI-Ereignisse.
- Datenschema v2 mit Migration.
- Behoben: AFK-Farmen, Streaming-Warnung, Fehlercode bei Unplace, Taps auf 3D-Vorschauen, Chat und Spielerliste über Fenstern, überstrahlter Platz.
- Place als private Experience veröffentlicht.

## 0.1.0 – M1 Kernschleife (2026-11-02)
- Insel Aetheria: Kristallplatz, 8 Schatzkammern, Wege, Flüsterwald-Vorschau, versiegeltes Ruinenportal, Lichtstimmung.
- Datengetriebener Katalog mit 25 Relikten und prozeduralen Low-Poly-Modellen.
- Persönliche Relikt-Spawns mit garantiertem Start-Relikt; Einsammeln per Prompt oder Hineinlaufen.
- Inventar und Sammlungsfenster mit 3D-Vorschau.
- Grundstückszuweisung und -freigabe, Besitzerschild.
- Ausstellen, Tauschen und Zurücklegen auf Podesten; Münzproduktion pro Sekunde.
- HUD für Desktop und Touch: Münzen, Zielhinweis, Navigation, Toasts.
- Speicherschicht mit Session-Lock, Retries, Autosave, Migrationen; Speicher-Fallback für unveröffentlichte Places.
- Serverseitige Validierung aller Remotes und Rate-Limits.
- Werkzeuge: Weltgenerator, Sync-Check Repo ↔ Studio.

## 0.0.0 – M0 Baseline (2026-11-02)
- Ausgangszustand gesichert, Git eingerichtet, Blender-Prototyp `assets/AetherRelic.glb`.
