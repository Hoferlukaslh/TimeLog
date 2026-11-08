# Serveur de synchronisation TimeLog

Serveur **Go** + **MariaDB** qui synchronise les données de l'application TimeLog
entre plusieurs appareils (téléphone, ordinateur…) d'un même compte (e-mail + mot de passe).
L'application fonctionne hors ligne et envoie ses modifications dès que le serveur est joignable.

**NGINX** est le point de sortie unique : l'API sous `/api/` et, si elle est activée, la version
web de l'application sous `/`, sur un seul port. Seul ce service est exposé.

## Démarrage (Docker)

```bash
cd server
cp .env.example .env        # puis changer les mots de passe dans .env
docker compose up -d --build
curl http://localhost:8787/api/v1/health    # {"app":"TimeLog","status":"ok"}
```

Dans l'application : menu **Synchronisation** → adresse du serveur
(ex. `http://192.168.1.10:8787` sur le réseau local), e-mail, mot de passe → *Créer un compte*,
puis *Se connecter* avec le même compte sur les autres appareils.

## Version web

Avec `WEB_ENABLED=true` dans `.env`, l'application est disponible dans un navigateur à l'adresse du
serveur, sans autre configuration (elle utilise l'API de la même adresse).

| Changement | Commande |
|---|---|
| activer (`WEB_ENABLED=true`) | `docker compose up -d --build` — plusieurs minutes la première fois (SDK Flutter) |
| désactiver (`WEB_ENABLED=false`) | `docker compose up -d` — l'API continue, la page web renvoie 404 |

La valeur doit être exactement `true` ou `false`. Si la variable est absente (fichier `.env` d'une
ancienne installation), la version web reste désactivée et le SDK Flutter n'est pas téléchargé.
Le microphone (notes audio) n'est autorisé par les navigateurs qu'en HTTPS ou sur `localhost`.

## Mise à jour d'une installation existante

```bash
git pull
docker compose up -d --build
```

Le fichier `.env`, la base (volume `db-data`), le port et les comptes ne changent pas. Les
applications déjà installées continuent de fonctionner sans modification : l'API est identique et
reste à la même adresse, désormais à travers NGINX.

| Commande | |
|---|---|
| `docker compose logs -f api` | journaux de l'API (`gateway` : journaux de NGINX) |
| `docker compose down` | arrêter (les données restent dans le volume `db-data`) |
| `docker compose up -d --build` | mettre à jour après un changement du code |
| `docker compose exec db mariadb-dump -utimelog -p timelog > sauvegarde.sql` | sauvegarde |

## Utilisation par Internet : HTTPS obligatoire

En `http://`, le mot de passe et les données circulent **en clair** (l'application l'indique).
C'est acceptable sur le réseau local, pas sur Internet. Placer l'API derrière un reverse proxy
avec certificat, par exemple Caddy :

```
timelog.exemple.ch {
    reverse_proxy localhost:8787
}
```

Derrière un reverse proxy, indiquer son adresse dans `TRUSTED_PROXIES` (ex. `172.16.0.0/12` pour un
Caddy sur la machine hôte) : la limitation des tentatives de connexion par adresse IP continue
alors de voir l'adresse réelle des clients.

## Configuration (`.env`)

| Variable | Défaut | |
|---|---|---|
| `DB_PASSWORD`, `DB_ROOT_PASSWORD` | — | mots de passe MariaDB (obligatoires) |
| `WEB_ENABLED` | `false` (`true` dans `.env.example`) | `true` : sert aussi la version web |
| `TIMELOG_PORT` | `8787` | port du serveur sur la machine (API et version web) |
| `TRUSTED_PROXIES` | — | reverse proxies de confiance (CIDR séparés par des espaces) |
| `SESSION_DAYS` | `180` | durée de validité d'une connexion sans utilisation |
| `MAX_BODY_MB` | `256` | taille maximale d'une requête (pièces jointes) |

## Sécurité

- Mots de passe hachés avec **bcrypt** (coût 12), jamais stockés ni journalisés en clair ;
  l'application ne garde pas le mot de passe, seulement un jeton de session.
- Jetons de session aléatoires (256 bits), stockés côté serveur sous forme de **SHA-256** uniquement.
- Limitation des tentatives de connexion (10 échecs / 15 min par IP et e-mail) ;
  temps de réponse identique que l'e-mail existe ou non.
- Chaque compte ne voit que ses données ; suppression du compte = suppression de toutes ses données.
- Images Docker avec utilisateur non root (API : distroless ; NGINX : alpine non privilégiée).
- NGINX remplace l'en-tête `X-Forwarded-For` : un client ne peut pas contourner la limitation des
  tentatives en choisissant son adresse.

## Développement

```bash
go test ./...            # tests de la fusion
go vet ./...
DB_DSN='timelog:…@tcp(localhost:3306)/timelog?charset=utf8mb4&parseTime=true' go run .
# Test de bout en bout avec l'application (depuis le dossier app/) :
cd ../app && TIMELOG_SERVER=http://localhost:8787 flutter test test/server_e2e_test.dart
```

Voir [API.md](API.md) pour l'API et [../docs/SYNC.md](../docs/SYNC.md) pour le fonctionnement.
