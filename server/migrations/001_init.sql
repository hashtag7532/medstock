-- MedStock schema. Every row belongs to one user; synced tables carry
-- `rev` (a global, increasing change number) so clients can pull
-- "everything changed since rev N", and `deleted` for soft deletes.

CREATE SEQUENCE sync_rev;

CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid  text NOT NULL UNIQUE,
  phone         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE medicines (
  id            uuid PRIMARY KEY,               -- generated on the device
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  brand_name    text NOT NULL,
  ingredients   jsonb NOT NULL DEFAULT '[]',    -- [{name, strength}]
  form          text NOT NULL,
  expiry        text,                           -- 'YYYY-MM' (Indian packs print month + year)
  batch_number  text NOT NULL DEFAULT '',
  manufacturer  text NOT NULL DEFAULT '',
  quantity      integer NOT NULL DEFAULT 0,
  unit          text NOT NULL,
  uses          text NOT NULL DEFAULT '',
  created_at    timestamptz NOT NULL,
  updated_at    timestamptz NOT NULL,
  deleted       boolean NOT NULL DEFAULT false,
  rev           bigint NOT NULL DEFAULT nextval('sync_rev')
);
CREATE INDEX medicines_user_rev ON medicines (user_id, rev);

CREATE TABLE schedules (
  id             uuid PRIMARY KEY,
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  medicine_id    uuid NOT NULL REFERENCES medicines(id) ON DELETE CASCADE,
  dose           integer NOT NULL,
  times          jsonb NOT NULL,                -- ["08:00", "21:00"]
  start_date     text NOT NULL,                 -- local date-time the course starts
  duration_days  integer,                       -- null = ongoing
  instructions   text NOT NULL DEFAULT '',
  status         text NOT NULL,                 -- active | stopped | completed
  updated_at     timestamptz NOT NULL,
  deleted        boolean NOT NULL DEFAULT false,
  rev            bigint NOT NULL DEFAULT nextval('sync_rev')
);
CREATE INDEX schedules_user_rev ON schedules (user_id, rev);

CREATE TABLE dose_logs (
  id            uuid PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  schedule_id   uuid NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
  scheduled_at  text NOT NULL,                  -- local dose time, e.g. 2026-10-18T21:00:00.000
  status        text NOT NULL,                  -- taken | skipped
  responded_at  timestamptz NOT NULL,
  updated_at    timestamptz NOT NULL,
  deleted       boolean NOT NULL DEFAULT false,
  rev           bigint NOT NULL DEFAULT nextval('sync_rev'),
  UNIQUE (schedule_id, scheduled_at)            -- one answer per dose, even from two phones
);
CREATE INDEX dose_logs_user_rev ON dose_logs (user_id, rev);

CREATE TABLE lab_reports (
  id            uuid PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title         text NOT NULL,
  report_date   date NOT NULL,
  lab_name      text NOT NULL DEFAULT '',
  updated_at    timestamptz NOT NULL,
  deleted       boolean NOT NULL DEFAULT false,
  rev           bigint NOT NULL DEFAULT nextval('sync_rev')
);
CREATE INDEX lab_reports_user_rev ON lab_reports (user_id, rev);

-- Replaced as a whole whenever its report is saved.
CREATE TABLE lab_results (
  id          bigserial PRIMARY KEY,
  report_id   uuid NOT NULL REFERENCES lab_reports(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  test_key    text NOT NULL,                    -- lines up the same test across labs
  value       double precision,
  value_text  text NOT NULL DEFAULT '',
  unit        text NOT NULL DEFAULT '',
  ref_low     double precision,
  ref_high    double precision,
  panel       text NOT NULL DEFAULT ''
);
CREATE INDEX lab_results_user_test ON lab_results (user_id, test_key);
CREATE INDEX lab_results_report ON lab_results (report_id);
