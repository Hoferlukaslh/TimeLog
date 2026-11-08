# Synchronisation (hors ligne d'abord)

TimeLog fonctionne toujours sur sa base **SQLite locale** (dans le navigateur pour la version web :
SQLite WebAssembly, stocké dans IndexedDB). La synchronisation est une option :
une fois connecté à un compte (menu *Synchronisation*), l'application échange ses modifications
avec le serveur ([server/](../server)) dès qu'il est joignable.

## Côté application (`app/lib/sync/`)

| Fichier | Rôle |
|---|---|
| `sync_schema.dart` | colonnes `uid` / `modified_at`, table `sync_log`, triggers SQLite |
| `sync_engine.dart` | connexion au compte, envoi / réception / fusion |
| `http_sync_backend.dart` | client de l'API |
| `sync_controller.dart` | synchronisation automatique et état pour l'interface |

### Suivi des modifications par triggers

Chaque table synchronisée a :
- `uid` : identifiant global (une journée est `day:2026-11-09` sur tous les appareils, ce qui permet
  de pointer l'arrivée sur le téléphone et le départ sur l'ordinateur dans la même journée) ;
- `modified_at` : date de dernière modification (ms).

Des **triggers SQLite** maintiennent ces colonnes et, quand la synchronisation est active, inscrivent
dans `sync_log` la table, l'uid et les **colonnes modifiées**. Tous les écrivains sont donc couverts
sans code spécifique : l'application, le **widget Android** (Kotlin), la restauration d'une sauvegarde.
Sans compte connecté, rien n'est inscrit.

Les réglages d'affichage (`themeMode`, `accentColor`, `language`, `use24h`) restent propres à chaque
appareil ; les autres (objectif journalier, jours travaillés, vacances…) sont synchronisés.

### Un cycle de synchronisation

1. **Réception** (`pull`, paginée) : les lignes modifiées sur le serveur sont appliquées colonne par
   colonne ; une colonne modifiée localement plus récemment et pas encore envoyée est conservée.
2. **Envoi** (`push`, par lots de 200 lignes / 16 Mo) : une modification par ligne, avec les colonnes
   modifiées ; les entrées envoyées sont retirées de `sync_log`.

Recevoir avant d'envoyer est important : les modifications locales en attente protègent les colonnes
modifiées ici plus récemment.

### Quand

Au démarrage, au retour dans l'application, toutes les 20 s s'il y a des modifications en attente et
toutes les 3 min sinon. Hors ligne, rien n'est perdu : `sync_log` garde les modifications.
Les pointages faits avec le widget Android, application fermée, sont envoyés à la prochaine ouverture.

### Compte

- Le mot de passe n'est jamais enregistré sur l'appareil, seulement le jeton de session (`sync_meta`).
- À la connexion, toutes les données de l'appareil sont envoyées et fusionnées avec le compte.
- Déconnexion : les données restent sur l'appareil, plus rien n'est synchronisé.
- Session expirée : l'application demande de se reconnecter (données locales conservées).

## Limites connues

- Les dates de modification viennent de l'horloge des appareils : des horloges très décalées peuvent
  donner la victoire à la mauvaise modification en cas de conflit sur la même colonne.
- Pas de synchronisation en arrière-plan quand l'application est fermée (prochaine ouverture).
- Version web : chaque navigateur est un appareil distinct, avec sa propre copie des données ; vider
  les données du site supprime les modifications qui n'ont pas encore été envoyées.
- Les pièces jointes sont transférées entières à chaque modification de leur contenu.
