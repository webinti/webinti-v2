# Webinti — site vitrine (Astro)

Site statique construit avec [Astro](https://astro.build). Hébergé sur un VPS,
servi par nginx.

## ⚠️ Structure du projet — à lire

**Tout est à la RACINE du dépôt.** Il n'y a pas (plus) de sous-dossier `site/`.

```text
/
├── astro.config.mjs      # config Astro (build → ./dist)
├── package.json          # scripts npm (build, dev…)
├── public/               # assets statiques servis tels quels
├── src/
│   ├── pages/            # une route par fichier .astro
│   ├── layouts/          # BaseLayout.astro = <head> commun (SEO, Google Analytics…)
│   ├── components/
│   ├── content/          # collections (projets showcase…)
│   └── styles/
├── cadrage-service/      # micro-service Node annexe (cadrage-quaisud) + son unit systemd
├── deploy/               # config nginx de référence
└── dist/                 # SORTIE DE BUILD (gitignored, généré par `npm run build`)
```

> Historique : le projet a transité par une structure `site/…`. Elle a été
> abandonnée. **La seule source de vérité est la racine.** Ne pas recréer de
> dossier `site/`.

## 🧞 Commandes (depuis la racine)

| Commande          | Action                                      |
| :---------------- | :------------------------------------------ |
| `npm install`     | Installe les dépendances                    |
| `npm run dev`     | Serveur de dev sur `localhost:4321`         |
| `npm run build`   | Build de production vers `./dist/`          |
| `npm run preview` | Prévisualise le build local                 |

## 🚀 Déploiement (VPS)

Le site est servi par nginx **directement depuis `./dist`** :
`root /home/openclaw/projects/webinti/dist;` (voir `deploy/nginx-webinti.conf`).

Pour déployer une mise à jour, sur le VPS, à la racine du dépôt :

```sh
git pull origin main
npm install
npm run build      # régénère ./dist servi par nginx
```

Aucun `rsync` ni reload nginx nécessaire : nginx sert `./dist`, et `npm run build`
remplace son contenu. Le HTML a un cache court (5 min) côté navigateur — faire un
hard refresh (Ctrl+Shift+R) pour vérifier.

## 📊 Analytics

Google Analytics (gtag.js) est injecté pour **toutes les pages** via
`src/layouts/BaseLayout.astro`. L'ID de mesure (`G-…`) y est défini par défaut et
peut être surchargé via la variable d'environnement `PUBLIC_GA_ID`.
