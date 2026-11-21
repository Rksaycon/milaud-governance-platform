import { useState, useEffect, useCallback } from "react";
import { supabase } from "./supabaseClient";

// ── Colour helpers ──────────────────────────────────────────────────────────
// `shift()` mirrors AppColors.shift() in the mobile app
// (may_laud/lib/theme/app_colors.dart) — HSLColor.fromColor(c).withLightness(l + d).
// Using the same maths here means the preview shows exactly the shades the phone
// will derive, instead of an approximation that drifts from the real palette.
const normalizeHex = (v) => {
  let hex = String(v || "").trim().replace(/^#/, "");
  if (/^[0-9a-f]{3}$/i.test(hex)) {
    hex = hex.split("").map((ch) => ch + ch).join("");
  }
  return /^[0-9a-f]{6}$/i.test(hex) ? `#${hex.toUpperCase()}` : null;
};

const shift = (hex, delta) => {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h /= 6;
  }
  const nl = Math.min(1, Math.max(0, l + delta));
  const channel = (n) => {
    const k = (n + h * 12) % 12;
    const a = s * Math.min(nl, 1 - nl);
    const v = nl - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
    return Math.round(255 * v).toString(16).padStart(2, "0");
  };
  return `#${channel(0)}${channel(8)}${channel(4)}`.toUpperCase();
};

// Shipped Maylaud palette (AppThemeConfig.defaults in app_theme_provider.dart).
const DEFAULT_BRAND = "#4C229C";
const DEFAULT_ACCENT = "#0056A3";

// PostgREST reports an unknown table as PGRST204 / "schema cache". That means
// supabase_app_theme.sql hasn't been run in this project yet — not that the
// colours are wrong. Detect it so the page can show setup instructions instead
// of a raw driver error the admin can't act on.
const isMissingTableError = (err) => {
  const text = `${err?.code ?? ""} ${err?.message ?? ""} ${err?.details ?? ""}`;
  return (
    /PGRST204/i.test(text) ||
    /could not find the table/i.test(text) ||
    /schema cache/i.test(text) ||
    /42P01/i.test(text) // undefined_table
  );
};

const SETUP_SQL = `create table if not exists public.app_theme (
  id           int primary key default 1,
  brand_color  text not null default '#4C229C',
  accent_color text not null default '#0056A3',
  updated_at   timestamptz not null default now(),
  constraint app_theme_singleton check (id = 1)
);

alter table public.app_theme enable row level security;

drop policy if exists "Anyone can view app theme" on public.app_theme;
create policy "Anyone can view app theme"
  on public.app_theme for select using (true);

drop policy if exists "Authenticated users can insert app theme" on public.app_theme;
create policy "Authenticated users can insert app theme"
  on public.app_theme for insert to authenticated with check (true);

drop policy if exists "Authenticated users can update app theme" on public.app_theme;
create policy "Authenticated users can update app theme"
  on public.app_theme for update to authenticated using (true);

insert into public.app_theme (id, brand_color, accent_color)
values (1, '#4C229C', '#0056A3') on conflict (id) do nothing;

alter table public.app_theme replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'app_theme'
  ) then
    alter publication supabase_realtime add table public.app_theme;
  end if;
end $$;`;

const PRESETS = [
  { name: "Maylaud Purple", brand: "#4C229C", accent: "#0056A3" },
  { name: "Ocean Blue", brand: "#1D4ED8", accent: "#0EA5E9" },
  { name: "Emerald", brand: "#047857", accent: "#059669" },
  { name: "Crimson", brand: "#B91C1C", accent: "#DC2626" },
  { name: "Sunset", brand: "#EA580C", accent: "#F59E0B" },
  { name: "Indigo Night", brand: "#4338CA", accent: "#6366F1" },
  { name: "Teal", brand: "#0F766E", accent: "#14B8A6" },
  { name: "Slate", brand: "#334155", accent: "#475569" },
];

const AppCustomizationPage = () => {
  const [brand, setBrand] = useState(DEFAULT_BRAND);
  const [accent, setAccent] = useState(DEFAULT_ACCENT);
  const [published, setPublished] = useState({
    brand: DEFAULT_BRAND,
    accent: DEFAULT_ACCENT,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState(null);
  // True when app_theme hasn't been created in this Supabase project yet.
  const [needsSetup, setNeedsSetup] = useState(false);
  const [sqlCopied, setSqlCopied] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("app_theme")
        .select("brand_color, accent_color")
        .eq("id", 1)
        .maybeSingle();
      if (error) throw error;
      setNeedsSetup(false);
      setMessage(null);
      if (data) {
        const next = {
          brand: normalizeHex(data.brand_color) || DEFAULT_BRAND,
          accent: normalizeHex(data.accent_color) || DEFAULT_ACCENT,
        };
        setBrand(next.brand);
        setAccent(next.accent);
        setPublished(next);
      }
    } catch (err) {
      if (isMissingTableError(err)) {
        setNeedsSetup(true);
        setMessage(null);
      } else {
        setMessage({
          type: "error",
          text: `Could not load the current palette: ${err.message}`,
        });
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const publish = async () => {
    setSaving(true);
    setMessage(null);
    try {
      const { error } = await supabase.from("app_theme").upsert(
        { id: 1, brand_color: brand, accent_color: accent },
        { onConflict: "id" }
      );
      if (error) throw error;
      setNeedsSetup(false);
      setPublished({ brand, accent });
      setMessage({
        type: "success",
        text: "Published. Phones with the app open repaint automatically — no app update needed.",
      });
    } catch (err) {
      if (isMissingTableError(err)) {
        setNeedsSetup(true);
        setMessage(null);
      } else {
        setMessage({ type: "error", text: `Could not publish: ${err.message}` });
      }
    } finally {
      setSaving(false);
    }
  };

  const copySetupSql = async () => {
    try {
      await navigator.clipboard.writeText(SETUP_SQL);
      setSqlCopied(true);
      setTimeout(() => setSqlCopied(false), 2500);
    } catch {
      setSqlCopied(false);
    }
  };

  const isDirty = brand !== published.brand || accent !== published.accent;

  // The two shades the mobile app derives from the brand colour.
  const midTone = shift(brand, 0.1);
  const darkTone = shift(brand, -0.24);

  const colorField = (label, hint, value, onChange) => (
    <div>
      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
        {label}
      </label>
      <div className="mt-2 flex items-center gap-3">
        <input
          type="color"
          value={value}
          onChange={(e) => onChange(e.target.value.toUpperCase())}
          className="h-10 w-14 cursor-pointer rounded border border-gray-300 dark:border-gray-600 bg-transparent"
          aria-label={label}
        />
        <input
          type="text"
          value={value}
          onChange={(e) => {
            const next = normalizeHex(e.target.value);
            if (next) onChange(next);
          }}
          className="w-32 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-800 dark:text-white font-mono text-sm"
        />
      </div>
      <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">{hint}</p>
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <h2 className="text-xl font-semibold text-gray-800 dark:text-white">
          App Customization
        </h2>
        <p className="mt-1 text-sm text-gray-600 dark:text-gray-400">
          Pick the colours of the Maylaud mobile app. Saving publishes to the shared
          Supabase <code>app_theme</code> row — every phone with the app open repaints
          over Realtime within a second, and the next launch opens in the new palette.
        </p>
        {needsSetup && (
          <div className="mt-4 rounded-lg border border-amber-300 bg-amber-50 px-4 py-4 text-sm text-amber-900 dark:border-amber-700 dark:bg-amber-900/20 dark:text-amber-200">
            <p className="font-semibold">One-time setup: the app_theme table is missing</p>
            <p className="mt-1">
              This Supabase project doesn&apos;t have the <code>app_theme</code>{" "}
              table yet, so there&apos;s nowhere to publish colours. Run the SQL below
              once and this page will work. It only creates a table, a couple of RLS
              policies and a Realtime entry — safe to re-run.
            </p>
            <ol className="mt-3 list-decimal space-y-1 pl-5">
              <li>
                Open your Supabase project → <strong>SQL Editor</strong> → New query.
              </li>
              <li>
                Paste the SQL below (or run <code>supabase_app_theme.sql</code> from
                the repo) and click <strong>Run</strong>.
              </li>
              <li>
                Come back here and press <strong>Check again</strong>.
              </li>
            </ol>
            <pre className="mt-3 max-h-56 overflow-auto rounded bg-black/5 p-3 text-xs leading-relaxed dark:bg-black/30">
              {SETUP_SQL}
            </pre>
            <div className="mt-3 flex flex-wrap gap-3">
              <button
                onClick={copySetupSql}
                className="rounded-lg bg-amber-600 px-3 py-1.5 text-white hover:bg-amber-700"
              >
                {sqlCopied ? "Copied ✓" : "Copy SQL"}
              </button>
              <button
                onClick={load}
                className="rounded-lg border border-amber-400 px-3 py-1.5 hover:bg-amber-100 dark:hover:bg-amber-900/40"
              >
                Check again
              </button>
            </div>
          </div>
        )}
        {message && (
          <div
            className={`mt-4 rounded-lg border px-4 py-3 text-sm ${
              message.type === "success"
                ? "border-green-200 bg-green-50 text-green-800 dark:border-green-800 dark:bg-green-900/30 dark:text-green-300"
                : "border-red-200 bg-red-50 text-red-800 dark:border-red-800 dark:bg-red-900/30 dark:text-red-300"
            }`}
          >
            {message.text}
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6 space-y-6">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {colorField(
              "Brand colour",
              "Headers, gradient, FAB, buttons and accents across the app.",
              brand,
              setBrand
            )}
            {colorField(
              "Accent colour",
              "Links, focused inputs and default Material buttons.",
              accent,
              setAccent
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Presets
            </label>
            <div className="mt-2 flex flex-wrap gap-2">
              {PRESETS.map((p) => (
                <button
                  key={p.name}
                  onClick={() => {
                    setBrand(p.brand);
                    setAccent(p.accent);
                  }}
                  className="flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
                >
                  <span
                    className="h-4 w-4 rounded-full"
                    style={{
                      background: `linear-gradient(135deg, ${shift(p.brand, -0.24)}, ${p.brand})`,
                    }}
                  />
                  {p.name}
                </button>
              ))}
            </div>
          </div>

          <div className="flex flex-wrap gap-3 pt-4 border-t dark:border-gray-700">
            <button
              onClick={publish}
              // Blocked until the table exists — otherwise the only feedback
              // would be the same raw "schema cache" error.
              disabled={saving || !isDirty || needsSetup}
              className="px-4 py-2 rounded-lg text-white bg-purple-600 hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving ? "Publishing…" : "Publish to mobile app"}
            </button>
            <button
              onClick={() => {
                setBrand(DEFAULT_BRAND);
                setAccent(DEFAULT_ACCENT);
              }}
              className="px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300"
            >
              Reset to Maylaud defaults
            </button>
            {isDirty && (
              <span className="self-center text-xs text-amber-600 dark:text-amber-400">
                Unsaved — phones still show the published palette.
              </span>
            )}
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">
            Live preview
          </label>
          <div className="mt-3 mx-auto max-w-[280px] rounded-[2rem] border-4 border-gray-800 dark:border-gray-700 overflow-hidden">
            <div
              className="px-4 pt-8 pb-6"
              style={{ background: `linear-gradient(135deg, ${darkTone}, ${brand})` }}
            >
              <div className="text-white/80 text-xs">Milaor, Camarines Sur</div>
              <div className="text-white text-lg font-bold">Good morning</div>
              <div className="mt-3 h-9 w-9 rounded-full bg-white/25 flex items-center justify-center text-white text-sm">
                3
              </div>
            </div>
            <div className="bg-gray-50 dark:bg-gray-900 px-4 pt-4 pb-16">
              <div className="grid grid-cols-2 gap-2">
                <div className="h-14 rounded-xl bg-white dark:bg-gray-800 shadow-sm" />
                <div className="h-14 rounded-xl bg-white dark:bg-gray-800 shadow-sm" />
              </div>
              <div className="mt-3 rounded-xl bg-white dark:bg-gray-800 shadow-sm p-3">
                <div className="h-2 w-24 rounded bg-gray-300 dark:bg-gray-600" />
                <div className="mt-2 h-2 w-40 rounded bg-gray-200 dark:bg-gray-700" />
                <button
                  className="mt-3 w-full rounded-lg py-2 text-white text-xs font-semibold"
                  style={{ backgroundColor: accent }}
                >
                  Continue
                </button>
              </div>
              <div
                className="mt-3 flex items-center gap-2 text-xs"
                style={{ color: accent }}
              >
                <span
                  className="w-2 h-2 rounded-full"
                  style={{ backgroundColor: brand }}
                />
                <span>Submit a document request</span>
              </div>
            </div>
            <div className="relative">
              <div
                className="absolute -top-6 left-1/2 -translate-x-1/2 h-14 w-14 rounded-full shadow-lg flex items-center justify-center text-white text-xl"
                style={{ background: `linear-gradient(135deg, ${midTone}, ${brand})` }}
              >
                +
              </div>
              <div className="h-1 bg-white dark:bg-gray-800" />
            </div>
          </div>

          <div className="mt-4 grid grid-cols-3 gap-2 text-center">
            {[
              ["Brand", brand],
              ["Mid", midTone],
              ["Anchor", darkTone],
            ].map(([label, value]) => (
              <div key={label}>
                <div className="h-8 rounded-lg" style={{ backgroundColor: value }} />
                <div className="mt-1 text-[11px] font-mono text-gray-500 dark:text-gray-400">
                  {value}
                </div>
                <div className="text-[11px] text-gray-500 dark:text-gray-400">
                  {label}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="lg:col-span-2">
          <p className="text-xs text-gray-500 dark:text-gray-400">
            {loading
              ? "Loading the currently published palette…"
              : `Currently live on phones: ${published.brand} (brand) · ${published.accent} (accent).`}
          </p>
        </div>
      </div>
    </div>
  );
};

export default AppCustomizationPage;