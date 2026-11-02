# Shop einrichten: Pässe und Developer Products

Diese Artikel legst **du** im Creator Dashboard an. Sie hängen an deinem Roblox-Konto, deshalb kann ich sie nicht anlegen. Danach schickst du mir die IDs, ich trage sie in `src/ReplicatedStorage/Shared/Config.luau` (`Config.Shop`) ein, und der Shop schaltet die Artikel frei.

Die Bilder liegen in `assets/shop/` (512×512 PNG).

## 1. Game Passes (einmal kaufen, für immer)

Creator Dashboard: **create.roblox.com → Creations → RELIC RUSH: Treasure Hunters → Monetization → Passes → Create a Pass**

| Key (für mich) | Name | Beschreibung | Bild | Preisvorschlag |
|---|---|---|---|---|
| `wings` | Magische Flügel | Leuchtende Aether-Flügel auf deinem Rücken. Rein kosmetisch. | `wings.png` | 149 Robux |
| `aura` | Sternenaura | Funkelnde Sterne umkreisen deinen Charakter. Rein kosmetisch. | `aura.png` | 99 Robux |
| `vip` | VIP-Paket | Goldenes VIP-Namensschild und goldene Akzente in deiner Schatzkammer. | `vip.png` | 249 Robux |
| `double_coins` | Doppelte Münzen | Deine ausgestellten Relikte erzeugen dauerhaft doppelt so viele Münzen. | `double_coins.png` | 299 Robux |

Nach dem Anlegen den Pass öffnen → **Sales** → „Item for Sale“ einschalten → Preis eintragen → speichern.

## 2. Developer Products (mehrfach kaufbar)

**Monetization → Developer Products → Create a Developer Product**

| Key (für mich) | Name | Beschreibung | Bild | Preisvorschlag |
|---|---|---|---|---|
| `coins_small` | Münzbeutel | Ein Beutel Münzen passend zu deiner Ausbaustufe (500 / 3.000 / 12.000). | `coins_small.png` | 29 Robux |
| `coins_large` | Münzschatz | Ein großer Münzschatz passend zu deiner Ausbaustufe (2.500 / 15.000 / 60.000). | `coins_large.png` | 99 Robux |

## 3. IDs an mich

Die ID steht in der Adresszeile der Artikelseite oder im Menü „…“ → *Copy Asset ID*. Schick sie mir in diesem Format:

```
wings = 
aura = 
vip = 
double_coins = 
coins_small = 
coins_large = 
```

Du musst nicht alle auf einmal anlegen. Artikel ohne ID bleiben im Shop auf „Bald verfügbar“.

## Hinweise zu Preisen und Fairness
- Die Preise sind **Vorschläge**. Sie orientieren sich an üblichen Preisen für kosmetische Pässe in kleineren Sammel-Simulatoren. Belastbare Daten gibt es erst nach dem Launch (Analytics → Monetization).
- Roblox behält bei jedem Verkauf einen Anteil ein; du erhältst den Rest als Robux. Den Umtausch in Geld (DevEx) prüft Roblox mit eigenen Voraussetzungen.
- „Doppelte Münzen“ und die Münzpakete sind **Komfort-Käufe**: Sie beschleunigen den Fortschritt, sind aber nie nötig. Willst du nur Kosmetik verkaufen, lass diese drei einfach weg.
- Es gibt keine bezahlten Zufallsboxen und keine Countdowns. Der Shop sagt ausdrücklich, dass alles optional ist.
- Nach dem Eintragen mache ich einen Testkauf je Artikel nur mit deiner ausdrücklichen Zustimmung.
