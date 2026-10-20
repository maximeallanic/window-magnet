# Window Magnet

[![CI](https://github.com/maximeallanic/window-magnet/actions/workflows/ci.yml/badge.svg)](https://github.com/maximeallanic/window-magnet/actions/workflows/ci.yml)
[![Licence : MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)
[![GNOME Shell 51](https://img.shields.io/badge/GNOME%20Shell-51-4a86cf.svg)](#compatibilité)

[English](README.md) | Français

**Des bords de fenêtres qui s'aimantent, avec un ressort.** Approchez une fenêtre d'une autre, ou du côté de
l'écran, et elle vient se coller contre ce bord ; continuez à tirer et elle se décroche. Une extension GNOME Shell pour
celles et ceux qui rangent leurs fenêtres à la main et veulent qu'elles s'alignent.

![Une fenêtre glissée à côté de deux autres : son bord droit s'aimante à leur bord gauche, son haut s'aligne sur celui
de la première, puis elle est décrochée, aimantée au bord gauche de l'écran et redimensionnée jusqu'à s'aimanter de
nouveau](media/demo.gif)

*Enregistré dans GNOME Shell 51 (imbriqué, sans écran) à vitesse réelle. [Version MP4](media/demo.mp4).*

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/install.sh | bash
```

**GNOME Shell 51 uniquement.** Sous Wayland, déconnectez-vous puis reconnectez-vous une fois après la première
installation. Cette commande télécharge la version 0.1.0 depuis GitHub : tant qu'elle n'est pas publiée, la commande
s'arrête sur une erreur de téléchargement ; [installez depuis les sources](#depuis-les-sources) en attendant. Pas
encore sur extensions.gnome.org.

## Pourquoi celle-ci

GNOME aimantait autrefois une fenêtre déplacée aux bords des autres. Depuis GNOME 40, il ne le fait plus que si l'on
maintient **Ctrl** (notes de version de Mutter : « Only snap to window edges when CTRL is pressed »). Le changement a
suivi des signalements de glissers qui semblaient saccadés, parce que chaque bord proche attrapait la fenêtre
([bogue Ubuntu 1727225](https://bugs.launchpad.net/ubuntu/+source/gnome-shell/+bug/1727225)). Window Magnet rétablit
l'aimantation entre fenêtres sans touche à maintenir, et change ce qui la rendait désagréable :

- **Aimantation sur ressort** : la position réelle de la fenêtre s'aimante tout de suite ; ce que vous voyez y glisse
  sur un ressort court, si bien qu'une aimantation se lit comme une attraction et non comme une saccade. Il suit le
  réglage *Réduire les animations* de GNOME.
- **Tient, puis lâche** : une fenêtre aimantée reste en place tant que le pointeur ne s'éloigne pas de plus que la
  distance d'aimantation (16 px par défaut, de 4 à 64), puis elle suit de nouveau exactement le pointeur.
- **Seulement les bords qui se font face** : une autre fenêtre n'attire un bord vertical que si les deux se
  chevauchent verticalement, et inversement : une fenêtre loin au-dessus n'attrape pas la vôtre.
- **Le redimensionnement s'aimante aussi, sans clignotement** : le bord que vous tirez s'aimante dans la même image que
  le redimensionnement de GNOME : l'application n'affiche jamais deux tailles à la suite.
- **Un interrupteur par source** : coupez l'aimantation aux autres fenêtres, aux bords de l'écran ou pendant le
  redimensionnement, ou seulement le ressort.

Elle règle aussi une chose que GNOME ne gère pas sous Wayland : **un onglet sorti d'une fenêtre et déposé sur le
bureau s'ouvre là où vous l'avez déposé**, à la taille de la fenêtre d'origine, dans toute application dont les
onglets peuvent être sortis.

Rien d'autre ne change : pas de pavage, pas de raccourci clavier, pas de changement de style. Elle n'agit que pendant
un glisser.

## Comparaison

D'après la documentation ou le code de chaque projet, vérifiés le 2026-10-20. Un tiret signifie que la source ne dit
rien.

| | S'aimante aux autres fenêtres | S'aimante aux bords de l'écran | Animation | Autre chose |
|---|---|---|---|---|
| **Window Magnet** (GNOME 51) | oui, sans touche à maintenir | oui, aussi en redimensionnant | ressort | place les onglets déposés |
| GNOME 51 sans extension | seulement en maintenant Ctrl | résiste aux bords de l'écran et des moniteurs ; Maj fait s'aimanter | aucune | glisser en haut ou sur un côté pour paver |
| [Tiling Assistant](https://extensions.gnome.org/extension/3733/tiling-assistant/), [Tiling Shell](https://extensions.gnome.org/extension/7065/tiling-shell/) | non : elles remplissent des zones et des dispositions | zones | — | pavage, assistant d'aimantation, dispositions |
| KDE Plasma (KWin) | oui, « window snap zone » | oui, « screen edge snap zone » | — | intégré au bureau |
| Xfce (xfwm4) | oui, « Snap windows to other windows » | oui | — | intégré au bureau |
| Windows Snap, [AquaSnap](https://www.nurgo-software.com/products/aquasnap) | Snap : non, il remplit des zones de l'écran. AquaMagnet d'AquaSnap : oui | oui | — | AquaSnap est une application à part |
| macOS [Magnet](https://magnet.crowdcafe.com/), [Rectangle](https://github.com/rxhanson/Rectangle) | absent de leur documentation | glisser vers un bord ou un coin remplit une zone | — | raccourcis clavier |

Window Magnet et les extensions de pavage n'ont pas été testées ensemble : deux extensions qui déplacent la même
fenêtre pendant un glisser peuvent se contrarier.

## Installation

### En une commande

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/install.sh | bash
```

Le script télécharge depuis GitHub le zip de la version épinglée (0.1.0), vérifie son SHA-256 contre la valeur écrite
dans `install.sh`, l'installe pour votre utilisateur avec `gnome-extensions install` et l'active. Ni root, ni outils
de compilation. Sous Wayland, **déconnectez-vous puis reconnectez-vous une fois** après la première installation :
GNOME Shell découvre les nouvelles extensions à l'ouverture de session. Le script est court et commenté ; lisez-le
d'abord si vous préférez. Il fonctionne une fois la version 0.1.0 publiée sur GitHub.

### Depuis les sources

```sh
git clone https://github.com/maximeallanic/window-magnet.git
cd window-magnet
./install.sh --from-source       # demande gettext (msgfmt) pour compiler les traductions
```

### À la main, depuis le zip

1. Téléchargez `window-magnet@maximeallanic.github.io.shell-extension.zip` depuis la
   [dernière version](https://github.com/maximeallanic/window-magnet/releases/latest)
   (et `SHA256SUMS` pour le vérifier : `sha256sum -c SHA256SUMS`).
2. Installez-le : `gnome-extensions install --force window-magnet@maximeallanic.github.io.shell-extension.zip`
3. Déconnectez-vous et reconnectez-vous, puis : `gnome-extensions enable window-magnet@maximeallanic.github.io`

### Depuis extensions.gnome.org

Pas encore publiée. Une fois qu'elle le sera, vous pourrez l'installer depuis le site ou l'application
*Gestionnaire d'extensions*.

### Vérifier que tout marche

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/verify.sh | bash
```

`verify.sh` ne modifie rien. Il contrôle la version de GNOME Shell, l'installation, le schéma de réglages, l'activation
et le fonctionnement de l'extension, et dit quoi faire pour tout ce qui ne va pas (messages en anglais).

### Désinstaller

```sh
curl -fsSL https://raw.githubusercontent.com/maximeallanic/window-magnet/main/uninstall.sh | bash
# ou, depuis un clone : ./uninstall.sh [--purge]
```

L'extension est désactivée (aucune fenêtre ne reste décalée), supprimée et retirée de la liste des extensions
activées. `--purge` remet aussi ses réglages à zéro. Le bouton *Supprimer* de l'application Extensions fait de même,
sauf pour les réglages.

## Réglages

Dans l'application Extensions (*Window Magnet*, bouton engrenage) ou avec
`gnome-extensions prefs window-magnet@maximeallanic.github.io`.

![Fenêtre de préférences : distance d'aimantation, aimanter aux autres fenêtres, aimanter aux bords de l'écran,
aimanter pendant le redimensionnement, animation à ressort, ouvrir les onglets déposés là où ils sont
déposés](media/prefs-fr.png)

| Réglage | Clé | Par défaut |
|---------|-----|------------|
| Distance d'aimantation : à partir de quelle distance un bord s'aimante, de 4 à 64 px | `snap-threshold` | `16` |
| Aimanter aux autres fenêtres | `snap-to-windows` | activé |
| Aimanter aux bords de l'écran | `snap-to-screen-edges` | activé |
| Aimanter pendant le redimensionnement | `snap-while-resizing` | activé |
| Animation à ressort | `spring-animation` | activé |
| Ouvrir les onglets déposés là où ils sont déposés | `place-dropped-tabs` | activé |

Depuis un terminal (le schéma est livré avec l'extension, d'où `--schemadir`) :

```sh
gsettings --schemadir ~/.local/share/gnome-shell/extensions/window-magnet@maximeallanic.github.io/schemas \
    set org.gnome.shell.extensions.window-magnet snap-threshold 24
```

## Compatibilité

| GNOME Shell | État |
|-------------|------|
| 51 | Pris en charge, testé (Debian testing, Wayland) |
| 50 et avant | Non déclaré : GNOME refuse de la charger |

- **Version 0.1.0, première publication** : couverte par des tests unitaires et par un test de bout en bout dans un
  GNOME Shell 51 imbriqué qui fait glisser de vraies fenêtres ; pas encore essayée sur beaucoup de machines. Les
  autres distributions en GNOME Shell 51 devraient fonctionner, et les retours sont bienvenus.
- **Pas encore sur extensions.gnome.org** ([liste de contrôle](docs/extensions-gnome-org.md), en anglais).
- **Glissers au pointeur et au toucher seulement** : les déplacements au clavier (Alt+F7) ne s'aimantent pas.
- **Traductions** : anglais et français pour l'instant. Les préférences suivent la langue du bureau via gettext ;
  ajouter une langue tient en un fichier `.po` ([CONTRIBUTING.md](CONTRIBUTING.md)).
- Window Magnet n'utilise que des API publiques de GNOME Shell et de Mutter. Une version plus récente de Shell est
  ajoutée à la liste une fois testée.

## Questions fréquentes

**GNOME n'a-t-il pas retiré l'aimantation exprès ?** Il l'a rendue facultative avec Ctrl, parce que s'aimanter à
chaque bord proche rendait les glissers saccadés. Window Magnet anime l'aimantation au lieu de sauter, et n'attire que
les bords qui se font face. Si vous préférez le comportement de GNOME, coupez *Aimanter aux autres fenêtres* et gardez
les bords de l'écran, ou désactivez l'extension.

**Est-ce une extension de pavage ?** Non. Elle ne choisit jamais une taille ni une place à votre place ; elle termine
l'alignement que vous avez commencé. Le pavage par les bords de GNOME (glisser en haut pour maximiser, sur un côté
pour la moitié d'écran) reste tel quel.

**Je l'ai installée mais rien ne se passe.** Sous Wayland, déconnectez-vous et reconnectez-vous une fois après
l'installation. Puis lancez `verify.sh` (ci-dessus) : il dit ce qui manque.

**La fenêtre s'aimante mais sans ressort.** Le ressort suit le réglage d'animation de GNOME : Paramètres,
Accessibilité, Vision, *Réduire les animations* doit être désactivé. Vérifiez aussi l'interrupteur *Animation à
ressort*.

**Peut-on déplacer une fenêtre sans aimantation ?** Éloignez-la de plus que la distance d'aimantation : elle suit
alors exactement le pointeur. Une distance plus petite rend l'aimantation plus rare ; *Aimanter aux autres fenêtres*
et *Aimanter aux bords de l'écran* coupent chaque source.

**Et avec les extensions de pavage ?** Non testé. D'autres extensions qui déplacent aussi les fenêtres pendant un
glisser peuvent entrer en conflit ; signalez-le.

**Plusieurs écrans ?** L'aimantation utilise les fenêtres et la zone utile de l'écran où se trouve la fenêtre.

**Avec quels onglets marche le dépôt sur le bureau ?** Toute application dont les onglets peuvent être sortis dans une
nouvelle fenêtre sous Wayland (les barres d'onglets libadwaita, par exemple). Rien n'est propre à une application :
l'extension reconnaît le glisser affiché par Mutter et la fenêtre que la même application crée juste après. Un onglet
déposé dans une autre fenêtre ne déplace rien.

**Collecte-t-elle quelque chose, parle-t-elle au réseau ?** Non. Elle ne lance aucun processus, n'ouvre aucune
connexion et ne lit aucun fichier.

**A-t-elle un lien avec Magnet pour macOS ?** Non. Window Magnet est un projet GNOME indépendant, sans lien avec les
éditeurs de Magnet, Rectangle, AquaSnap ou des autres outils cités sur cette page.

## Fonctionnement

Voir [docs/how-it-works.md](docs/how-it-works.md) (en anglais). Développement, tests et régénération des médias :
[docs/development.md](docs/development.md).

## Essayez-la et dites-nous

Vous êtes sous GNOME Shell 51 ? Installez-la, déplacez quelques fenêtres, et
[ouvrez un ticket](https://github.com/maximeallanic/window-magnet/issues) avec ce qui vous a plu et ce qui coince :
votre distribution, vos applications et vos écrans sont ce que les tests ne couvrent pas. Les traductions sont
bienvenues aussi. Lisez [CONTRIBUTING.md](CONTRIBUTING.md) et le [code de conduite](CODE_OF_CONDUCT.md). Failles de
sécurité : [SECURITY.md](SECURITY.md).

## Crédits et licence

MIT, voir [LICENSE](LICENSE). Le ressort vient de la boîte à outils de mouvement de
[m3e-gnome-extensions](https://github.com/maximeallanic/m3e-gnome-extensions) (MIT, copiée sans modification), dont le
solveur de ressort est un portage de celui de Jetpack Compose (Apache-2.0). Détails dans [NOTICE.md](NOTICE.md). Les
noms de produits de la comparaison appartiennent à leurs propriétaires et ne servent qu'à les décrire.
