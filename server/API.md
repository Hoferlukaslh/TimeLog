# API du serveur TimeLog (v1)

Base : `/api/v1`. Corps JSON. Les routes marquées 🔒 exigent `Authorization: Bearer <token>`.
Les erreurs renvoient `{"error": "<code>"}`.

| Méthode | Route | Corps | Réponse |
|---|---|---|---|
| GET | `/health` | | `{"status":"ok","app":"TimeLog"}` |
| POST | `/auth/signup` | `{"email","password"}` | 201 `{"token","account_id","email"}` |
| POST | `/auth/login` | `{"email","password"}` | 200 `{"token","account_id","email"}` |
| POST | `/auth/logout` 🔒 | | 204 |
| GET | `/account` 🔒 | | `{"account_id","email"}` |
| POST | `/account/delete` 🔒 | `{"password"}` | 204 — supprime le compte et toutes ses données |
| POST | `/sync/push` 🔒 | `{"device_id","changes":[Change]}` | `{"accepted":n}` |
| GET | `/sync/pull?cursor=N` 🔒 | | `{"changes":[Change],"cursor":"N","has_more":bool}` |

Codes d'erreur : `bad_request`, `too_large`, `invalid_email`, `weak_password` (8 à 72 caractères),
`email_taken`, `invalid_credentials`, `too_many_attempts`, `unauthorized` (jeton absent / expiré),
`server_error`, `database_unavailable`, `server_unavailable` (NGINX ne joint pas l'API).

L'API est servie à travers NGINX (`server/gateway/`), sur la même origine que la version web : elle
n'envoie pas d'en-têtes CORS, et un site hébergé ailleurs ne peut donc pas l'appeler depuis un navigateur.

## Change

```json
{
  "table": "time_entries",
  "uid": "day:2026-11-09",
  "deleted": false,
  "values": {"date": "2026-11-09", "arrival": 480, "departure": null},
  "columns": ["date", "arrival"],
  "modified_at": 1762675200000,
  "device_id": "3f2a…",
  "data": "<base64, contenu d'une pièce jointe>",
  "column_times": {"arrival": 1762675200000}
}
```

- `table` : `settings`, `categories`, `time_entries`, `vacation_years`, `journal_entries`, `notes`, `attachments`.
- `uid` : identifiant global de la ligne. Clé naturelle pour `time_entries` (`day:<date>`),
  `vacation_years` (`year:<année>`), `settings` (`setting:<clé>`) ; aléatoire sinon.
  Les références (`category_id`, `note_id`) sont transmises sous forme d'uid.
- `columns` : colonnes réellement modifiées (fusion colonne par colonne).
- `modified_at` : millisecondes depuis 1970.
- `column_times` : envoyé par le serveur dans `pull` (date de chaque colonne).

## Fusion côté serveur

Le serveur garde l'**état courant** de chaque ligne (`records`) avec la date de chaque colonne :
- une colonne n'est remplacée que par une modification plus récente ;
- une suppression l'emporte sur les modifications plus anciennes et est conservée (pierre tombale)
  pour être transmise aux autres appareils ; une modification plus récente fait revivre la ligne ;
- chaque modification acceptée reçoit un numéro de séquence du compte ; `pull?cursor=N` renvoie
  les lignes modifiées après `N` (par pages : 500 lignes / 16 Mo).
