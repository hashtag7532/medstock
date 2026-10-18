import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { pool } from './db.js';

// Verifying ID tokens only needs the project ID. When FIREBASE_AUTH_EMULATOR_HOST
// is set, firebase-admin accepts tokens issued by the local Auth emulator instead.
initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID ?? 'demo-medstock' });

/**
 * Express middleware: requires `Authorization: Bearer <Firebase ID token>`,
 * creates the user row on first sight, and sets req.user = {id, firebaseUid, phone}.
 */
export async function requireUser(req, res, next) {
  const header = req.get('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'missing_token' });

  let decoded;
  try {
    decoded = await getAuth().verifyIdToken(token);
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }
  if (!decoded.phone_number && process.env.REQUIRE_PHONE !== 'false') {
    return res.status(403).json({ error: 'phone_login_required' });
  }

  const { rows } = await pool.query(
    `INSERT INTO users (firebase_uid, phone) VALUES ($1, $2)
     ON CONFLICT (firebase_uid) DO UPDATE SET last_seen_at = now(), phone = COALESCE(EXCLUDED.phone, users.phone)
     RETURNING id, phone`,
    [decoded.uid, decoded.phone_number ?? null],
  );
  req.user = { id: rows[0].id, firebaseUid: decoded.uid, phone: rows[0].phone };
  next();
}
