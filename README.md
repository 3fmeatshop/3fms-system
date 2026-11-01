# 3FMS SYSTEM

The screens are hosted on **GitHub Pages**; the data stays in your **Google Sheet** (Apps Script).

| File | What it is |
|---|---|
| `index.html` | Team app (Manager, Operations, Cashier, Sales) and Rider app |
| `shop.html` | Customer online shop |
| `config.js` | **Paste your Apps Script /exec URL here** |

## Links
After setup, open the app as Manager › **Users & PINs** › *App links* — the links shown there already point to GitHub:

- Team: `https://<you>.github.io/3fms-system/?k=<team key>`
- Rider: `https://<you>.github.io/3fms-system/?k=<rider key>`
- Shop: `https://<you>.github.io/3fms-system/shop.html?k=<shop key>`

The old Apps Script links keep working too.

## Update later
Upload the new `index.html` / `shop.html` (keep `config.js`), and paste the new `Code.gs` in Apps Script › Deploy › Manage deployments › New version.
