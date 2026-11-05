# Launch-Material und Anleitung

Alle Dateien liegen in `assets/launch/`. Die neuen Bilder (Stand 0.4.0) zeigen das Herrenhaus, die
Wächter-Geister und die Schatzinsel; die Rohbilder liegen in `assets/launch/raw/`, neu erzeugen mit
`tools/marketing/compose-thumbnail.ps1`.

| Datei | Wofür | Format |
|---|---|---|
| `icon_v2.png` | Spielicon (Geister vor dem Aetherkristall, Schriftzug) | 512×512 |
| `thumb_en_1_manor.png` | Thumbnail 1 – „BUILD YOUR TREASURE MANOR!“ | 1920×1080 |
| `thumb_en_2_spirits.png` | Thumbnail 2 – „CATCH CUTE SPIRITS!“ | 1920×1080 |
| `thumb_en_3_isle.png` | Thumbnail 3 – „FIND THE TREASURE ISLE!“ | 1920×1080 |
| `thumb_de_1_herrenhaus.png` … `thumb_de_3_insel.png` | dieselben auf Deutsch (für die deutsche Lokalisierung der Thumbnails) | 1920×1080 |

Empfehlung: Die **englischen** Thumbnails als Standard hochladen (Roblox ist international), die
deutschen unter *Lokalisierung → Deutsch* als eigene Thumbnails hinterlegen. Die alten Bilder
(`icon.png`, `thumbnail_*.png`) zeigen die frühe Version und können ersetzt werden.

Tipps aus erfolgreichen Spielen: Thumbnail 1 ist das wichtigste (das sehen Spieler zuerst). Nach
1–2 Wochen lohnt sich ein Vergleich – Roblox bietet dafür *Thumbnail-Tests* (A/B) an.

## Wo du was einträgst

Creator Dashboard → **Unbenannte Experience** → **Konfigurationen** (*Configure*):

1. **Grundeinstellungen**
   - Name: `RELIC RUSH: Treasure Hunters` (Tipp: Ein kurzes Emoji davor wie `👻 RELIC RUSH` fällt in der Liste mehr auf)
   - Beschreibung: Text unten (Deutsch). Unter *Lokalisierung* kannst du die englische Fassung zusätzlich hinterlegen.
   - Genre: **Simulation** (falls Untergenres angeboten werden: Sammeln / Tycoon)
   - Geräte: Computer, Smartphone, Tablet (Konsole erst nach einem Gamepad-Test)
2. **Icon:** `icon_v2.png` hochladen.
3. **Thumbnails:** `thumb_en_1_manor.png`, `thumb_en_2_spirits.png`, `thumb_en_3_isle.png` in dieser Reihenfolge hochladen, dann *Speichern*. Roblox prüft Bilder vor der Anzeige, das kann etwas dauern.
4. **Orte → Start-Place → Server-Füllung / Max. Spieler:** `8`
5. **Fragebogen zur Altersfreigabe** (*Maturity & Compliance*). Beantworte ihn ehrlich. Was im Spiel steckt:
   - keine Gewalt, kein Blut, keine Waffen, keine Angstszenen
   - keine romantischen Inhalte, kein derber Humor
   - keine bezahlten Zufallsgegenstände; alle Robux-Käufe sind feste Artikel
   - Roblox-Chat ist an (Standard), sonst kein freier Nutzertext
   - Käufe: 4 Game Passes (ein fünfter, „Auto-Truhe“, ist vorbereitet) und 2 Developer Products
6. **Zugriff** (*Privacy*): erst auf **Öffentlich**, wenn die Release-Checkliste abgehakt ist.

## Abzeichen (Badges) anlegen

Abzeichen erscheinen auf der Spielseite und motivieren zum Weiterspielen. Im Creator Dashboard unter
*Abzeichen* anlegen (Bild: z. B. ein Ausschnitt aus den Thumbnails), dann die ID in
`src/ReplicatedStorage/Shared/Config.luau` bei `Config.Badges` eintragen (oder mir schicken):

| Schlüssel | Name | Wofür |
|---|---|---|
| welcome | Willkommen in Aetheria | einmal beigetreten |
| firstSpirit | Geisterjäger | ersten Geist gefangen |
| firstRelic | Erste Ausstellung | erstes Relikt ausgestellt |
| collector10 | Sammler | 10 Relikte entdeckt |
| collectorAll | Meistersammler | alle Relikte entdeckt |
| legendary | Legende | legendäres Relikt gefunden |
| manor | Hausherr | Eingangshalle gebaut |
| vault | Schatzgewölbe | Gewölbe gebaut |
| isle | Inselentdecker | erste Reise zur Schatzinsel |
| treasure | Schatzgräber | ersten Schatz ausgegraben |
| expedition | Ruinenforscher | Expedition geschafft |

Ein ID-Wert 0 heißt „noch nicht angelegt“ – das Spiel überspringt das Abzeichen dann einfach.

## Spielpass „Auto-Truhe“

Im Dashboard einen Pass „Auto-Truhe“ anlegen (Vorschlag 149–199 Robux), die ID in `Config.Shop.passes`
bei `auto_chest` eintragen. Bis dahin steht er im Shop als „Bald verfügbar“.

## Beschreibung (Deutsch, < 1000 Zeichen)

```
✨ Willkommen in Aetheria – der schwebenden Insel der Reliktjäger! ✨

Fang süße Wächter-Geister, sammle magische Relikte und stelle sie in deinem eigenen Herrenhaus aus. Jedes Relikt verdient Münzen – damit baust du dein Haus Raum für Raum aus!

👻 Jage Wächter-Geister – seltene sind flink und trickreich
🏰 Baue dein Herrenhaus: Eingangshalle, Bibliothek, Kartenraum, Türme
💎 Reliktsaal, Schatzkeller und Schatzgewölbe für 20 Relikte
🗺️ Sammle Kartenteile und reise zur geheimen Schatzinsel
⚔️ Expedition in die Vergessenen Ruinen – allein oder mit Freunden
📅 Tagesbonus, Spielzeit-Geschenke und neue Aufgaben jeden Tag
🏆 Kletter in der Bestenliste „Größte Sammlung“ nach oben

Lumi, dein kleiner Lichtgeist, zeigt dir die ersten Schritte – in unter einer Minute fängst du deinen ersten Geist!

Kostenlos spielbar. Alle Shop-Artikel sind optional.
```

## Description (English)

```
✨ Welcome to Aetheria – the floating island of relic hunters! ✨

Catch cute guardian spirits, collect magical relics and show them off in your very own manor. Every relic earns coins – use them to build your house room by room!

👻 Hunt guardian spirits – rare ones are fast and tricky
🏰 Build your manor: entrance hall, library, map room, towers
💎 Relic hall, treasure cellar and vault for 20 relics
🗺️ Collect map pieces and travel to the secret Treasure Isle
⚔️ Explore the Forgotten Ruins – solo or with friends
📅 Daily bonus, playtime gifts and new quests every day
🏆 Climb the "Biggest Collection" leaderboard

Lumi, your little light spirit, shows you the ropes – you'll catch your first spirit in under a minute!

Free to play. All shop items are optional.
```

Das Spiel selbst gibt es jetzt komplett auf Deutsch und Englisch (automatisch nach Spielersprache).

## Nach dem Launch: was du beobachten solltest

Creator Dashboard → **Analytics**:
- **Onboarding-Funnel** (eigene Schritte: Joined → FirstRelic → FirstDisplay → FirstUpgrade → ForestVisited → TutorialDone). Hier siehst du, an welchem Schritt neue Spieler abspringen.
- **Retention D1 / D7** und **Sitzungsdauer** zeigen, ob Spieler wiederkommen.
- **Economy** (Münzquellen und -ausgaben): ob Ausbau und Glücksrune zu teuer oder zu billig sind.
- **Monetization**: Kaufquote pro Artikel.

Erst mit echten Daten lohnt es sich, Preise oder Balance zu ändern.
