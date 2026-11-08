# Serveur de synchronisation TimeLog

Serveur **Go** + **MariaDB** qui synchronise les données de l'application TimeLog
entre plusieurs appareils (téléphone, ordinateur…) d'un même compte (e-mail + mot de passe).
L'application fonctionne hors ligne et envoie ses modifications dès que le serveur est joignable.

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

| Commande | |
|---|---|
| `docker compose logs -f api` | journaux du serveur |
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

## Configuration (`.env`)

| Variable | Défaut | |
|---|---|---|
| `DB_PASSWORD`, `DB_ROOT_PASSWORD` | — | mots de passe MariaDB (obligatoires) |
| `TIMELOG_PORT` | `8787` | port de l'API sur la machine |
| `SESSION_DAYS` | `180` | durée de validité d'une connexion sans utilisation |
| `MAX_BODY_MB` | `256` | taille maximale d'une requête (pièces jointes) |

## Sécurité

- Mots de passe hachés avec **bcrypt** (coût 12), jamais stockés ni journalisés en clair ;
  l'application ne garde pas le mot de passe, seulement un jeton de session.
- Jetons de session aléatoires (256 bits), stockés côté serveur sous forme de **SHA-256** uniquement.
- Limitation des tentatives de connexion (10 échecs / 15 min par IP et e-mail) ;
  temps de réponse identique que l'e-mail existe ou non.
- Chaque compte ne voit que ses données ; suppression du compte = suppression de toutes ses données.
- Image Docker minimale (distroless), utilisateur non root.

## Développement

```bash
go test ./...            # tests de la fusion
go vet ./...
DB_DSN='timelog:…@tcp(localhost:3306)/timelog?charset=utf8mb4&parseTime=true' go run .
# Test de bout en bout avec l'application (depuis le dossier app/) :
cd ../app && TIMELOG_SERVER=http://localhost:8787 flutter test test/server_e2e_test.dart
```

Voir [API.md](API.md) pour l'API et [../docs/SYNC.md](../docs/SYNC.md) pour le fonctionnement.
