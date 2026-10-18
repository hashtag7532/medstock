// End-to-end tests. Need PostgreSQL, the Auth emulator (npm run emulator)
// and the API (npm start) running locally.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';

const API = process.env.API_URL ?? 'http://localhost:8080';
const EMU = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099'}`;
const PROJECT = process.env.FIREBASE_PROJECT_ID ?? 'demo-medstock';

async function json(res) {
  const body = await res.json();
  if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(body)}`);
  return body;
}

/** Signs in with phone OTP through the emulator, exactly like the app does. */
async function login(phone) {
  const idt = `${EMU}/identitytoolkit.googleapis.com/v1`;
  const { sessionInfo } = await json(await fetch(`${idt}/accounts:sendVerificationCode?key=demo`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ phoneNumber: phone, recaptchaToken: 'emulator' }),
  }));
  const { verificationCodes } = await json(await fetch(`${EMU}/emulator/v1/projects/${PROJECT}/verificationCodes`));
  const code = verificationCodes.filter((c) => c.sessionInfo === sessionInfo).at(-1).code;
  const { idToken } = await json(await fetch(`${idt}/accounts:signInWithPhoneNumber?key=demo`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ sessionInfo, code }),
  }));
  return idToken;
}

const sync = async (token, body) => json(await fetch(`${API}/v1/sync`, {
  method: 'POST',
  headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
  body: JSON.stringify(body),
}));

const randomPhone = () => `+9198${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`;

test('rejects requests without a valid token', async () => {
  assert.equal((await fetch(`${API}/v1/me`)).status, 401);
  assert.equal((await fetch(`${API}/v1/me`, { headers: { authorization: 'Bearer nope' } })).status, 401);
});

test('a second device gets everything the first one pushed', async () => {
  const token = await login(randomPhone());
  const now = new Date().toISOString();
  const med = { id: randomUUID(), brand_name: 'Dolo 650', ingredients: [{ name: 'Paracetamol', strength: '650 mg' }],
    form: 'tablet', expiry: '2028-04', quantity: 15, unit: 'tablets', uses: 'Fever and mild pain', created_at: now, updated_at: now };
  const sched = { id: randomUUID(), medicine_id: med.id, dose: 1, times: ['08:00', '21:00'], start_date: '2026-10-18T11:18:00.000',
    duration_days: 5, instructions: 'After food', status: 'active', updated_at: now };
  const log = { id: randomUUID(), schedule_id: sched.id, scheduled_at: '2026-10-18T21:00:00.000', status: 'taken', responded_at: now, updated_at: now };
  const report = { id: randomUUID(), title: 'CBC', report_date: '2026-10-15T00:00:00.000', lab_name: 'City Lab', updated_at: now,
    results: [{ name: 'Platelet count', test_key: 'plateletcount', value: 85000, unit: '/uL', ref_low: 150000, ref_high: 410000, panel: 'CBC' }] };

  const first = await sync(token, { cursor: 0, changes: { medicines: [med], schedules: [sched], dose_logs: [log], lab_reports: [report] } });
  assert.ok(first.cursor > 0);

  const fresh = await sync(token, { cursor: 0 });
  assert.equal(fresh.changes.medicines.length, 1);
  assert.equal(fresh.changes.medicines[0].brand_name, 'Dolo 650');
  assert.deepEqual(fresh.changes.schedules[0].times, ['08:00', '21:00']);
  assert.equal(fresh.changes.dose_logs[0].status, 'taken');
  assert.equal(fresh.changes.lab_reports[0].report_date, '2026-10-15');
  assert.equal(fresh.changes.lab_reports[0].results[0].value, 85000);

  // Nothing new since the latest cursor.
  const again = await sync(token, { cursor: fresh.cursor });
  assert.equal(again.changes.medicines.length + again.deletes.length, 0);

  const me = await json(await fetch(`${API}/v1/me`, { headers: { authorization: `Bearer ${token}` } }));
  assert.deepEqual(me.counts, { medicines: 1, schedules: 1, dose_logs: 1, lab_reports: 1 });
});

test('newest edit wins, older edits are ignored, deletes propagate', async () => {
  const token = await login(randomPhone());
  const t0 = '2026-10-18T10:00:00.000Z', t1 = '2026-10-18T11:00:00.000Z', t2 = '2026-10-18T12:00:00.000Z';
  const med = { id: randomUUID(), brand_name: 'Azee 500', form: 'tablet', quantity: 3, unit: 'tablets', created_at: t0, updated_at: t0 };
  const { cursor } = await sync(token, { cursor: 0, changes: { medicines: [med] } });

  await sync(token, { cursor, changes: { medicines: [{ ...med, quantity: 2, updated_at: t2 }] } }); // newer
  await sync(token, { cursor, changes: { medicines: [{ ...med, quantity: 9, updated_at: t1 }] } }); // stale phone
  const after = await sync(token, { cursor: 0 });
  assert.equal(after.changes.medicines[0].quantity, 2);

  const deleted = await sync(token, { cursor: after.cursor, deletes: [{ table: 'medicines', id: med.id }] });
  assert.deepEqual(deleted.deletes, [{ table: 'medicines', id: med.id }]);
});

test("users never see each other's data", async () => {
  const alice = await login(randomPhone());
  const bob = await login(randomPhone());
  const now = new Date().toISOString();
  const med = { id: randomUUID(), brand_name: 'Private', form: 'tablet', unit: 'tablets', created_at: now, updated_at: now };
  await sync(alice, { cursor: 0, changes: { medicines: [med] } });

  // Bob can't read it, overwrite it or delete it.
  assert.equal((await sync(bob, { cursor: 0 })).changes.medicines.length, 0);
  await sync(bob, { cursor: 0, changes: { medicines: [{ ...med, brand_name: 'Hacked', updated_at: new Date(Date.now() + 1e6).toISOString() }] } });
  await sync(bob, { cursor: 0, deletes: [{ table: 'medicines', id: med.id }] });
  const mine = await sync(alice, { cursor: 0 });
  assert.equal(mine.changes.medicines[0].brand_name, 'Private');
  assert.equal(mine.deletes.length, 0);
});

test('rejects malformed sync bodies', async () => {
  const token = await login(randomPhone());
  const res = await fetch(`${API}/v1/sync`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify({ changes: { medicines: [{ id: 'not-a-uuid' }] } }),
  });
  assert.equal(res.status, 400);
});
