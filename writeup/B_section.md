# Measuring NFL Pass Rush

## Pressure rate

We measured NFL performance with **pressure rate**: how often a defensive lineman pressures the quarterback per pass rush. We used regular-season games only (2023–2025), since the competition asks about regular-season performance and preseason snaps often come against backups.

- **A pass rush** is any play where the lineman has a recorded get-off time or a recorded time to pressure.
- **A pressure** is any rush with a recorded time to pressure. We also counted **fast pressures** (2.5 seconds or less) and **sacks** (half sacks count as 0.5).
- **Edge share** is the fraction of a player's rushes where he lined up on the edge rather than the interior.

This gives 33,513 pass rushes from 98 defensive linemen, with an overall pressure rate of 8.1%. We kept the **69 linemen with at least 100 rushes** so each player's rate rests on enough plays (median 297 rushes, median pressure rate 6.2%). Of those, **63 also ran the run the hoop drill**, and they form the main analysis.

## Separating skill from luck

Pressure on a single rush is mostly luck, so a player with a few hundred rushes can look better or worse than he really is. As a check, we also built a **shrunk pressure rate** that pulls each player toward the league average in proportion to how little we know about him. The data says to treat each player as if he also had about 183 average rushes, so a typical lineman with 297 rushes keeps about 62% of his own rate. Combine bend predicts the shrunk rate as well (p = 0.013, against p = 0.011 for the raw rate), so the main result is not driven by small samples.

## Does Combine bend show up in games?

We also measured bend on real NFL pass rushes, using the same method as the Combine drill. For each rush, from the snap until the pass, a sack or 3 seconds (whichever came first), we took the player's peak sideways acceleration: speed × turn rate. As at the Combine, frames slower than 1.5 yards per second were ignored because the direction reading is unreliable when a player is nearly still.

In-game bend turned out to measure **where a player lines up** more than how he moves. Edge rushers loop around tackles while interior linemen push straight ahead, so in-game bend is almost a stand-in for edge share (correlation 0.89). To compare players fairly, we graded every rush against the average for that alignment and season. This **role-adjusted in-game bend** removes most of the role effect (correlation with edge share drops to 0.36), and it still predicts pressure after accounting for draft year, draft pick, weight and edge share (p = 0.022). Bending in real games matters.

But Combine bend is only a weak preview of in-game bend. The two are mildly related (correlation 0.26, p = 0.04), and the link is no longer significant once edge share and weight are included (p = 0.30). Our main claim is therefore **Combine bend → NFL pressure**, not "Combine bend → in-game bend." One likely reason: the Combine hoop has no blocker, while in-game movement depends on the opponent and the play call.

## Limitations on the NFL side

- Pressure is credited to individual players, but it also depends on teammates, coverage and the quarterback.
- Rookies from the 2025 class have only one season of rushes, so their rates are less certain.
- Role adjustment uses a two-way label (edge or interior), which can't capture every alignment or rush technique.
