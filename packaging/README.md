# Paquets d'installation de TimeLog

Ce dossier fabrique les installeurs de TimeLog :

| Plateforme | Format | Fabrication | Résultat |
|---|---|---|---|
| Debian / Ubuntu | `.deb` | `build-linux.sh` (dpkg-deb) | `dist/timelog_<version>-1_amd64.deb` |
| Arch Linux | `.pkg.tar.zst` | `build-linux.sh` (makepkg) | `dist/timelog-<version>-1-x86_64.pkg.tar.zst` |
| Windows 64 bits | installeur `.exe` (NSIS) | `windows\build-windows.ps1` | `dist/timelog-<version>-setup-x64.exe` |

La version est lue automatiquement dans `app/pubspec.yaml`. Tout ce qui est généré va dans
`packaging/build/` et `packaging/dist/` (ignorés par git).

## Linux (.deb et Arch)

Prérequis : Flutter, les dépendances de build Linux (GTK 3, CMake, Ninja, clang), puis
`dpkg-deb` (Debian/Ubuntu) et/ou `makepkg` (Arch). Un outil absent fait simplement ignorer
le format correspondant.

```bash
packaging/build-linux.sh                  # compile Flutter, produit les deux paquets
packaging/build-linux.sh --skip-flutter   # réutilise le bundle déjà compilé
packaging/build-linux.sh --only deb       # ou --only arch
```

Installation :

```bash
sudo apt install ./packaging/dist/timelog_*.deb     # Debian / Ubuntu
sudo pacman -U packaging/dist/timelog-*.pkg.tar.zst # Arch
```

Le paquet installe l'application dans `/usr/lib/timelog`, la commande `/usr/bin/timelog`,
une entrée de menu et l'icône. Les dépendances (GTK 3, GStreamer) sont déclarées ; l'audio
et la lecture de formats supplémentaires sont des recommandations (`parecord` / `pulseaudio`,
`gst-plugins-good`).

## Windows (installeur NSIS)

À faire **sur Windows** : Flutter ne compile pas l'application Windows depuis Linux.

Prérequis :
- Flutter et Visual Studio 2022 (charge de travail « Développement Desktop en C++ ») ;
- NSIS 3.x (https://nsis.sourceforge.io), `makensis` dans le PATH ou dans `C:\Program Files (x86)\NSIS`.

```powershell
powershell -ExecutionPolicy Bypass -File packaging\windows\build-windows.ps1
# ou, si le bundle est déjà compilé :
powershell -ExecutionPolicy Bypass -File packaging\windows\build-windows.ps1 -SkipFlutter
```

L'installeur :
- installe dans `C:\Program Files\TimeLog` ;
- crée les raccourcis (menu Démarrer et bureau) ;
- s'inscrit dans « Applications et fonctionnalités » (désinstallation possible) ;
- ferme TimeLog s'il tourne pendant une mise à jour ou une désinstallation ;
- **ne supprime pas les données** de l'utilisateur (`%APPDATA%\ch.lukas\TimeLog\`) à la désinstallation.

Runtime Visual C++ : si `vc_redist.x64.exe` (Microsoft, https://aka.ms/vs/17/release/vc_redist.x64.exe)
est placé dans `packaging\windows\redist\` avant la compilation, il est embarqué et installé
automatiquement sur les PC qui ne l'ont pas. Sans ce fichier, l'installeur ne l'inclut pas.

Compilation manuelle, si besoin :

```powershell
makensis /DAPP_VERSION=1.1.1 /DSOURCE_DIR=C:\...\app\build\windows\x64\runner\Release /DOUTPUT_DIR=C:\...\packaging\dist packaging\windows\timelog.nsi
```

## Ce qui a été vérifié

- Linux : `build-linux.sh` produit les deux paquets ; les métadonnées (dépendances, licence,
  entrée `.desktop`) sont validées, et le binaire extrait du `.deb` ne référence aucune
  bibliothèque manquante (`ldd`).
- Windows : le script NSIS compile (avec et sans runtime VC++), et l'installation puis la
  désinstallation silencieuses (`/S`) ont été testées sous Wine avec un exécutable factice
  (copie des fichiers, raccourcis, entrée de registre, nettoyage).
- Non vérifié ici : le script `build-windows.ps1` lui-même (pas de PowerShell fonctionnel
  sur ce poste) et une compilation réelle de `timelog.exe`.

## Avertissements connus

- `namcap` signale des RUNPATH vers le dossier de build dans les plugins (`app/linux/flutter/ephemeral`).
  C'est produit par Flutter ; le lancement fonctionne car les bibliothèques sont déjà chargées
  par l'exécutable. Le paquet Arch ne retire pas les symboles (`!strip`) : le bundle est déjà
  en release, et `strip` ne ferait que réduire la taille des plugins.
- Le paquet Arch n'a pas de sommes de contrôle (`sha256sums=('SKIP')`) : c'est un paquet
  local, reconstruit à chaque fois. Pour une publication, fixer une somme dans `arch/PKGBUILD`.
