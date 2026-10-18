# MedStock — Product Note

*v1 prototype · October 2026 · Owner: Parth Dodia*

**In one line:** MedStock knows which medicines a family already has, how much is left, when each expires and what their latest blood tests say. On its own that is a weak business. Inside a pharmacy, diagnostics or health platform, it gives users a reason to open the app every week and leads naturally to repeat medicine orders and lab bookings.

---

## 1. The problem

Medicines in Indian homes are bought for one illness, partly used, and forgotten in a drawer. The household's memory of what it has, and whether it's still good, fails at exactly the moments that matter.

| Moment | What happens today | Cost |
|---|---|---|
| **About to buy** | Nobody remembers the half strip at home, or that a different brand is the same drug | Duplicate purchases, money wasted |
| **Someone is unwell, often at night** | Rummaging through a drawer, guessing from brand names | Delay; sometimes an expired medicine is taken |
| **Medicines expire** | Found by accident, if at all; cut strips lose their printed date | Waste, risk of taking expired stock |
| **A course is prescribed** | Doses are remembered (or not); nobody knows when stock will run out | Missed doses, last-minute runs to the chemist |
| **Tests are repeated** | Reports sit across WhatsApp, email, paper and lab apps | No way to see a trend: daily platelets in dengue, HbA1c year on year |

The underlying problem is that nothing in the home keeps an up-to-date record of what medicines are there or what the test history looks like. People rely on memory, paper and scattered chats.

## 2. Target group

**Primary: the family health manager.** An urban adult, roughly 28 to 45, who buys and organises medicines for the household. That often includes elderly parents with ongoing prescriptions (BP, diabetes, thyroid), sometimes in another city. They feel the problem most because they handle several people and many medicines, and they are the one who will do the setup work.

**Secondary users**

| Group | Situation | What they get |
|---|---|---|
| Households with young children | Fever and cough at night; many syrups, many half-used bottles | "What do we have for this, and is it still good?" |
| People on long-term medicines | Daily tablets that run out monthly | Dose reminders that keep the count right, refill warnings |
| Acute episodes (dengue, typhoid, COVID) | Daily blood tests for a week or two | One place to upload reports and see the trend |
| Annual check-up takers | One big report a year | Year-on-year comparison without digging up last year's PDF |

**Business TG (who would integrate this):** e-pharmacies, diagnostic lab chains, hospital chains with retail pharmacy, and health insurers with wellness apps. For them, MedStock is a feature that increases engagement and repeat orders. It isn't something they'd buy as a standalone product.

## 3. Why this is not a standalone product

The honest assessment: as an independent app, MedStock would struggle.

- **Low natural frequency.** Someone checks their medicine cabinet only a few times a month. A utility opened that rarely gets uninstalled or forgotten.
- **No willingness to pay.** Users won't pay a subscription to track their medicines, and the value of one avoided duplicate purchase is a few hundred rupees.
- **High onboarding cost, slow payoff.** The user does the work up front (adding every medicine) and sees the benefit weeks later, the next time they shop or fall ill. Most standalone apps lose users in exactly that gap (see section 6).
- **The data goes stale.** Without purchase data flowing in, the list drifts from reality, users stop trusting it, and they stop using it.
- **Monetising alone means ads or selling data.** Both are unacceptable for health data and would destroy trust.

So the value isn't in MedStock alone. It's in the moments it creates for a business that sells medicines and tests.

## 4. Why it is valuable inside a pharmacy or health platform

### 4.1 Frequency: a reason to open the app when not buying

Pharmacy and diagnostics apps are opened when someone needs to buy. MedStock adds reasons to open the app in between:

| Reason to open | How often |
|---|---|
| Dose reminders (Yes / Skipped / Stopped) | Daily while a course is running |
| "Do we have something for this?" | Whenever someone in the family is unwell |
| Checking before buying | Every purchase, including at offline chemists |
| Expiry clean-up | Monthly |
| Viewing test reports and trends | After every test; daily during an acute episode |

The app stops being "the place I buy from" and becomes "the place I manage the family's health from", and the buying follows.

### 4.2 Cross-selling at the right moment, not with ads

Each loop starts from something the user already did in MedStock:

| Trigger in MedStock | Natural next step for the platform |
|---|---|
| Course will run short ("need 6, have 4") | One-tap order of the missing quantity |
| Ongoing medicine about to run out | Refill reminder and reorder, or a subscription |
| Prescription scanned, medicine not at home | "Order these 2" with the prescription already attached |
| Medicine expired | Replace it, plus disposal guidance |
| Annual check-up due (a year since the last report) | Book the same package again, home sample collection |
| Dengue: daily CBC being uploaded | Book tomorrow's home collection; results land in the app automatically |
| Report value outside range | Book a teleconsult with the report attached (no diagnosis from the app) |

These are services, not promotions: each one completes something the user was already doing.

### 4.3 Vertical integration in the supply chain

When the same platform sells the medicine, runs the lab and holds the record, the loop closes and most of the data entry disappears:

- **Medicine orders fill the cabinet automatically.** Brand, batch, expiry and quantity come from the invoice, so nobody has to scan.
- **Lab results arrive as structured data** straight from the lab system, with no photo or PDF reading needed. They feed the trend views directly.
- **Demand signals** (courses ending, refills due, expiries coming up) help pharmacy inventory planning and delivery batching.
- **Fewer duplicate and wasted purchases** builds goodwill. The platform is the one that told you not to buy, which earns the trust that brings back the next order.

### 4.4 The flywheel

```
  Orders and lab tests ──fill──▶ accurate cabinet and health record
          ▲                                   │
          │                                   ▼
   timely, relevant                 daily/weekly reasons to open
   next steps (refill,              (doses, "do we have it?",
   re-test, consult)                 expiry, trends)
          ▲                                   │
          └──────── trust and habit ◀─────────┘
```

**What to measure for the business:** monthly active users and app opens per user (compared with users without MedStock), repeat purchase rate, refill conversion, lab re-booking rate, and duplicate purchases avoided (a goodwill metric).

## 5. How it fits into a user's life

MedStock should stay out of the way and show up only at the moments it's needed.

| Rhythm | Moment | What MedStock does |
|---|---|---|
| Every purchase | At the chemist or checkout | "You already have 8 Dolo 650 (expires Mar 2027)" |
| When ill | Fever at 11 pm | Search "fever": shows what's at home, in date, labelled for it |
| Daily (during a course) | Dose time | Reminder with Yes / Skipped / Stopped; stock goes down by itself |
| Weekly | Ongoing medicines | "Papa's BP tablets run out in 5 days" |
| Monthly | Expiry clean-up | "2 expired, 3 expire this month: use these first" |
| After any test | Report arrives | Values read, compared with last time, trend updated |
| Yearly | Annual check-up | "Last check-up was 12 months ago": book, then compare year on year |

**Design rule:** every notification must lead to something useful done in one tap (answer the dose, reorder, open the comparison). Anything else is noise and gets the app muted.

## 6. The hardest problem: getting the list in and keeping it right

This is the make-or-break problem. A cabinet that's 30% complete is useless ("it said we didn't have it, but we did"), and asking a new user to sit down and scan 25 strips is a request most people abandon.

### 6.1 Why onboarding is so hard

- **Effort first, reward later:** setup takes 10–20 minutes, and the payoff comes days or weeks later.
- **Physical hassle:** medicines are spread across drawers, bags and rooms; strips are cut, and boxes are thrown away.
- **Upkeep:** every dose taken, strip finished or new purchase changes the list. If upkeep is manual, the list is wrong within a week.

### 6.2 Principles

1. **Never ask for the whole list.** Let it build up through things the user does anyway.
2. **Show value from the first item.** The first scan should immediately show something useful, such as "expires in 3 months" or "same as Crocin".
3. **Accept approximate counts.** "About 8 left" is fine. Precision isn't worth the user's effort.
4. **Every source of data counts:** purchases, prescriptions, bills and dose logs, not just scans.

### 6.3 Ways in, from least effort to most

| Way in | Effort | Status |
|---|---|---|
| **Orders from the platform go into the cabinet automatically** | None | Future (needs the platform integration) |
| **Photo of a pharmacy bill or online invoice**: 5–15 medicines at once, with batch and expiry | One photo | Future (high priority) |
| **Prescription scan** creates schedules and adds missing medicines | One photo | Built |
| **Scan when you use it:** the first time someone reaches for a strip, they scan it | Seconds, spread over time | Built (scan + confirm) |
| **Drawer scan:** several strips in one photo for the first setup | One photo, then review | Future |
| **One family member sets it up** for everyone, through a shared household | One person's effort | Future (family sharing) |
| **Pharmacist adds the items at the counter** (partner chemists) | None for the user | Future (B2B) |

### 6.4 Keeping it right without effort

- **Dose answers reduce stock automatically** (built).
- **Orders add stock automatically** (future, with integration).
- **Gentle checks:** "Still have about 8 Dolo 650?" with Yes / Fewer / Finished buttons, at most weekly.
- **Expiry clean-up** doubles as a review: removing expired items cleans the list.
- **The first activation goal:** 10 medicines added within 7 days. Users who reach it are likely to stay; that threshold should be tested in the pilot.

## 7. Features we should not build, and why

| Don't build | Why |
|---|---|
| **Symptom checker or diagnosis** ("you probably have…") | Medical-device regulation (CDSCO), liability, and real harm if wrong. Show what's at home for a symptom and point to a doctor; never diagnose. |
| **Dosage advice or "take this instead" recommendations** | Prescribing is a doctor's job. Same-composition matches are shown with "check with your pharmacist", and never for antibiotics, prescription-only (Schedule H/H1) drugs or children's doses. |
| **AI interpretation of lab reports** ("your liver is fine") | Same regulatory and liability problem. Show values, ranges, trends and changes; leave interpretation to doctors. |
| **Ad-driven or data-driven upselling** (selling insights to pharma, targeted ads from health data) | Breaks trust and the DPDP Act's consent rules. Cross-selling only follows from the user's own action. |
| **Price comparison against other pharmacies** | Inside a pharmacy platform it works against the business; standalone it's a crowded, low-margin space. |
| **Streaks, badges and gamified adherence** | Pressure around taking medicines can cause harm (double doses to "catch up"). Reminders should stay neutral. |
| **Community, forums or social features** | Moderation burden, medical misinformation risk, no link to the core job. |
| **A general health chatbot** | Hard to keep safe, hard to make reliable, and it doesn't solve the cabinet problem. Use AI only for reading documents. |
| **A full medical record system** (every document type, vaccination cards, insurance cards) | Scope creep. Medicines and lab values are the high-frequency core; connect to ABHA/ABDM for wider records instead of rebuilding them. |
| **Long manual entry forms** | Every required field cuts completion. Capture from photos and orders; make manual entry optional. |
| **Smart pill boxes or other hardware** | Expensive, slow to iterate, small market; the phone already does reminders. |
| **Telemedicine inside this module** | It belongs to the platform. MedStock should hand off to it with context (the report attached), not rebuild it. |

## 8. Future enhancements

| Priority | Enhancement | Why |
|---|---|---|
| **Next** | Auto-add from platform orders and invoices | Removes the biggest onboarding friction |
| **Next** | Bill / invoice photo import | Bulk onboarding for purchases from offline chemists |
| **Next** | Backup of label photos and report files | Today only extracted data syncs |
| **Next** | Expiry and low-stock notifications | Monthly and weekly reasons to return |
| **Next** | Refill and reorder from the course card | The first cross-sell loop |
| **Soon** | Family / household sharing, caregiver mode for parents | The primary TG's real situation |
| **Soon** | Lab booking with results flowing straight into Trends | Closes the diagnostics loop (dengue, annual check-ups) |
| **Soon** | Drug database (brand → composition, uses, Rx status) | Better matching, safer same-composition matches, real symptom search |
| **Soon** | Duplicate-ingredient warning (e.g. paracetamol in a cold tablet and in Dolo) | High safety value from data we already have |
| **Later** | ABHA / ABDM integration (link health records from labs and hospitals) | Reports arrive without uploading; India's digital health rails |
| **Later** | Share a report or trend with a doctor via a time-limited link | Consultations with context |
| **Later** | Hindi and regional languages, large-text mode, WhatsApp reminders for elderly parents | Reach beyond English-first users |
| **Later** | Disposal guidance and drop-off points for expired medicines | Responsible end of life |
| **Later** | Insurance: claims documents, wellness programmes | Partnership revenue |

## 9. Success metrics for a pilot

| Metric | Target to test |
|---|---|
| Activation: 10+ medicines within 7 days | 40% of new users |
| Time to add 10 medicines | Under 3 minutes |
| Scan accuracy: expiry and composition right without edits | 90% / 85% |
| Weekly active households (any check, dose answer or report view) | 30% |
| Dose reminders answered | 60% |
| Opens per month vs. non-MedStock users of the same platform | +50% |
| Refill conversion from "running short" prompts | Track; no target yet |

These targets are starting assumptions to be reset after the first pilot.

## 10. Risks

| Risk | Mitigation |
|---|---|
| Regulation (CDSCO software as a medical device, DPDP Act for health data) | The "don't build" list above; explicit consent; data deletion; legal review before launch |
| Wrong extraction (expiry or strength misread) | Mandatory confirm screen; flag low-confidence fields; prompt to rescan |
| Stale data erodes trust | Auto-capture from orders; dose logging; light-touch checks; show counts as approximate |
| Feels like an upsell machine | Cross-sell only from the user's own trigger; never from inferred health data without consent |
| AI cost per scan | On-device OCR first, AI only for hard cases; structured data from orders and labs needs no AI |

## Appendix: what v1 already does

Scan packs (on-device OCR or Claude vision) with a confirm step; cabinet sorted by expiry; check before buying (same brand or exact composition); "commonly used for" search; dose schedules with Yes / Skipped / Stopped reminders that reduce stock; prescription scan to schedules; lab reports from photos or PDFs with values, ranges, comparison and trend charts; phone OTP login (Firebase); per-user storage on the phone, synced to a PostgreSQL backend. See [`README.md`](../README.md) and [`user-journeys.md`](user-journeys.md).
