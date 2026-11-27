# OUTLINE: final paper (draft structure, not final text)

> Limits: **2,000 words max** and **fewer than 10 figures + tables combined**.
> Judging: Football 30, Data Science 30, Writeup 20, Data Viz 20.
> Word budgets below add up to exactly 2,000. Aim for about 1,900 so captions and titles fit. Delete this box before submitting.
>
> **Edited Nov 26 (Ava):**
> - Word budgets trimmed (the first version added up to about 2,200).
> - Writing split updated to the one we discussed: Ava writes Sections 1, 2 and 6; Savannah writes Sections 3 and 7; we write 4, 5 and 8 together.
> - The bar chart moved up to the Introduction as the "at a glance" picture, and the figures were renumbered. In-game bend moved from Section 5 to Section 7.
> - The Section 6 → 7 reference in the intro was fixed.

---

# Bend: Putting a Number on the Pass Rusher's Most Famous Trait

**One-sentence pitch:** We turned "bend," the trait scouts most often talk about in pass rushers, into a number for the first time, and showed it predicts NFL pressure beyond draft position, size and role.

## 1. Introduction (~200 words) — Ava

- What bend is: an edge rusher running a tight curve at full speed while leaning in to get around the tackle (the motorcycle comparison).
- Scouts judge it by eye; nobody has a number for it.
- The run the hoop drill is designed to test bend, but until now it was only watched, not measured.
- Our question: does Combine bend predict how often a lineman pressures the QB in regular-season NFL games, beyond what teams already know?
- Headline answer: yes. One step above his class in bend ≈ +0.76 points of pressure rate (≈ 11% more pressures), p = 0.011.
- **Figure 1 (the "at a glance" picture):** `output/B_05_adjusted_pressure_by_bend_group.png`. Low 6.7%, middle 6.1%, high 8.3%: the best benders stand out. A coach gets the point in 3 seconds, before any details.
- Honesty up front: we found bend in a search of about 700 tests (Section 7).

## 2. Measuring Bend at the Combine (~400 words) — Ava

- The drill: a figure-8 around two hoops, then a sprint out; 109 DL; 10 ran it twice (averaged).
- Bend = peak sideways acceleration (speed × turn rate), turns counted in both directions, frames under 1.5 yd/s ignored.
- Peak happens on the loops (113 of 119 tries), so it measures real bend.
- Graded within draft year (`bend_z`), because the 2024 class was higher.
- **Figure 2:** `output/A_hoop_path.png` (ideally a high-bend vs. low-bend player side by side).
- Is bend just "small and fast"? Weight r = −0.43, 40 time r = −0.48; weight + 40 + athleticism explain only 23% of bend.
- **Figure 3:** `output/A_bend_vs_weight.png`.

## 3. Measuring NFL Pass Rush (~300 words) — Savannah (trimmed from `writeup/B_section.md`)

- Pressure rate, regular season 2023–2025: 33,513 rushes, 98 DL, 8.1% overall.
- 69 with ≥100 rushes, 63 of those ran the hoop → main analysis.
- Shrunk pressure rate as a luck check (k ≈ 183; 62% of own rate kept at 297 rushes).
- Edge share as the role control.
- Trim: keep definitions and sample. The in-game bend material moves to Section 7.

## 4. Main Result: Bend Predicts Pressure (~250 words) — together (Ava drafts, Savannah edits; C_join_and_model.R)

- Model: pressure rate ~ bend_z + draft year + log(draft pick) + weight + edge share; 63 DL; undrafted = pick 260.
- **Table 1:** main model coefficients (bend +0.76, p = 0.011; log pick −0.91, p = 0.010; others n.s.; R² = 0.36).
- Bend is about as strong as draft position, which already reflects everything scouts know.
- **Figure 4 (the main chart, the evidence):** `output/B_05_adjusted_pressure_vs_bend.png`.
- Refer back to Figure 1 for the simple version.
- Probably an underestimate: teams put good benders on the edge, so controlling for edge share removes some of bend's real effect.

## 5. Robustness Checks (~150 words) — together (Ava drafts, Savannah edits)

- Shrunk pressure rate: p = 0.013.
- Every draft class positive (r = 0.43, 0.37, 0.47).
- Edge vs. interior split: same direction in both; interior p = 0.017 (30), edge p = 0.25 (33). Small groups.
- Adds to the NFL athleticism score (p = 0.03).

## 6. Hidden Talent and Possible Busts (~300 words) — Ava

- Pressure over draft-slot expectation; r = 0.43 with bend.
- **Figure 5:** `output/A_hidden_talent.png`.
- **Table 2:** gems and busts (shorten to the top 4–5 of each).
  - Gems: Cedric Johnson (R6, 12.9% vs 6.9% expected), Javon Solomon (R5, 12.2% vs 7.1%), Adetomiwa Adebawore (highest bend, beat his R4 slot).
  - Busts: Darius Robinson (R1, lowest bend, 2.4% vs 8.7%).
  - Exceptions: Jared Verse, Will McDonald (low bend, still productive).
- These are illustrations, not a separate test (same 63 players, cutoffs chosen by hand).

## 7. In-Game Bend, Limitations and How We Found This (~250 words) — Savannah

- In-game bend: role-adjusted game bend predicts pressure (p = 0.022), but Combine bend only weakly predicts game bend (p = 0.30 with controls). The hoop has no blocker. Main claim stays Combine → pressure.
- Found in a search of about 700 tests across WR, OL and DL. Bend was the one candidate with a clear football reason that survived the checks, but it does not pass a strict multiple-testing correction. Promising, not proven.
- Weak spots: doesn't predict sack rate; dropping single players moves t from 1.85 to 3.03.
- 63 players; 2025 rookies have one season.
- Pressure depends on teammates, coverage and the QB.
- Edge/interior is a two-way label.
- Next steps: more draft classes, other drills, bend vs. a blocker.

## 8. How Teams Could Use It (~150 words) — together

- An objective extra signal for pass rushers, most useful when it disagrees with where a player is projected to go.
- Cheap: it comes from a drill every DL already runs.
- One tool among several (power, hands, first step aren't captured).

---

**Words:** 200 + 400 + 300 + 250 + 150 + 300 + 250 + 150 = 2,000. By person: Ava about 900 (Sections 1, 2, 6), Savannah about 550 (Sections 3, 7), together about 550 (Sections 4, 5, 8).
**Figures and tables:** 5 figures + 2 tables = 7 (limit < 10).
**If we need to cut a figure:** cut Figure 1 (the bar chart) first, since Figure 4 shows the same result in more detail. Keep in mind that Figures 3, 4 and 5 are all scatter plots, so the bar chart also adds variety.
**Not in the paper:** WR slant work (B_01, B_02, A_01–A_03); `C_pressure_by_bend_group.png` (replaced by the adjusted version).
**Files:** Ava drafts in `writeup/A_section.md`, Savannah in `writeup/B_section.md`, and Savannah assembles this file at the end. First drafts by Dec 8.
