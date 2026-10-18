# MedStock — Product Note

*v1 prototype · October 2026 · Owner: Parth Dodia*

**In one line:** MedStock knows which medicines a family already has, how much is left, when each expires and what their latest blood tests say. It is built to sit on top of a business that already sells medicines and tests (an e-pharmacy, a diagnostics chain, a hospital pharmacy), turning that knowledge into timely repeat orders and lab bookings.

**What success means:** revenue the client would not otherwise have earned, from orders and lab bookings that start in MedStock.

---

## 1. The problem

Medicines in Indian homes are bought for one illness, partly used, and forgotten in a drawer. The household's memory of what it has, and whether it's still good, fails at exactly the moments that matter.

| Moment | What happens today | Cost |
|---|---|---|
| **About to buy** | Nobody remembers the half strip at home, or that a different brand is the same drug | Duplicate purchases, money wasted |
| **Someone is unwell, often at night** | Rummaging through a drawer, guessing from brand names | Delay; sometimes an expired medicine is taken |
| **Medicines expire** | Found by accident, if at all; cut strips lose their printed date | Waste, risk of taking expired stock |
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

**Business TG (who would integrate this):** e-pharmacies, diagnostic lab chains, hospital chains with retail pharmacy, and health insurers with wellness apps. For them, MedStock is a layer that brings customers back between purchases and turns household health moments into orders and bookings (section 3).

## 3. Where MedStock fits

MedStock is a **retention and cross-sell layer for a medicine and diagnostics business.** The client already owns the supply chain: the pharmacy, the delivery network, the labs. MedStock is the consumer-facing layer that keeps that business present in the user's life between purchases, and turns household health moments into orders.

### 3.1 What it connects to

MedStock doesn't need to integrate the supply chain itself. It needs three connections to a client who has one:

| Connection | What it does | Effort |
|---|---|---|
| **Orders in** | Every medicine the user buys from the client lands in the cabinet with brand, batch, expiry and quantity, with no scanning | An order-history API |
| **Lab results in** | Results from the client's labs arrive as structured data and feed the trend views directly | A results API (or ABHA/ABDM) |
| **Orders and bookings out** | A refill, the missing medicines from a prescription, a re-test: each opens the client's cart or booking flow, pre-filled | Deep links into existing checkout |

These are a handful of APIs, not supply-chain work. The client's vertical integration (selling the medicine, running the lab, holding the record) is the advantage; MedStock is how that advantage reaches the user.

### 3.2 Why the connection matters

The same three connections solve MedStock's own hardest problems:

- **Onboarding:** orders and lab results fill the app with no effort from the user (section 6).
- **Data going stale:** every purchase and every test keeps the record current.
- **Monetisation:** revenue comes from the client's orders and bookings, never from ads or from selling health data.
- **Frequency:** the user returns for doses, expiries and reports, and the client is in front of them when the next need comes up.

## 4. How it drives revenue for the client

### 4.1 Cross-selling at the right moment, not with ads

Every revenue loop starts from something the user already did in MedStock:

| Trigger in MedStock | Order or booking for the client |
|---|---|
| Course will run short ("need 6, have 4") | One-tap order of the missing quantity |
| Ongoing medicine about to run out | Refill reminder and reorder, or a subscription |
| Prescription scanned, medicine not at home | "Order these 2" with the prescription already attached |
| Medicine expired | Replace it, plus disposal guidance |
| Annual check-up due (a year since the last report) | Book the same package again, home sample collection |
| Dengue: daily CBC being uploaded | Book tomorrow's home collection; results land in the app automatically |
| Report value outside range | Book a teleconsult with the report attached (no diagnosis from the app) |

These are services, not promotions: each one completes something the user was already doing, which is why they convert.

### 4.2 Habit is the input, orders are the output

Pharmacy and diagnostics apps are opened only when someone needs to buy. MedStock adds reasons to come back in between, and each visit is a chance for one of the triggers above:

| Reason to come back | How often |
|---|---|
| Dose reminders (Yes / Skipped / Stopped) | Daily while a course is running |
| "Do we have something for this?" | Whenever someone in the family is unwell |
| Checking before buying | Every purchase, including at offline chemists |
| Expiry clean-up | Monthly |
| Viewing test reports and trends | After every test; daily during an acute episode |

Engagement is tracked as a leading indicator, not as the goal (section 10).

### 4.3 What the client gains beyond orders

- **Demand signals:** courses ending, refills due and expiries coming up help with inventory planning and delivery batching.
- **Trust that brings the next order:** "You already have this, don't buy it" costs one sale and earns loyalty. It's tracked honestly as a guardrail (section 10).
- **A health record that keeps customers:** a family whose medicines and five years of reports live in the client's app is unlikely to move to a competitor.

### 4.4 The flywheel

```
  Orders and lab tests ──fill──▶ accurate cabinet and health record
          ▲                                   │
          │                                   ▼
   timely, relevant                 reasons to come back
   next steps (refill,              (doses, "do we have it?",
   re-test, consult)                 expiry, trends)
          ▲                                   │
          └──────── trust and habit ◀─────────┘
```

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
- **Expiry clean-up** doubles as a review: removing expired items cleans the list.
- **Activation** is defined in section 7.3: a useful record plus one order or booking started from MedStock.

## 7. Acquisition and activation

v1 is built from the product side. An early product also has to answer two questions: how do users arrive, and what makes them do the work of adding medicines and reports?

### 7.1 Acquisition: arrive already activated

The cheapest and strongest channels come through the client's existing customers and give the user something useful on day one:

| Channel | How it works | Why it activates |
|---|---|---|
| **Lab reports delivered into MedStock** | "Your report is ready. View it with your past results" opens MedStock with the report already there | First value with zero effort: a report, and a trend from the second test onward |
| **Order delivered → "Track these medicines"** | The invoice adds every item to the cabinet with one tap | Cabinet starts full, with expiry dates |
| **At checkout** | "You have 8 of these at home" badge in the cart; tap to see the cabinet | Shows value at the moment of purchase |
| **Prescription upload in the pharmacy flow** | Users already upload prescriptions to order; offer reminders and schedules from it | Doses start the same day |
| **Referral** | Invite a family member; both get store credit after the new user's first order | Caregivers bring their parents |

### 7.2 Incentives: reward actions that lead to orders

Incentives help, but rewarding the raw number of items added gets gamed (the same strip scanned five times, random photos) and pays for data that never turns into revenue. The design rules:

1. **Reward the action closest to a purchase.** The best rewards are themselves the conversion.
2. **Pay in store credit, redeemable on the next order or booking**, never cash. The reward then brings back an order.
3. **Verify before rewarding:** unique medicines (deduplicated by brand and batch) with a valid expiry; reports that parse as real lab reports with a date and results.
4. **Cap and expire:** a lifetime cap per user, credits that expire in 30–60 days, a minimum order value.
5. **Never make health-data sharing a condition of service.** Rewards are an extra; consent stays freely given (DPDP Act).

| Action | Reward | Why it pays back |
|---|---|---|
| **Scan a prescription** | Discount on ordering the medicines not at home | The reward is the order |
| **First lab report added** | Discount on the next lab test | Brings the next booking to the client |
| **Expiry clean-up** (remove expired items) | Discount on replacing them | Replacement orders, plus a cleaner cabinet |
| **First 5 medicines added** | Small credit on the next order (one time) | Gets users past the empty-cabinet stage |
| **Course completed with doses answered** | Credit towards the refill of an ongoing medicine | Refill order; better data |
| **Referral** | Credit for both, after the friend's first order | Paid only when it produces revenue |

### 7.3 Activation

A user is **activated** when they have a useful record *and* have acted on one trigger:

- 5+ medicines or 1+ lab report in the app, **and**
- one order or booking started from a MedStock prompt, within 30 days of joining.

The second half matters: a full cabinet that never leads to an order is a cost, not a customer.

### 7.4 Do the incentives pay for themselves?

Each reward should clear a simple test before launch:

```
reward cost  <  (extra orders it causes) × (average order value) × (gross margin)
```

"Extra orders it causes" is measured against a holdout group that sees no reward. Rewards that don't pass are cut, however popular.

## 8. Features we should not build, and why

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
| **Rewards for the number of items added, or cash rewards** | Easy to game, pays for data that never becomes revenue; rewards should be store credit tied to an order (section 7.2). |
| **Long manual entry forms** | Every required field cuts completion. Capture from photos and orders; make manual entry optional. |
| **Smart pill boxes or other hardware** | Expensive, slow to iterate, small market; the phone already does reminders. |
| **Telemedicine inside this module** | It belongs to the platform. MedStock should hand off to it with context (the report attached), not rebuild it. |

## 9. Future enhancements

| Priority | Enhancement | Why |
|---|---|---|
| **Next** | Auto-add from platform orders and invoices | Removes the biggest onboarding friction |
| **Next** | Bill / invoice photo import | Bulk onboarding for purchases from offline chemists |
| **Next** | Backup of label photos and report files | Today only extracted data syncs |
| **Next** | Expiry and low-stock notifications | Monthly and weekly reasons to return |
| **Next** | Refill and reorder from the course card | The first cross-sell loop |
| **Soon** | Lab booking with results flowing straight into Trends | Closes the diagnostics loop (dengue, annual check-ups) |
| **Soon** | Drug database (brand → composition, uses, Rx status) | Better matching, safer same-composition matches, real symptom search |
| **Soon** | Duplicate-ingredient warning (e.g. paracetamol in a cold tablet and in Dolo) | High safety value from data we already have |
| **Later** | ABHA / ABDM integration (link health records from labs and hospitals) | Reports arrive without uploading; India's digital health rails |
| **Later** | Disposal guidance and drop-off points for expired medicines | Responsible end of life |
| **Later** | Insurance: claims documents, wellness programmes | Partnership revenue |

## 10. Metrics

### 10.1 North star: MedStock-driven revenue

**Revenue from orders and lab bookings that start from a MedStock prompt**, per active user per month, measured as **incremental** revenue against a holdout group of the client's customers who don't get MedStock.

- **Attributed revenue:** an order or booking within 7 days of a MedStock prompt (refill, missing medicines, re-test, replacement), or started from a MedStock button.
- **Incremental revenue:** how much more MedStock users spend than the holdout group. This is the number that justifies MedStock, since some attributed orders would have happened anyway.

### 10.2 Revenue drivers

| Metric | What it tells you |
|---|---|
| Prompt → order conversion, by trigger (refill, prescription, re-test, expiry) | Which loops earn money; where to invest |
| Repeat purchase rate vs. holdout | Whether MedStock keeps customers buying |
| Lab re-booking rate vs. holdout | Whether report trends bring the next test |
| Revenue per activated user (first 90 days) | Value of getting a user activated |
| Incentive ROI per reward type (section 7.4) | Which rewards to keep |

### 10.3 Leading indicators

Engagement and data quality predict revenue, but aren't the goal.

| Metric | Target to test |
|---|---|
| Activation (section 7.3) | 25% of new users within 30 days |
| Time to add 10 medicines | Under 3 minutes |
| Scan accuracy: expiry and composition right without edits | 90% / 85% |
| Weekly active users (any check, dose answer or report view) | 30% |
| Dose reminders answered | 60% |

### 10.4 Guardrails

| Metric | Why |
|---|---|
| Duplicate purchases avoided ("you already have this") | A deliberate short-term revenue cost that builds trust; report it, don't hide it |
| Incentive cost per activated user | Keeps acquisition spend honest |
| Notification opt-outs and mutes | Too many prompts kill the channel that drives revenue |
| Data-deletion requests and complaints | Early warning that cross-selling feels intrusive |

All targets are starting assumptions to be reset after the first pilot.

## 11. Risks

| Risk | Mitigation |
|---|---|
| Regulation (CDSCO software as a medical device, DPDP Act for health data) | The "don't build" list above; explicit consent; data deletion; legal review before launch |
| Wrong extraction (expiry or strength misread) | Mandatory confirm screen; flag low-confidence fields; prompt to rescan |
| Stale data erodes trust | Auto-capture from orders; dose logging; expiry clean-up; show counts as approximate |
| Feels like an upsell machine | Cross-sell only from the user's own trigger; never from inferred health data without consent |
| Incentives get gamed or cost more than they earn | Store credit only, deduplication and verification, caps and expiry, a holdout test for every reward |
| Revenue attributed to MedStock that would have happened anyway | Measure against a holdout group; report incremental revenue, not just attributed |
| AI cost per scan | On-device OCR first, AI only for hard cases; structured data from orders and labs needs no AI |

## Appendix: what v1 already does

Scan packs (on-device OCR or Claude vision) with a confirm step; cabinet sorted by expiry; check before buying (same brand or exact composition); "commonly used for" search; dose schedules with Yes / Skipped / Stopped reminders that reduce stock; prescription scan to schedules; lab reports from photos or PDFs with values, ranges, comparison and trend charts; phone OTP login (Firebase); per-user storage on the phone, synced to a PostgreSQL backend. See [`README.md`](../README.md) and [`user-journeys.md`](user-journeys.md).
