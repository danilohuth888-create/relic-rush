# RELIC RUSH: Treasure Hunters

Fantasy-Sammelspiel für Roblox. Spieler sammeln auf der schwebenden Insel **Aetheria** Relikte, stellen sie in ihrer eigenen Schatzkammer aus und verdienen damit Münzen. Mit den Münzen bauen sie die Schatzkammer aus.

Aktueller Stand und Tests: [STATUS.md](STATUS.md) · Bekannte Fehler: [BUGS.md](BUGS.md) · Änderungen: [CHANGELOG.md](CHANGELOG.md) · Release: [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)

## Quelle der Wahrheit

| Was | Quelle | Wie es nach Studio kommt |
|---|---|---|
| Spielcode (alle Skripte) | `src/` in diesem Repo | Per Roblox-Studio-MCP eingespielt; `tools/sync` prüft, dass Studio und Repo übereinstimmen |
| Weltgeometrie Aetheria | `tools/world/BuildAetheria.luau` | Skript in Studio ausführen (MCP oder Befehlsleiste); baut `Workspace.Aetheria` komplett neu |
| Sonderassets (Blender) | `assets/` | GLB über *Import 3D* in Studio |
| Ausgangszustand vor der Entwicklung | `backups/m0-studio-baseline.json`, Originalobjekte in `ServerStorage.M0_Backup` | – |

Regel: Code wird **zuerst im Repo** geändert und dann nach Studio übertragen, nie umgekehrt. Vor jedem Commit muss der Sync-Check grün sein.

### Sync prüfen

1. `tools/sync/StudioHashes.luau` in Studio ausführen (MCP `execute_luau` oder Befehlsleiste) und die JSON-Ausgabe als Datei speichern.
2. Vergleichen:

```bash
node tools/sync/manifest.mjs studio-hashes.json
```

Die Ausgabe `In sync: N scripts.` bedeutet, dass Studio exakt dem Repo entspricht.

Die Ordnerstruktur ist Rojo-kompatibel (`default.project.json`). Rojo ist aktuell nicht installiert; ein späterer Umstieg braucht keine Umstrukturierung.

## Architektur

Serverautoritativ: Der Client schickt nur Wünsche (Spawn-ID, Podest-Nummer, Relikt-ID). Besitz, Münzen und Reichweite prüft ausschließlich der Server.

```
src/
  ReplicatedStorage/Shared/        von Server und Client genutzt
    Config.luau                    alle Balancing-Werte (Stufen, Seltenheiten, Reichweiten)
    RelicDefs.luau                 datengetriebener Katalog der 25 Relikte
    RelicVisuals.luau              baut Low-Poly-Modelle aus dem Katalog (Welt, Podest, UI)
    Net.luau                       einzige Stelle, die Remotes benennt
  ServerScriptService/Server/
    Main.server.luau               startet Dienste, Spieler-Lebenszyklus, Studio-Testhook
    Services/
      PlayerDataService.luau       Profile, DataStore mit Session-Lock, Migrationen, Kaufbelege
      PlotService.luau             8 Grundstücke, Besitzer, Stufen, Deko, VIP-Look, Darstellung
      RelicSpawnService.luau       persönliche Relikt-Spawns, Einsammeln, Glücks-Würfe
      DisplayService.luau          Ausstellen / Tauschen / Zurücklegen
      EconomyService.luau          Münzproduktion, Gutschriften, Ausgaben, Offline-Einnahmen
      UpgradeService.luau          Schatzkammer-Ausbau, Glücksrune
      QuestService.luau            Tagesaufgaben, Sammelbuch-Meilensteine, Besuche, Tutorial-Abschluss
      ShopService.luau             Pässe, Developer Products (ProcessReceipt), Kosmetik
    Util/
      RateLimiter.luau             Token-Bucket pro Spieler und Remote
      Progress.luau                Ereignis-Bus „Spieler hat X getan“ (gegen zyklische requires)
      Analytics.luau               Roblox AnalyticsService (Funnel, Münzflüsse, Ereignisse)
  StarterPlayer/StarterPlayerScripts/Client/
    Main.client.luau               Client-Start
    ClientState.luau               lokale Kopie der Serverdaten (nur lesen)
    Controllers/
      HudController.luau           komplette UI im Code (Münzen, Lumi-Hinweis, Navigation,
                                   Sammelbuch, Podest-Auswahl, Aufgaben, Shop)
      RelicController.luau         Relikt-Pickups, Animationen, Einsammeln
      PlotController.luau          lokale Prompts am eigenen Grundstück (Podeste, Ausbau-Stein)
      LumiController.luau          Tutorial-Geist mit Lichtstrahl-Führung
tools/
  world/BuildAetheria.luau         Weltgenerator
  sync/                            Abgleich Repo ↔ Studio
assets/                            Blender-Exporte (GLB)
```

### Wichtige Designentscheidungen

- **Persönliche Relikt-Spawns.** Jeder Spieler hat an jedem Spawnpunkt sein eigenes Relikt. Niemand konkurriert ums erste Erfolgserlebnis, niemand kann anderen etwas wegschnappen. Der Server entscheidet, welches Relikt wo liegt.
- **Inventar als Zähler** (`relicId -> Anzahl`), Ausstellung als `Podest -> relicId`. Jede Verschiebung läuft ohne Yield. Die Summe aus Inventar und Ausstellung bleibt deshalb immer gleich, was gegen Duplikation schützt.
- **Datenspeicher:** UpdateAsync mit Session-Lock `{ job, t }`, Wiederholungen mit Backoff, Autosave alle 120 s und Speichern bei `BindToClose`. Kann ein Profil nicht geladen werden, wird der Spieler mit Hinweis gekickt, statt mit leeren Daten weiterzuspielen. In einem unveröffentlichten Place liegen die Daten nur im Speicher.
- **Neue Relikte** brauchen nur eine Zeile in `RelicDefs.luau`. Modell, UI-Karte, Spawn-Pools und Münzrate leiten sich daraus ab.
- **Teststeuerung:** Im Studio-Playtest stellt `ServerStorage.DevTools` (BindableFunction, nur bei `RunService:IsStudio()`) die Aktionen `inspect`, `grant`, `setPass`, `receipt` und `save` bereit. Clients können ihn nicht erreichen.
- **Shop-Artikel** stehen in `Config.Shop`. Bei `id = 0` zeigt der Shop „Bald verfügbar“, und es kann nichts gekauft werden. Die Preise kommen live aus dem Creator Dashboard.

## Nutzung (Entwicklung)

1. `E:\RELIC-RUSH` ist ein Git-Repo; gearbeitet wird auf dem Branch `dev`, `main` enthält nur freigegebene Stände.
2. Roblox Studio mit dem Place öffnen, Roblox-Studio-MCP verbinden.
3. Welt neu bauen (nur wenn nötig): Inhalt von `tools/world/BuildAetheria.luau` im Edit-Modus ausführen.
4. Skripte aus `src/` nach Studio übertragen und mit dem Sync-Check bestätigen.
5. Playtest mit **Play** in Studio.
