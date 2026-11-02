# Release-Checkliste

Nichts davon wird ohne ausdrückliche Freigabe veröffentlicht.

## Voraussetzungen (Roblox-Konto / Experience)
- [ ] Place als **private** Experience veröffentlicht (für DataStore-Tests)
- [ ] Game Settings → Security: Studio-Zugriff auf API-Dienste aktiviert (nur für Tests)
- [ ] Max. Spieler pro Server = 8
- [ ] Experience-Fragebogen / Altersfreigabe (Maturity) ausgefüllt
- [ ] Spielname, Beschreibung, Genre gesetzt
- [ ] Spielicon (512×512) und Thumbnails erstellt und hochgeladen
- [ ] Prüfen: aktuelle Roblox-Veröffentlichungsrichtlinien und Monetarisierungsregeln

## Gameplay
- [x] Kernschleife Sammeln → Ausstellen → Münzen (M1)
- [ ] Schatzkammer-Upgrades (M2)
- [ ] Tutorial Lumi, überspringbar (M2)
- [ ] 25 Relikte im Spiel erreichbar (M3)
- [ ] Quests (M3)
- [ ] Expedition oder bewusst auf späteres Update verschoben (M4)

## Technik und Sicherheit
- [x] Alle Remotes serverseitig validiert, Rate-Limits
- [x] Duplikationsschutz bei Ausstellen/Tauschen nachgewiesen
- [ ] Speichern/Rejoin in veröffentlichtem Place nachgewiesen
- [ ] Session-Lock mit zwei Servern geprüft
- [ ] BindToClose-Speichern bei Serverabschaltung geprüft
- [ ] 8-Spieler-Test (Studio Local Server)
- [ ] Studio-Testhook `DevInspect` nur in Studio aktiv (geprüft per Code, live verifizieren)
- [ ] Kaufabwicklung (ProcessReceipt) idempotent getestet (M5)

## Mobile und Performance
- [ ] UI auf kleinen Smartphones (Studio-Emulation + echtes Gerät)
- [ ] Touch-Einsammeln und Prompts auf Gerät
- [ ] Bildrate auf schwachem Gerät akzeptabel
- [ ] Partikel und Lichter begrenzt

## Monetarisierung (M5)
- [ ] Produkte, Preise und IDs von dir bestätigt
- [ ] Keine bezahlten Zufallsboxen, keine Countdowns, keine Kaufpflicht
- [ ] PolicyService-Prüfung für regionale Einschränkungen

## Abschluss
- [ ] Releasekandidat auf `main` gemergt und getaggt
- [ ] Ausdrückliche Freigabe für die öffentliche Veröffentlichung
