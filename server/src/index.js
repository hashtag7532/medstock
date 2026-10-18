import express from 'express';
import { requireUser } from './auth.js';
import { migrate, pool, transaction } from './db.js';
import { BadRequest, pull, push } from './sync.js';

const app = express();
app.use(express.json({ limit: '10mb' }));

app.get('/health', async (_req, res) => {
  await pool.query('SELECT 1');
  res.json({ ok: true });
});

app.use('/v1', requireUser);

/** Who am I, and how much is stored for me. */
app.get('/v1/me', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT
       (SELECT count(*) FROM medicines   WHERE user_id = $1 AND NOT deleted)::int AS medicines,
       (SELECT count(*) FROM schedules   WHERE user_id = $1 AND NOT deleted)::int AS schedules,
       (SELECT count(*) FROM dose_logs   WHERE user_id = $1)::int               AS dose_logs,
       (SELECT count(*) FROM lab_reports WHERE user_id = $1 AND NOT deleted)::int AS lab_reports`,
    [req.user.id],
  );
  res.json({ user: req.user, counts: rows[0] });
});

/**
 * POST /v1/sync
 * body: { cursor, changes: {medicines, schedules, dose_logs, lab_reports}, deletes: [{table, id}] }
 * reply: { cursor, changes: {...}, deletes: [...] }  (everything changed since `cursor`)
 */
app.post('/v1/sync', async (req, res) => {
  const { cursor = 0, changes = {}, deletes = [] } = req.body ?? {};
  const result = await transaction(async (db) => {
    await push(db, req.user.id, changes, deletes);
    return pull(db, req.user.id, cursor);
  });
  res.json(result);
});

app.use((err, _req, res, _next) => {
  if (err instanceof BadRequest) return res.status(400).json({ error: 'bad_request', message: err.message });
  console.error(err);
  res.status(500).json({ error: 'server_error' });
});

await migrate();
const port = Number(process.env.PORT ?? 8080);
// 0.0.0.0 so the Android emulator (10.0.2.2) and phones on your Wi-Fi can reach it.
app.listen(port, '0.0.0.0', () => console.log(`MedStock API on http://localhost:${port}`));
