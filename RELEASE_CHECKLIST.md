# Release-Checkliste

Nichts davon wird ohne deine ausdrückliche Freigabe öffentlich geschaltet.

## Was du im Roblox Creator Dashboard / Studio erledigen musst
- [x] Place als **private** Experience veröffentlicht (GameId 10774417779)
- [x] Studio-Zugriff auf API-Dienste
- [ ] Max. Spieler pro Server = 8
- [x] 4 Pässe angelegt und eingetragen
- [x] 2 Developer Products angelegt und eingetragen
- [ ] Zwei versehentlich als Pass angelegte Münzpakete nicht zum Verkauf anbieten
- [ ] Experience umbenennen in „RELIC RUSH: Treasure Hunters“
- [ ] Fragebogen zur Altersfreigabe (Maturity & Compliance) ausfüllen
- [ ] Spielname, Beschreibung, Genre, Geräte (Computer, Phone, Tablet) setzen
- [ ] Spielicon (512×512) und Thumbnails (1920×1080) hochladen – Entwürfe liefere ich
- [ ] Öffentlich schalten (*Privacy → Public*) – erst nach allen Punkten unten

## Gameplay
- [x] Kernschleife Sammeln → Ausstellen → Münzen
- [x] Schatzkammer-Stufen 2/3
- [x] Tutorial Lumi, überspringbar
- [x] Tägliche Aufgaben, Sammelbuch, Meilensteine
- [x] Wiederholbare Münz-Ausgabe (Glücksrune)
- [ ] Alle 25 Relikte erreichbar – aktuell 18; der Rest kommt mit der Expedition (Update)
- [ ] Musik und mehr Soundeffekte

## Technik und Sicherheit
- [x] Alle Remotes serverseitig validiert, Rate-Limits
- [x] Duplikationsschutz bei Ausstellen/Tauschen nachgewiesen
- [x] Kaufabwicklung idempotent (simuliert)
- [x] Speicher-Fallback bei DataStore-Fehlern in Studio
- [x] Speichern/Rejoin in veröffentlichtem Place nachgewiesen
- [x] Session-Lock (frisch → abgewiesen, veraltet → übernommen) geprüft
- [ ] 8-Spieler-Test (Studio *Test → Clients and Servers*)
- [x] Studio-Testhook `DevTools` nur in Studio aktiv (Code-Prüfung `RunService:IsStudio()`)
- [ ] Ein echter Testkauf je Artikel mit deinem Konto (erst nach deiner Zustimmung)

## Mobile und Performance
- [x] UI skaliert (UIScale 0,62–1,15), große Touch-Flächen, Safe-Area
- [ ] UI auf kleinem Smartphone (Studio-Geräteemulation + echtes Gerät)
- [ ] Bildrate auf schwachem Gerät akzeptabel

## Monetarisierung
- [x] Keine bezahlten Zufallsboxen, keine Countdowns, keine Kaufpflicht
- [x] Shop mit Hinweis „Alles optional“
- [ ] Preise und Artikel von dir bestätigt
- [ ] „Doppelte Münzen“ und Münzpakete bewusst freigegeben (Komfort-Käufe, nicht nur Kosmetik)

## Abschluss
- [ ] Releasekandidat auf `main` gemergt und getaggt
- [ ] Deine ausdrückliche Freigabe für die öffentliche Veröffentlichung
