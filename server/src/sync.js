// Two-way sync. The client pushes rows it changed (with its own UUIDs and
// updated_at), the server keeps the newest version of each row (last write
// wins), then returns every row of this user changed since the client's cursor.

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TABLES = ['medicines', 'schedules', 'dose_logs', 'lab_reports'];

export class BadRequest extends Error {}

function check(condition, message) {
  if (!condition) throw new BadRequest(message);
}

function rows(changes, table) {
  const list = changes?.[table] ?? [];
  check(Array.isArray(list), `${table} must be an array`);
  for (const r of list) {
    check(typeof r === 'object' && r && UUID.test(r.id ?? ''), `${table}: every row needs a UUID id`);
    check(!Number.isNaN(Date.parse(r.updated_at)), `${table}: every row needs updated_at`);
  }
  return list;
}

const num = (v) => (v === null || v === undefined || v === '' ? null : Number(v));

/** Applies the client's changes for user `userId` inside transaction `db`. */
export async function push(db, userId, changes = {}, deletes = []) {
  // Parents first, so foreign keys hold within one request.
  for (const m of rows(changes, 'medicines')) {
    await db.query(
      `INSERT INTO medicines (id, user_id, brand_name, ingredients, form, expiry, batch_number, manufacturer,
                              quantity, unit, uses, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
       ON CONFLICT (id) DO UPDATE SET
         brand_name = EXCLUDED.brand_name, ingredients = EXCLUDED.ingredients, form = EXCLUDED.form,
         expiry = EXCLUDED.expiry, batch_number = EXCLUDED.batch_number, manufacturer = EXCLUDED.manufacturer,
         quantity = EXCLUDED.quantity, unit = EXCLUDED.unit, uses = EXCLUDED.uses,
         updated_at = EXCLUDED.updated_at, deleted = false, rev = nextval('sync_rev')
       WHERE medicines.user_id = $2 AND medicines.updated_at <= EXCLUDED.updated_at`,
      [m.id, userId, String(m.brand_name ?? ''), JSON.stringify(m.ingredients ?? []), String(m.form ?? 'other'),
        m.expiry ?? null, String(m.batch_number ?? ''), String(m.manufacturer ?? ''), Number(m.quantity ?? 0) | 0,
        String(m.unit ?? 'units'), String(m.uses ?? ''), m.created_at ?? m.updated_at, m.updated_at],
    );
  }

  for (const s of rows(changes, 'schedules')) {
    check(UUID.test(s.medicine_id ?? ''), 'schedules: medicine_id must be a UUID');
    await db.query(
      `INSERT INTO schedules (id, user_id, medicine_id, dose, times, start_date, duration_days, instructions, status, updated_at)
       SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10
       WHERE EXISTS (SELECT 1 FROM medicines WHERE id = $3 AND user_id = $2)
       ON CONFLICT (id) DO UPDATE SET
         dose = EXCLUDED.dose, times = EXCLUDED.times, start_date = EXCLUDED.start_date,
         duration_days = EXCLUDED.duration_days, instructions = EXCLUDED.instructions, status = EXCLUDED.status,
         updated_at = EXCLUDED.updated_at, deleted = false, rev = nextval('sync_rev')
       WHERE schedules.user_id = $2 AND schedules.updated_at <= EXCLUDED.updated_at`,
      [s.id, userId, s.medicine_id, Number(s.dose ?? 1) | 0, JSON.stringify(s.times ?? []), String(s.start_date),
        s.duration_days ?? null, String(s.instructions ?? ''), String(s.status ?? 'active'), s.updated_at],
    );
  }

  for (const l of rows(changes, 'dose_logs')) {
    check(UUID.test(l.schedule_id ?? ''), 'dose_logs: schedule_id must be a UUID');
    // A dose is answered once; a second phone answering the same dose is ignored.
    await db.query(
      `INSERT INTO dose_logs (id, user_id, schedule_id, scheduled_at, status, responded_at, updated_at)
       SELECT $1,$2,$3,$4,$5,$6,$7
       WHERE EXISTS (SELECT 1 FROM schedules WHERE id = $3 AND user_id = $2)
       ON CONFLICT DO NOTHING`,
      [l.id, userId, l.schedule_id, String(l.scheduled_at), String(l.status), l.responded_at ?? l.updated_at, l.updated_at],
    );
  }

  for (const r of rows(changes, 'lab_reports')) {
    const saved = await db.query(
      `INSERT INTO lab_reports (id, user_id, title, report_date, lab_name, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6)
       ON CONFLICT (id) DO UPDATE SET
         title = EXCLUDED.title, report_date = EXCLUDED.report_date, lab_name = EXCLUDED.lab_name,
         updated_at = EXCLUDED.updated_at, deleted = false, rev = nextval('sync_rev')
       WHERE lab_reports.user_id = $2 AND lab_reports.updated_at <= EXCLUDED.updated_at
       RETURNING id`,
      [r.id, userId, String(r.title ?? ''), String(r.report_date).slice(0, 10), String(r.lab_name ?? ''), r.updated_at],
    );
    if (saved.rowCount === 0) continue; // older than what we have, or not this user's
    await db.query('DELETE FROM lab_results WHERE report_id = $1', [r.id]);
    for (const x of r.results ?? []) {
      await db.query(
        `INSERT INTO lab_results (report_id, user_id, name, test_key, value, value_text, unit, ref_low, ref_high, panel)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [r.id, userId, String(x.name ?? ''), String(x.test_key ?? ''), num(x.value), String(x.value_text ?? ''),
          String(x.unit ?? ''), num(x.ref_low), num(x.ref_high), String(x.panel ?? '')],
      );
    }
  }

  check(Array.isArray(deletes), 'deletes must be an array');
  for (const d of deletes) {
    check(TABLES.includes(d?.table) && UUID.test(d?.id ?? ''), 'deletes: need a known table and a UUID id');
    await db.query(
      `UPDATE ${d.table} SET deleted = true, updated_at = now(), rev = nextval('sync_rev')
       WHERE id = $1 AND user_id = $2 AND NOT deleted`,
      [d.id, userId],
    );
  }
}

/** Every row of `userId` changed after `cursor`, plus the new cursor. */
export async function pull(db, userId, cursor = 0) {
  check(Number.isInteger(cursor) && cursor >= 0, 'cursor must be a non-negative integer');
  const changes = {};
  const deletes = [];
  let maxRev = cursor;

  for (const table of TABLES) {
    const { rows: found } = await db.query(
      `SELECT * FROM ${table} WHERE user_id = $1 AND rev > $2 ORDER BY rev`,
      [userId, cursor],
    );
    changes[table] = [];
    for (const row of found) {
      maxRev = Math.max(maxRev, Number(row.rev));
      const { user_id: _u, rev: _r, deleted, ...data } = row;
      if (deleted) deletes.push({ table, id: row.id });
      else changes[table].push(data);
    }
  }

  const reportIds = changes.lab_reports.map((r) => r.id);
  if (reportIds.length) {
    const { rows: results } = await db.query(
      `SELECT report_id, name, test_key, value, value_text, unit, ref_low, ref_high, panel
       FROM lab_results WHERE report_id = ANY($1) ORDER BY id`,
      [reportIds],
    );
    for (const report of changes.lab_reports) {
      report.results = results.filter((x) => x.report_id === report.id).map(({ report_id: _, ...x }) => x);
    }
  }

  return { cursor: maxRev, changes, deletes };
}
