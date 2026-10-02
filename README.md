# Viroh Automation portfolio: setup

The site is one static `index.html` on Vercel. Dashboards, uploaded HTML files and contact details live in Supabase, so changes in the admin panel go live for every visitor straight away.

| File | Purpose |
| --- | --- |
| `index.html` | The website and admin panel |
| `supabase-setup.sql` | Creates tables, storage, security rules and sample data |
| `vercel.json` | Security headers for Vercel |

## 1. Get your Supabase keys

1. Open <https://supabase.com/dashboard> and select your project.
2. Open **Project Settings → API Keys**. Copy the **Publishable key** (`sb_publishable_…`). It's already in `index.html`.
3. Open **Project Settings → Data API**. Copy the **Project URL**, which looks like `https://abcdxyz.supabase.co`.
4. Never copy the **Secret key** (`sb_secret_…`) or the `service_role` key into the site or GitHub. They bypass all security rules.

## 2. Add the Project URL to the site

In `index.html`, find this line near the top of the main script and paste your Project URL:

```js
const SUPABASE_URL='https://YOUR-PROJECT-REF.supabase.co';
```

## 3. Lock down sign-in and create the admin user

In the Supabase dashboard:

1. **Authentication → Sign In / Providers → Email**: keep Email enabled, and turn **Allow new users to sign up** off.
2. **Authentication → Users → Add user → Create new user**: email `padavepranay01@gmail.com`, a strong password of at least 12 characters, and tick **Auto Confirm User**.
3. **Authentication → Multi-Factor**: make sure **TOTP (App Authenticator)** is enabled.
4. **Authentication → URL Configuration**: set **Site URL** to your Vercel address, for example `https://your-site.vercel.app`.

## 4. Create the database

Open **SQL Editor → New query**, paste all of `supabase-setup.sql`, and click **Run**. The final query should return one row with your email. If it's empty, finish step 3, then run the file again.

## 5. Publish to GitHub and Vercel

1. Push `index.html`, `vercel.json` and `README.md` to your GitHub repo. `supabase-setup.sql` is safe to include too, because it contains no secrets.
2. In Vercel: **Add New → Project →** import the repo. Choose framework preset **Other** and leave the build command empty, then deploy.

## 6. First admin sign-in

1. Open `https://your-site.vercel.app/#admin`, or click **Admin** in the footer.
2. Sign in with your email and password.
3. Scan the QR code with Google Authenticator, Microsoft Authenticator or Authy, then enter the 6-digit code.
4. From now on, every sign-in asks for your password **and** a code from that app.

## How security works

- **Database rules (RLS)** decide who can do what. Visitors can only read published dashboards and contact details. The database accepts writes only from an account listed in `admins` that has passed the authenticator check. The admin panel UI is not the security layer, so even someone who reads the page code can't change anything.
- **The publishable key is public by design.** It identifies your project but grants nothing beyond what RLS allows.
- **Sign-up is disabled**, so nobody can create a new account.
- **Uploaded dashboards** go to a private storage bucket (HTML only, 2 MB maximum). They're downloadable only while published, and they run in a sandboxed iframe that can't reach your admin session.
- **Sessions** end when you close the tab or after 20 minutes of inactivity. The Security page has **Sign out everywhere**.

## Routine tasks

- **Upload a dashboard:** Admin → Dashboards → drag in an `.html` file. It goes live immediately; use **Unpublish** to hide it.
- **Lost your authenticator phone:** Supabase → Authentication → Users → your user → delete the MFA factor, then sign in and scan a new QR code.
- **Forgot your password:** Supabase → Authentication → Users → your user → **Send password recovery**, or set a new password there.
- **Check for suspicious sign-ins:** Supabase → Authentication → Logs.
- **Free plan pausing:** free projects pause after about a week with no activity. If the site shows "Dashboards could not be loaded", open the Supabase dashboard and click **Restore project**.
