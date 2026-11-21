# Milaud Web Admin Dashboard

The React admin dashboard for **Milaud**. Municipal staff use it to verify citizen reports, group them into incidents, manage document requests, and publish announcements to the mobile app.

See the [main README](../README.md) for the full project overview.

## Features
- Report verification workflow with incident grouping and routing
- Announcements, document requests, and emergency hotline management
- App theme customization that syncs to the mobile app
- Admin authentication with Supabase row-level security

## Tech stack
React 19 · Vite · Tailwind CSS · React Router · Supabase

## Run locally
Create a `.env` file in this folder:
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

Then:
```bash
npm install
npm run dev        # development server
npm run build      # production build
node --test        # run tests
```

More detail: [Supabase integration](SUPABASE_INTEGRATION.md) · [Deployment guide](DEPLOYMENT_GUIDE.md) · [Project documentation](PROJECT_DOCUMENTATION.md)
