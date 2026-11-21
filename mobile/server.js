/**
 * May-Laud Weather & Flood Alert Backend
 * Node.js/Express server providing real-time weather data from OpenWeatherMap
 * and Open-Meteo for the Flutter mobile app.
 *
 * Endpoints:
 *   GET  /health
 *   GET  /weather/current?lat=&lon=        Current weather from OpenWeatherMap
 *   GET  /weather/rain-risk?lat=&lon=      Rain/flood risk assessment
 *   GET  /weather/forecast?lat=&lon=       7-day forecast from Open-Meteo
 *
 * Configuration (.env):
 *   OPENWEATHER_API_KEY=...   (required, server-side only — never shipped to clients)
 *   PORT=3000
 *   CORS_ORIGIN=*
 *   NODE_ENV=development
 *
 * Default coordinates: lat=13.596, lon=123.177 (Milaor, Camarines Sur)
 */

import express from 'express';
import dotenv from 'dotenv';
import axios from 'axios';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const OPENWEATHER_API_KEY = process.env.OPENWEATHER_API_KEY;
const DEFAULT_LAT = 13.596;
const DEFAULT_LON = 123.177;
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

const OWM_BASE = 'https://api.openweathermap.org/data/2.5';
const OM_BASE = 'https://api.open-meteo.com/v1';

app.use(helmet());
app.use(cors({ origin: CORS_ORIGIN, credentials: true }));
app.use(express.json({ limit: '10kb' }));
app.use(morgan('dev'));

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 100 });
app.use(limiter);

/** Classify rain risk using the same thresholds the Flutter side documents
 *  (50 mm / 12 h = Severe, matching weather_service.dart + flood_alert_screen.dart). */
function classifyRainRisk(mm) {
  if (mm >= 50) return 'Severe';
  if (mm >= 25) return 'High';
  if (mm >= 10) return 'Moderate';
  return 'Low';
}

function recommendedAction(risk) {
  switch (risk) {
    case 'Severe':
      return 'Evacuate immediately to designated safe zones. Follow authorities\' instructions.';
    case 'High':
      return 'Consider evacuation if in low-lying areas. Avoid flooded streets.';
    case 'Moderate':
      return 'Prepare emergency kits. Stay alert for updates.';
    default:
      return 'Monitor weather updates. No immediate action required.';
  }
}

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    openweather_configured: !!OPENWEATHER_API_KEY,
  });
});

app.get('/weather/current', async (req, res) => {
  try {
    const lat = req.query.lat != null ? parseFloat(req.query.lat) : DEFAULT_LAT;
    const lon = req.query.lon != null ? parseFloat(req.query.lon) : DEFAULT_LON;
    if (!OPENWEATHER_API_KEY) {
      return res.status(500).json({ error: 'OpenWeatherMap API key not configured on server' });
    }
    const { data } = await axios.get(`${OWM_BASE}/weather`, {
      params: { lat, lon, appid: OPENWEATHER_API_KEY, units: 'metric' },
      timeout: 15000,
    });
    res.json({
      lat: data.coord.lat,
      lon: data.coord.lon,
      name: data.name,
      country: data.sys.country,
      temp: data.main.temp,
      feels_like: data.main.feels_like,
      humidity: data.main.humidity,
      pressure: data.main.pressure,
      weather: data.weather[0],
      wind: data.wind,
      clouds: data.clouds,
      rain: data.rain || null,
      snow: data.snow || null,
      visibility: data.visibility,
      dt: data.dt,
    });
  } catch (err) {
    const status = err.response ? err.response.status : 500;
    if (status === 401) return res.status(401).json({ error: 'Invalid OpenWeatherMap API key' });
    if (status === 403) return res.status(403).json({ error: 'OpenWeatherMap API access forbidden' });
    if (status === 404) return res.status(404).json({ error: 'Location not found' });
    if (status === 429) return res.status(429).json({ error: 'OpenWeatherMap rate limit exceeded' });
    res.status(500).json({ error: 'Failed to fetch current weather' });
  }
});

app.get('/weather/rain-risk', async (req, res) => {
  try {
    const lat = req.query.lat != null ? parseFloat(req.query.lat) : DEFAULT_LAT;
    const lon = req.query.lon != null ? parseFloat(req.query.lon) : DEFAULT_LON;
    if (!OPENWEATHER_API_KEY) {
      return res.status(503).json({ error: 'OpenWeatherMap API key not configured on server' });
    }

    // 1) Current conditions from OpenWeatherMap (the key-protected provider).
    //    Never fabricate data if the provider fails — surface a 502 instead.
    let currentRainMm = 0;
    let temp, humidity, condition;
    try {
      const { data } = await axios.get(`${OWM_BASE}/weather`, {
        params: { lat, lon, appid: OPENWEATHER_API_KEY, units: 'metric' },
        timeout: 15000,
      });
      temp = data.main.temp;
      humidity = data.main.humidity;
      condition = data.weather[0].description;
      currentRainMm =
        data.rain && data.rain['1h'] != null
          ? data.rain['1h']
          : data.rain && data.rain['3h'] != null
            ? data.rain['3h'] / 3
            : 0;
    } catch (err) {
      const status = err.response ? err.response.status : 502;
      return res.status(status === 502 ? 502 : status).json({
        error: 'Weather provider unavailable',
        provider: 'openweathermap',
      });
    }

    // 2) Next-12-h precipitation outlook from Open-Meteo (free, no key required).
    //    Falls back to the current-rain reading if the forecast source is down.
    let expectedRainMmNext12h = currentRainMm;
    try {
      const { data } = await axios.get(`${OM_BASE}/forecast`, {
      params: {
        latitude: lat,
        longitude: lon,
        hourly: 'precipitation',
        forecast_hours: 12,
        timezone: 'Asia/Manila',
      },
      timeout: 8000,
    });
      const hourly = data.hourly || {};
      const times = hourly.time || [];
      const precip = hourly.precipitation || [];
      const nowIso = new Date().toISOString();
      let sum = 0;
      let count = 0;
      for (let i = 0; i < times.length && count < 12; i += 1) {
        if (times[i] >= nowIso) {
          sum += precip[i] || 0;
          count += 1;
        }
      }
      if (count > 0) expectedRainMmNext12h = sum;
    } catch (_) {
      // keep currentRainMm as best-available estimate
    }

    const risk = classifyRainRisk(expectedRainMmNext12h);
    res.json({
      lat,
      lng: lon,
      expected_rain_mm_next_12h: parseFloat(expectedRainMmNext12h.toFixed(1)),
      flood_risk: risk,
      evacuation_advisory: risk === 'Severe',
      recommended_action: recommendedAction(risk),
      note: `Based on OpenWeatherMap current conditions (${condition}, ${temp}°C, ${humidity}% humidity) and Open-Meteo 12h precipitation outlook. Not a substitute for official PAGASA advisories.`,
      checked_at: new Date().toISOString(),
      source: { current: 'openweathermap', forecast: 'open-meteo' },
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to compute rain risk' });
  }
});

app.get('/weather/forecast', async (req, res) => {
  try {
    const lat = req.query.lat != null ? parseFloat(req.query.lat) : DEFAULT_LAT;
    const lon = req.query.lon != null ? parseFloat(req.query.lon) : DEFAULT_LON;
    const { data } = await axios.get(`${OM_BASE}/forecast`, {
      params: {
        latitude: lat,
        longitude: lon,
        daily:
          'weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max',
        timezone: 'Asia/Manila',
      },
      timeout: 15000,
    });
    res.json({ lat, lon, daily: data.daily, timezone: data.timezone });
  } catch (err) {
    res.status(502).json({ error: 'Forecast provider unavailable' });
  }
});

app.listen(PORT, () => {
  console.log(`May-Laud Weather Backend running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`OpenWeatherMap configured: ${!!OPENWEATHER_API_KEY}`);
});

export default app;
