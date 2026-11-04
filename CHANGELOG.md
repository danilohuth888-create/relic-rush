# Changelog

## 0.4.0 – Sound, Spielgefühl und Expedition (in Arbeit)
- Expedition „Vergessene Ruinen“ für 1–4 Spieler: Druckplatten, Spiegelsaal mit Irrlicht, Rätselsteine, Kristallwächter, gemeinsame Truhe. Alle 25 Relikte sind jetzt erreichbar.
- Abklingzeit 10 min pro Spieler, Begleiter bekommen Münzen. Datenschema v4.
- Tycoon-Ausbau: 22 Bauteile an Kauftasten statt drei Ausbaustufen, Einkommens-Boni bis ×1,75, Galerie mit Podesten 13–16. Datenschema v5 übernimmt bisherige Stufen.
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
