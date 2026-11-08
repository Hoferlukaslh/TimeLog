# Développement

TimeLog est une application **Flutter** (Android, Linux, Windows, Web) avec un widget Android natif en
**Kotlin** et un serveur de synchronisation facultatif en **Go + MariaDB**.

Le dépôt contient deux projets : l'application dans [`app/`](../app) et le serveur dans
[`server/`](../server). Sauf mention contraire, les commandes ci-dessous se lancent dans `app/`.

## Lancer et tester

```bash
cd app
flutter pub get
flutter run -d linux          # bureau Linux (GStreamer, parecord/ffmpeg)
flutter run -d windows        # bureau Windows (uniquement depuis Windows, Visual Studio 2022)
flutter run -d chrome         # navigateur (sans serveur : voir « Version web »)
flutter run -d <android-id>   # téléphone / émulateur Android
flutter test                  # tests Dart / widgets
(cd android && ./gradlew :app:testDebugUnitTest)   # tests Kotlin du widget

# Test de bout en bout avec le serveur de synchronisation
(cd ../server && docker compose up -d --build)
TIMELOG_SERVER=http://localhost:8787 flutter test test/server_e2e_test.dart
```

## Qualité du code

```bash
dart analyze                 # analyse stricte (types stricts, futures, style) : 0 problème attendu
dart format lib test         # formatage (largeur 120, défini dans analysis_options.yaml)
(cd android && ./gradlew :app:lintDebug :app:testDebugUnitTest)   # Android Lint + tests Kotlin
(cd ../server && go vet ./... && go test ./...)                      # serveur
```

> - `flutter analyze` peut planter (serveur d'analyse) avec Flutter 3.47 : utiliser `dart analyze`.
> - Pour Gradle en ligne de commande, utiliser le JDK d'Android Studio (`JAVA_HOME=/opt/android-studio/jbr`).
> - Si des icônes manquent dans un build release, lancer `flutter clean` puis reconstruire
>   (le cache de réduction de la police d'icônes n'est pas toujours régénéré).

La version de l'application est définie dans `pubspec.yaml` et doit correspondre à
`AppInfo.appVersion` (`app/lib/app_info.dart`) ; un test le vérifie.

## Structure

```
app/                 application Flutter
  lib/
    data/            base SQLite (schéma) et dépôt d'accès aux données
    platform/        ce qui dépend de l'hôte : implémentation io (Android, Linux, Windows) et web
    models/          modèles (TimeEntry, JournalEntry, Note, Attachment, Category)
    services/        paramètres, calcul des heures, vacances, catégories, export/import, widget
    sync/            synchronisation hors ligne d'abord (triggers, moteur, client HTTP)
    screens/         écrans (heures, journal, notes, éditeurs, dessin, audio, paramètres…)
    widgets/         composants réutilisables (sélecteur de période, éditeur Markdown, responsive…)
    drawing/         modèle et rendu des dessins vectoriels
    l10n/            traductions ARB (+ code généré dans l10n/gen)
  android/           application Android et widget natif (Kotlin, écrit directement dans SQLite)
  linux/             application Linux et script d'entrée de menu
  windows/           application Windows
  web/               page d'accueil, icônes, SQLite WebAssembly (sqlite3.wasm, sqflite_sw.js)
  test/              tests Dart
server/              serveur de synchronisation Go + MariaDB (Docker)
  gateway/           NGINX, point de sortie unique (API + version web)
docs/                documentation technique
```

Toutes les données, y compris les pièces jointes (découpées en blocs), sont stockées dans
une base **SQLite** unique.

## Plateformes

- **Ne pas importer `dart:io`** hors de `lib/platform/platform_io.dart` : l'application ne compilerait
  plus pour le web. Ce qui dépend de l'hôte passe par `lib/platform/platform.dart`.
- **Grands écrans** : `lib/widgets/responsive.dart` définit les seuils. Tout est conditionné à une
  hauteur d'au moins 500 : un téléphone, même en paysage, garde exactement l'interface compacte.
- **Windows** : ne se compile que sous Windows (pas de compilation croisée depuis Linux).

### Version web

SQLite tourne en WebAssembly dans un worker partagé (`web/sqlite3.wasm`, `web/sqflite_sw.js`) et
stocke la base dans IndexedDB. Après une mise à jour de `sqflite_common_ffi_web`, régénérer ces
deux fichiers : `dart run sqflite_common_ffi_web:setup --force`.

En production, l'API et l'application partagent la même origine (NGINX), l'API n'a donc pas besoin
de CORS. Pour tester la synchronisation dans un navigateur, passer par l'image Docker
([server/README.md](../server/README.md)) : `flutter run -d chrome` ne sert pas l'API.

## Ajouter une langue

1. Copier `app/lib/l10n/app_en.arb` en `app/lib/l10n/app_xx.arb` (code ISO de la langue).
2. Changer `"@@locale"` en `"xx"` et traduire les valeurs (dont `languageName`, le nom de
   la langue dans cette langue).
3. Lancer `flutter gen-l10n` (ou simplement `flutter run`). La langue apparaît
   automatiquement dans les paramètres.

Pour le widget Android, ajouter aussi `app/android/app/src/main/res/values-xx/strings.xml`.
