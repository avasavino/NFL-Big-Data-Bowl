# Person A Progress Log

**Ava Savino** · NFL Big Data Bowl 2027 · Combine side of the project
Started November 11, 2026 · Deadline January 6, 2027

---

## About This Project

The 2027 Big Data Bowl asks whether the way players move at the NFL Combine, measured by sensors that record each player's position 10 times per second, can predict how well they play in real regular-season NFL games.

Our team chose to study **wide receivers on the slant route**. A slant is a route where the receiver runs a few steps straight and then cuts toward the middle of the field. Our question is: **does how sharply a receiver cuts on the slant at the Combine predict how open he gets on slants in the NFL?**

The work is split between two people. As Person A, I handle the Combine side: turning the raw sensor data from the slant drill into a score for each receiver. Person B handles the NFL side: measuring how open each receiver gets on real NFL slants. The two halves connect through each player's ID number (`nfl_id`), and we join them together at the end.

This log records what each step does, what I did, what I found, what it means, and any important problems along the way, so I have everything I need to write the final paper.

---

## Where Things Stand

- **Step 1 – Exploring the data** (`01_explore.R`): Complete.
- **Step 2 – Loading the slant drill** (`A_01_load_slant.R`): Complete.
- **Step 3 – Scoring each receiver's cut** (`A_02_slant_metrics.R`): Complete. The handoff file for Person B is saved but still needs to be pushed to GitHub.
- **Step 4 – Comparing cut force to stopwatch times** (`A_03_compare_stopwatch.R`): Complete (Nov 16). Cut force is unrelated to the 40-yard dash.
- **New direction (Nov 16) – Defensive linemen and "bend"**: The project switched from receivers to measuring bend for pass rushers (see "The New Direction" below). Person B has been sent their new tasks.
- **Step 5 – Measuring bend on the run the hoop drill** (`A_05_dl_bend.R`): Complete (Nov 16). Handoff file `combine_dl_bend.csv` saved for 109 defensive linemen.
- **Earlier plan – Joining with Person B's receiver data**: Not started, replaced by the new direction. Person B's file (`nfl_slant_separation.csv`) is already finished and pushed. An early look (Nov 16, below) found no link between cut force and NFL slant separation, plus a draft-year problem that has to be fixed first.

---

## Step 1: Exploring the Data

**File:** `scripts/01_explore.R`

### What this step does
Before choosing what to study, this step opens the smaller data files and counts what's in them: how many players there are, what positions they play, which Combine drills each position ran, and how many players went on to play real NFL snaps. It does not touch the very large NFL game tracking files (about 2 GB), which would be slow to load.

### What I did
I loaded four files: the player list, the Combine results (stopwatch times like the 40-yard dash), the career summary for each player, and the Combine tracking data. Then I counted players by position, listed every tracked drill, and checked how many players at each position played at least 100 NFL snaps.

### What I found
The data covers 510 players drafted in 2023, 2024 and 2025, across five position groups: 107 wide receivers, 122 defensive backs, 118 defensive linemen, 121 offensive linemen and 42 tight ends. Sixty-two different drills were tracked. Receivers ran a full set of route drills, including the slant, curl, comeback, dagger and go routes.

Only about 60–65% of players at each position played 100 or more NFL snaps. For receivers, that's 70 of 107. So even though the data looks big, the number of players we can actually study at one position is closer to 70.

### What it means
Studying everything at once wasn't realistic, and the competition specifically encourages focusing on one position or one drill. We needed a position where (1) many players ran the same drill and (2) the NFL data already has a clear performance number we could compare against.

To choose, I checked which NFL performance numbers are filled in for each position. Receivers stood out: the NFL play-by-play file records `separation_at_pass_forward` (how many yards of space the receiver has from the nearest defender when the ball is thrown) on about 38,000 receiver routes. Defensive backs had excellent Combine drills but no ready-made NFL coverage number, so studying them would have meant building that measure from scratch. Tight ends had the right numbers but only 42 players.

That's why we chose wide receivers, and the slant route in particular, since all 107 receivers ran the slant drill at the Combine and the slant is one of the most common NFL routes.

---

## Step 2: Loading the Slant Drill

**File:** `scripts/A_01_load_slant.R`
**Creates:** `output/A_slant_tracking.rds` (a small copy of the slant data), `output/A_slant_paths.png` and `output/A_slant_speed.png` (pictures)

### What this step does
The Combine tracking file has about 925,000 rows covering every drill for every position. This step pulls out only the slant drill, puts each player's data in time order, adds a simple clock, and saves a small copy so later steps load quickly. It also draws pictures of the routes so we can see what a slant actually looks like in the data.

### What I did
I kept only the rows where the drill is `SLANT_ROUTE_LEFT` and the tracked object is a player. The football is also tracked in the same file, so those rows had to be removed. I sorted each player's data in time order and numbered the frames, then converted frame numbers into seconds since the start of the route (each frame is one tenth of a second). The original time column is the actual clock time of day, which isn't useful for comparing players, so this new "seconds since start" clock lets us line every receiver up from the same starting point.

I then plotted the route path (field position) and speed over time for 12 randomly chosen receivers.

### What I found
The slant drill has 4,326 frames of data from 107 receivers. 104 receivers ran it once and 3 ran it twice. Each try lasts about 2 to 5 seconds.

The pictures showed two things I didn't expect:

1. **The slant is a smooth S-shaped curve, not a sharp corner.** Receivers start running straight, bend smoothly toward the middle, and on longer recordings straighten back out.
2. **Receivers never slow down.** Speed rises steadily the whole way through the route. In 97 of 110 tries there is no real slowdown at all.

### What it means
Our original plan was to measure how hard each receiver "brakes" going into his cut, based on the idea that good route runners stop quickly and re-accelerate. The data shows that on the slant there's no braking to measure: receivers accelerate through the turn.

This led to the most important decision so far. Instead of braking, we measure **cut force**: how sharply a receiver turns *while* moving fast (explained in Step 3). This is arguably a better and more original idea anyway, because it's built around what receivers actually do on this route.

### Problems worth noting
- The Combine file mixes ball tracking with player tracking. Without filtering, the ball's movement would have been treated as a player's route.
- I wrote this script with Claude's help and then went through it line by line. From Step 3 on, I write all the code myself.

---

## Step 3: Scoring Each Receiver's Cut

**File:** `scripts/A_02_slant_metrics.R`
**Creates:** `output/combine_slant_metrics.csv`, the handoff file for Person B with one row per receiver

### What this step does
This step finds the moment of each receiver's hardest cut on the slant and measures it. It produces five numbers per receiver and saves them in a file that Person B will join with their NFL data.

### What I did
I started by studying one receiver (player 55884) in detail, so I could check every calculation by eye, and then applied the same steps to all 107 receivers.

**Turn rate.** The tracking data includes the direction each player is moving (`dir`), measured like a compass in degrees. I calculated how much that direction changes from one frame to the next and multiplied by 10 to get degrees per second. This is the turn rate, or how quickly he is changing direction.

**Cut force.** Turning sharply is easy when walking and hard when sprinting. To capture that, I multiplied speed by turn rate (converted from degrees to radians, as the physics formula requires). This is the sideways push a player experiences in a turn, the same thing you feel when a car takes a corner fast. Physicists call it lateral acceleration. It's measured in yards per second squared, and dividing by 10.73 converts it to g's (multiples of gravity), which is an easy way to explain it to coaches.

**Hardest cut.** For each receiver, I found the frame with the largest cut force. That's the moment of his hardest cut. From that moment I recorded:
- **time_to_cut**: how many seconds into the route it happened
- **cut_speed**: how fast he was going
- **turn_rate**: how quickly he was turning
- **cut_force**: the sideways push

**Burst.** I measured how much his speed increased in the half second after the cut, to capture how explosively he comes out of it.

**One row per player.** For the 3 receivers who ran the drill twice, I averaged their two tries.

### What I found
Player 55884 shows why cut force matters more than turn sharpness alone. His sharpest turn was at 1.9 seconds (42.7 degrees per second), but his hardest cut was at 2.1 seconds (41.3 degrees per second). The turn at 2.1 was slightly gentler, but he was moving faster (6.03 vs 5.59 yards per second), so it produced more force.

Across all 107 receivers:
- **Cut force** ranges from 2.7 to 5.8 yards per second squared, with a middle value of 4.34. In g's, that's 0.25 to 0.54, so the strongest cutter generates about twice the sideways force of the weakest.
- **The hardest cut happens 1.0 to 2.7 seconds into the route** for every receiver. That's exactly where the break of a slant should be, which tells us the method is finding the real cut and not random noise.
- **Burst** ranges from 0.27 to 1.53 yards per second gained in half a second (middle value 1.09).
- **Faster receivers tend to turn less sharply.** The correlation between speed at the cut and turn rate is −0.45. This is a real trade-off, like a car that can't take a tight corner at high speed. Cut force combines both, so it identifies the receivers who handle this trade-off best.

### What it means
We now have a single, physically meaningful number for each receiver's cut that comes directly from the sensor data and can't be measured with a stopwatch. It rewards receivers who can turn sharply without giving up speed, which is exactly what should create separation from a defender.

### Problems worth noting
These problems affected the method and are worth explaining in the paper:

- **Noisy direction at low speed.** In the first second, when a player is barely moving, the sensor can't tell which way he's heading. The direction readings jump around and create fake turn rates as high as 299 degrees per second. I ignored any frame where the player was moving slower than 1.5 yards per second. This threshold was chosen by looking at where the noise stopped.
- **Compass wrap-around.** Direction goes from 0 to 360 degrees, so a turn from 359° to 1° looks like −358° instead of 2°. This happened 11 times. I corrected it so every change is measured the short way around the circle (between −180 and +180 degrees).
- **Keeping players separate.** When calculating the change from one frame to the next, the first frame of one player could accidentally be compared to the last frame of the previous player, creating 109 fake turns. Grouping the data by player and attempt prevented this.
- **Short recordings.** I originally planned to measure burst over one full second after the cut, but 6 recordings end before then. Half a second works for every receiver.

---

## Step 4: Comparing Cut Force to Stopwatch Times

**File:** `scripts/A_03_compare_stopwatch.R`
**Creates:** `output/A_cutforce_vs_forty.png` (scatter plot of cut force against 40-yard dash time)

### What this step does
Teams already have stopwatch times from the Combine, like the 40-yard dash, the 3-cone drill and the short shuttle. If cut force simply repeated what those times already show, it wouldn't be useful. This step checks whether cut force measures something new. The competition prompt asks directly where tracking data "adds context" beyond traditional drill times.

### What I did
I joined my cut force scores to each receiver's official stopwatch times from the Combine results file (40-yard dash, 3-cone drill and short shuttle), matching on player ID. I counted how many receivers had each time, ran a correlation test between cut force and 40-yard dash time, and made a scatter plot with one dot per receiver and a best-fit straight line.

### What I found
**Not every receiver has stopwatch times.** Of the 107 receivers, 97 ran the 40-yard dash, but only 33 ran the 3-cone drill and only 38 ran the short shuttle. Most receivers skip the agility drills. Every one of them ran the slant, though, so tracking data gives us an agility-type measure for players who have no agility time at all.

**Cut force has almost no relationship with 40-yard dash time.** The correlation is 0.07 (on a scale where 0 means no relationship and 1 means a perfect match), with a p-value of 0.47, meaning a link this small could easily be chance. The 95% confidence range runs from −0.13 to 0.27, so any real relationship is weak at most. In the scatter plot, the best-fit line is nearly flat and the dots are spread widely. Receivers with fast and slow 40 times both show the full range of cut force, from about 2.7 to 5.7.

Cut force is also unrelated to the 3-cone drill (correlation 0.08, 33 receivers) and the short shuttle (−0.02, 38 receivers). These two are based on small groups, so they're less certain than the 40-yard dash result.

### What it means
Cut force captures something the stopwatch doesn't. A receiver's straight-line speed tells you almost nothing about how hard he can cut while running a route. This supports the main argument of the project: Combine tracking data adds new information that traditional drill times miss, which is exactly what the competition prompt asks about.

There is one important caution for the paper. Being unrelated to the 40 is only valuable if cut force **also predicts NFL performance**. A completely random number would also be unrelated to the 40. The next step, joining with Person B's NFL separation data, answers whether cut force is a real skill or just noise.

### Possible figure for the paper
The scatter plot (`A_cutforce_vs_forty.png`) is a good candidate for the writeup, since it makes the "the stopwatch misses this" point at a glance. Before using it in the final paper, it should be cleaned up: a lighter theme, the correlation printed on the chart, and maybe a few standout receivers labeled.

---

## Early Look at the NFL Link (Nov 16)

Before starting the joining step with Person B, Claude ran a quick preview to see what we should expect. These are rough checks, not the final analysis.

### Cut force does not predict NFL slant separation
All 78 of Person B's receivers match a receiver in my file. Across them, cut force has essentially no relationship with NFL slant separation over expected (correlation −0.09, p-value 0.45). The result is the same when only receivers with 10 or more NFL slants are used (−0.06, 49 receivers). None of my other scores show a meaningful positive link either. Burst has a small negative correlation (−0.23, p = 0.04), but with five scores tested, one result that small is likely chance, and it points the opposite way from what we'd expect.

### The NFL outcome itself may be the problem
Even draft position and 40-yard dash time, which teams rely on heavily, show no relationship with slant separation (0.02 and 0.05). If nothing predicts it, the per-player separation score is probably too noisy, or too driven by things like the quarterback and the play call, to reflect a receiver's own skill. This matches what we found earlier: luck is about six times bigger than skill on a single slant.

Plan B (adding more route types) was also checked. Using in, out, hitch, corner, post and cross routes, up to 23,000 NFL routes, cut force still shows no positive link (correlations between −0.10 and −0.18, none significant). Yards after catch over expected was also checked, and showed no link and almost no detectable player-to-player skill.

### A draft-year problem in the Combine data
Receivers with higher cut force appeared to play fewer NFL snaps (correlation −0.29). That turned out to be caused by draft year, not skill:

- **The 2025 slant recordings are different.** They are much shorter (about 2.8 seconds vs about 4.5 seconds in 2023 and 2024) and end earlier in the route. This suggests the drill or the recording setup changed in 2025.
- **2025 receivers have higher cut force on average:** 4.64, compared with 4.10 in 2023 and 4.22 in 2024. This difference is far too large to be chance (p = 0.0001).
- **2025 receivers have had only one NFL season**, so they naturally have fewer snaps.

Put together, the "high cut force, fewer snaps" pattern is mostly a draft-year effect. Within each draft year, the relationship is small and not significant (−0.11, −0.24 and −0.20).

### What it means
Cut force can't be compared fairly across draft years as it is. It needs to be adjusted within each year (for example, scored relative to the other receivers from the same Combine). This affects every later analysis and should be explained in the paper's methods section.

The bigger takeaway is that NFL slant separation, at least as currently measured per player, does not look like a usable target. The team needs to decide how to connect cut force to NFL games in a way that holds up.

### Quick test of Option A: does the Combine cut show up in games? (Nov 16)
Option A measures cut force on real NFL slants using the game tracking data, then checks whether Combine cut force predicts in-game cut force. Claude ran a rough prototype using the same method as Step 3, applied to each receiver's NFL slant plays from the snap to the throw.

- **It works with our data.** All NFL slant plays are in the game tracking files, which have "ball_snap" and "pass_forward" markers. Each season loads in about a second when only the needed columns are read, so no supercomputer is needed. The prototype covered 2,279 NFL slant plays from 79 receivers.
- **In-game cut force is a real, repeatable trait.** Unlike separation, a receiver's in-game cut force is fairly consistent from play to play. After about 16 slants (the typical number per receiver), his average is about half skill and half luck (reliability 0.52), much better than separation.
- **But Combine cut force does not predict in-game cut force.** The correlation is 0.05 (0.08 after adjusting for draft year), essentially zero.
- **In-game cut force on a play is also unrelated to separation on that play** (correlation 0.01).

### Quick test of other drills: braking on curl and comeback routes (Nov 16)
Receivers do slam the brakes on curl and comeback routes, so Claude tested Combine braking on those drills against NFL hitch routes (4,512 plays, 78 receivers). Combine braking had only weak, non-significant links with in-game braking (0.15 for comeback, 0.11 for curl) and none with hitch separation. The 2025 class again scored much higher on these drills, which confirms the 2025 recording difference isn't limited to the slant.

### What the tests together suggest
Across three outcomes and three drills, the pattern is the same: **Combine route-drill movement does not carry over strongly to how receivers move or get open in NFL games.** At the same time, receivers *do* have a consistent cutting style in real games. These were quick prototypes, so the careful versions could shift slightly, but large changes are unlikely. This is the key finding the project now has to build its story around.

### Does Option A really answer the prompt? (Nov 16)
Not fully, on its own. The prompt asks for links between Combine tracking and NFL **performance**, and for insights that help teams **find hidden talent and avoid busts**. In-game cut force is a way of *moving*, not a measure of performance. A "the drill doesn't translate" result alone would be honest but hard to make useful to teams. So Claude looked for an NFL performance measure that is reliable enough to test against.

### A better performance measure: yards per route run (Nov 16)
**Yards per route run (YPRR)** is a standard stat NFL teams use for receivers: total receiving yards divided by the number of routes run. It rewards getting open, getting targeted and gaining yards, and it isn't distorted by how much a player plays. Unlike slant separation, it's a stable player trait: targets per route run, for example, is about 68% skill after a typical receiver's 277 routes. And it behaves like a real performance measure, since draft pick predicts it clearly (correlation −0.43: higher picks produce more).

For the 63 receivers with at least 100 NFL routes and a Combine slant:

- **Speed through the cut predicts NFL production.** Receivers who carried more speed into their hardest Combine cut (`cut_speed`, adjusted within draft year) produced more yards per route run: about +0.2 yards per route for each step above their class average (p = 0.007).
- **It still holds after accounting for draft year and draft pick** (+0.2, p = 0.012). Adding it nearly doubles how much of the difference in YPRR is explained, from 11% (draft position alone) to 20%. This is the "hidden talent" angle the prompt asks for: it tells teams something the draft order didn't already know.
- **Sharper turning points the other way** (turn rate, −0.12, p = 0.08, not significant).
- **Cut force itself does not predict YPRR** (−0.05). Its two ingredients pull in opposite directions, so multiplying them cancels the signal out.

### What it means
The interesting skill isn't "turn as hard as possible." It's **keeping your speed through the cut**. Receivers who round the slant slightly but stay fast seem to outproduce receivers who make a sharper but slower turn. This is non-obvious, matches the speed-vs-sharpness trade-off found in Step 3, and is actionable for scouts and coaches.

**Update, same day:** in the fuller, fairer search below, this result did not stand out, so it's now a weaker lead.

**Important caution:** this was found after testing several Combine measures against several NFL outcomes. When you test many things, one can look significant by chance. It has to be confirmed carefully before it becomes the headline, for example by checking that it holds in each draft class and isn't driven by one or two players, and the paper should say honestly how it was found.

---

## Searching for a Stronger Link (Nov 16)

Ava wanted the project to match the original idea, **a practice skill that predicts a different in-game result**, and to be sure a real relationship exists before building it. So Claude ran a systematic, fair search instead of testing one idea at a time.

### How the search worked
1. **Same skills on every drill.** For every Combine drill that most players at a position ran, the same six movement skills were measured from the tracking data: top speed, hardest acceleration, hardest braking, cut force, speed at the cut, and (for linemen) burst in the first half second. Each was graded on a curve within draft year. Combined scores across each position's drills were also built, since averaging drills reduces luck.
2. **Reliable NFL performance stats.** Each position was matched with performance stats that have enough plays per player to be mostly skill:
   - Receivers: yards per route run, targets per route run, separation on all routes, EPA per route, yards after catch over expected.
   - Defensive linemen: pressure rate (about 54% skill after a typical 297 pass rushes), sack rate, fast pressure rate.
   - Offensive linemen: pressure allowed rate (81% skill), average pressure probability allowed (93% skill), sack allowed rate.
3. **Fair comparisons.** Every test accounted for draft year and draft pick, so a result has to say something the draft order didn't already know.
4. **A shuffle test for luck.** When you run hundreds of tests, some look significant by chance. The Combine scores were randomly shuffled among players hundreds of times to see how strong the best result gets from luck alone. A real finding has to beat that.

### What the search found
- **Receivers (63 players, 390 tests).** 31 results reached p < 0.05, compared with about 20 expected from luck. Nothing beat the shuffle test (best family-wise p = 0.33).
- **Offensive linemen (66 players, 162 tests).** 18 hits vs about 8 from luck. The best was acceleration in the five-yard wave drill → fewer pressures allowed, but it didn't beat the shuffle test either (family-wise p = 0.15).
- **Defensive linemen (69 players, 144 tests).** 36 hits vs about 7 from luck, the strongest signal by far. But most of it turned out to be **body weight**: lighter linemen (usually edge rushers) are faster in drills and also get more pressure because of their role. After accounting for weight, the overall hit count fell to luck level (8 vs about 6).

### The one result that survived: "bend" for pass rushers
In the **run the hoop** drill, defensive linemen sprint around a circle while leaning in. That's exactly how an edge rusher "bends" around an offensive tackle to reach the quarterback, a trait scouts talk about constantly but have never had a number for. **Cut force on this drill**, the same measure from Step 3, is a direct measurement of bend.

For 63 defensive linemen:

- **Higher bend → more NFL pressure.** It holds after accounting for draft year, draft pick, body weight and whether the player lines up on the edge or the interior (p = 0.012).
- **It shows up in every draft class.** The correlation is 0.46 in 2023, 0.36 in 2024 and 0.43 in 2025.
- **It adds to the NFL's own athleticism score** (p = 0.03) and to vertical jump (p = 0.04).
- **Size of the effect:** one step above average in bend goes with about 0.75 percentage points more pressure, on an average pressure rate of 7%. That's roughly 11% more pressures.
- **Weak spots:** it doesn't predict sack rate (sacks are rarer and noisier). Dropping single players moves its strength around (t from 1.85 to 3.03). And when predicting one draft class from the other two, it helped for 2023 and 2024 but not for 2025.

### What it means
There is no Combine tracking link in this data that is "definitely" real in the strictest sense. With about 60–70 NFL players per position, no single result can pass every test. The most promising candidate is **bend → pressure rate**. It has a clear football meaning chosen for a reason (the drill is designed to test bend), it's consistent across years, and it survives the obvious explanations. It matches the original idea of the project (a practice skill predicting a different game result) and reuses the cut force method directly. Its weakness is that it was found during a search, so the paper would need to say so honestly.

Switching to defensive linemen would change the project's position group and Person B's NFL work, so it's a team decision.

---

## The New Direction: Measuring "Bend" (Nov 16)

After the search, Ava chose to switch the project to defensive linemen and bend. Person B has been sent the new plan.

### The idea, explained simply

**What's a pass rusher?** On passing plays, defensive linemen try to get to the quarterback before he throws. The best ones line up on the outside (the "edge") and run *around* the offensive tackle who's trying to block them.

**What's "bend"?** To get around that blocker, the rusher has to run a tight curve at full speed while leaning his body in, like a motorcycle racer tilting into a turn. If he can't bend, he has to take a wide path, and the quarterback has time to throw. Scouts say things like "this guy has elite bend" all the time, but it has always been an opinion from watching video, never a number.

**The Combine drill.** In the **run the hoop** drill, linemen sprint around a big painted circle on the ground. It's a test of bend, but until now scouts have only watched it with their eyes. 109 defensive linemen ran it.

**What we measure.** Cut force (from Step 3) = how hard a player turns × how fast he's going. On a circle, that's exactly bend: a high number means he takes a tight curve without slowing down. For the first time, bend becomes a number.

**What we check.** Do the linemen with more bend at the Combine get to the quarterback more often in real NFL games? That's **pressure rate**: pressures ÷ the number of times he rushed the passer.

**The answer from the search.** Yes. More bend goes with about 11% more pressures, and it holds even after accounting for what teams already know: where he was drafted, how heavy he is, whether he plays inside or outside, and the NFL's own athleticism score.

**The one-sentence pitch:**
> We turned "bend," the most famous trait scouts look for in a pass rusher, into a number for the first time, and showed it predicts NFL pressure beyond draft position, size and athleticism.

### Would the judges like it?

The judges are analytics staff from NFL teams. Here's how the idea lines up with each part of the score:

| Category | Weight | How bend does | Why |
|---|---|---|---|
| **Football** | 30% | Strong | Scouts already care about bend, so a number for it is instantly useful. Teams could use it to compare rushers or spot ones the draft overlooked. It's also one of the prompt's own examples ("trench play"). |
| **Data science** | 30% | Good, if honest | It survives a lot of checks. But it was found by searching, it's based on 63 players, and it doesn't predict sacks. Judges will notice, so the paper has to say this openly and show the checks. |
| **Writing** | 20% | Strong potential | A very easy story to tell: a famous trait, a clever measurement, a clear result. |
| **Charts** | 20% | Strong potential | Great visuals are possible, like two players' paths around the hoop (one tight, one wide) colored by speed. That's both innovative and accessible. |

**Overall:** It's genuinely good work that analytics staff would respect, mainly because it's original, clearly useful and honest about how sure we are. It's not a guaranteed winner, since the final result is modest ("probably real, not proven"). But it's much stronger than the receiver version, where nothing held up.

### What would make it even better
1. **Show bend in real games too.** Measure bend on actual NFL pass rushes using the game tracking data. "Bend at the Combine shows up as bend on Sundays" makes the story much more convincing.
2. **Hidden-talent examples.** Name a few real players with high bend who were drafted late and then got lots of pressure. Judges love concrete examples.
3. **Be upfront about the limits.** Say plainly: "we tested many ideas, and this is the one that held up. Here are the checks." Analytics people trust that far more than a perfect-looking result.

### Who does what now
- **Person A (Ava):** measure bend on the run the hoop drill (`A_05_dl_bend.R`, reusing the Step 3 cut force method), adjusted within draft year. Saves `output/combine_dl_bend.csv`.
- **Person B:** NFL pressure rate, sack rate and edge share for every defensive lineman, regular season only (`output/nfl_dl_pressure.csv`). Then bend measured on real NFL pass rushes from the game tracking data (`output/nfl_dl_game_bend.csv`).
- **Together:** join on `nfl_id` and build the final model and charts.

---

## Step 5: Measuring Bend on the Run the Hoop Drill

**File:** `scripts/A_05_dl_bend.R`
**Creates:** `output/combine_dl_bend.csv` (handoff file, one row per defensive lineman) and `output/A_hoop_path.png` (picture of the drill)

### What this step does
This step turns the run the hoop drill into a bend score for every defensive lineman who ran it. It uses the same cut force method built for receivers in Step 3, applied to a new drill.

### What the drill looks like
Looking at the tracking data showed that run the hoop is a **figure-8 around two hoops**, followed by a straight sprint out at the end. The player starts slowly, accelerates into the first loop, crosses through the middle, loops around the second hoop, and then sprints away. On one loop he turns left, and on the other he turns right. Recordings last about 6.5 to 9.5 seconds (64 to 96 frames). Unlike the slant, the clip length is similar across all three draft years.

### What I did
1. Kept only run the hoop rows for players (not the ball), sorted each try in time order, and added a clock in seconds.
2. Drew one player's full path, colored by speed, to see the drill's shape.
3. Calculated turn rate and cut force for every frame, the same way as Step 3: change in direction × 10, the compass wrap fix, ignoring frames slower than 1.5 yards per second, grouped by player and try. **One change:** the turn is measured as its absolute size, because the figure-8 has turns in both directions and we care how hard the player turns, not which way.
4. For each try, found the moment of hardest bend (biggest cut force). This almost always happens on the loops themselves (113 of 119 tries), not on the final sprint, so the score measures real bend around the hoop.
5. Averaged the two tries for the 10 players who ran the drill twice.
6. Graded bend on a curve within each draft year (`bend_z`), so players are only compared to their own Combine class.

**Output columns:** `nfl_id`, `draft_year`, `attempts`, `bend` (peak cut force, yd/s²), `bend_speed` (speed at that moment, yd/s), `bend_z` (bend graded within draft year)

### What I found
- **109 defensive linemen** ran the drill. 99 ran it once and 10 ran it twice.
- **Bend ranges from 6.2 to 8.7 yd/s²**, with a middle value of 7.3. In g's (dividing by 10.73), that's about 0.58 to 0.81 g. That's much higher than receivers on the slant (0.25 to 0.54 g), because the hoop forces tight turns.
- Speed at the moment of peak bend ranges from 1.9 to 4.3 yards per second.
- Example: player 55877 (2023) hit his peak bend of 7.42 at 6.2 seconds, moving 3.92 yards per second, turning 109 degrees per second. That's slightly above average for his class (`bend_z` = 0.48).
- **Average bend by year:** 7.23 in 2023, 7.66 in 2024, 7.23 in 2025. The 2024 class is higher, which is another reason to grade within draft year.

### Early check against NFL pressure
Using this exact version of bend, a quick check against NFL pressure rate (63 linemen with at least 100 regular-season pass rushes) gave the same result as the search: higher bend goes with more pressure after accounting for draft year, draft pick, body weight and edge role (p = 0.011). The relationship points the same way in every class (correlations of 0.46, 0.36 and 0.43). The official version will use Person B's pressure file once it's ready.

### What it means
The bend score is ready and behaves sensibly. It peaks on the loops, it's on a realistic physical scale, and it's adjusted for year-to-year differences in the Combine. My half of the new handoff is done.

### Possible figure for the paper
The figure-8 path picture (`A_hoop_path.png`) is a strong candidate for introducing the drill. A cleaner version could show two players side by side, one with high bend and one with low, so readers see the difference immediately.

---

## Key Decisions

**Studying wide receivers on the slant route (Nov 11).** Receivers have the best NFL performance measure in the data, all 107 ran the slant drill, and the slant is easy for coaches to picture.

**Splitting the work into a Combine side and an NFL side (Nov 11).** Each person only edits files starting with their own letter (A or B), so we can work at the same time without overwriting each other in GitHub. The two halves connect through player ID.

**Replacing "braking" with "cut force" (Nov 11).** The data showed receivers never slow down on the slant, so there was nothing to measure for braking. Cut force (speed × turn rate) captures how sharply a receiver can turn without losing speed.

**Using only regular-season NFL games (Nov 11).** The competition asks about regular-season performance. Preseason games involve backups and simple game plans, and playoff games are few. This leaves 2,114 NFL slants from 78 receivers (down from 100 receivers if all game types were included).

**Keeping all players instead of dropping small samples (Nov 11).** We checked and found that NFL separation on a single slant is mostly luck: the typical difference between players is about 0.34 yards, while play-to-play randomness is about 2 yards. Even with 10 slants, a player's average is only about 22% skill. It takes about 35 slants to be half skill, half luck. Dropping players with fewer than 10 slants would remove 37% of receivers, many of them backups and busts, which are exactly the players the competition wants us to identify. Instead, each player's NFL score is "shrunk" toward the average based on how many slants he ran, the same way a hitter who goes 2-for-3 isn't assumed to be a .667 hitter. As a backup check, we'll rerun the final result using only players with 10 or more slants.

**Adjusting cut force for draft year (Nov 16).** The 2025 Combine recorded route drills differently (shorter clips, higher average scores). Cut force is now also given as a z-score within each draft class (`cut_force_z`), so receivers are only compared to others from the same Combine.

**Choosing Option A, "does the Combine cut show up in games?" (Nov 16, Ava's choice; to confirm with Person B).** The project now asks whether Combine cut force predicts the same cut force measured in real NFL games, instead of predicting separation directly. It reuses the Step 3 method on NFL game tracking. The quick test suggests the answer may be "no," which would make the project a study of why the drill doesn't translate.

**Keeping cut force as the main measurement (Nov 16).** The near-zero correlations are a finding about the Combine drill, not a sign that cut force is broken. Cut force behaves like a real measurement: at the Combine it lands on the route's break every time, and in NFL games it's consistent from play to play for the same receiver (reliability about 0.52). Other Combine measures (turn rate, speed at the cut, braking on curl and comeback routes) didn't translate either, so swapping cut force for something else wouldn't fix the result.

**Switching to defensive linemen and "bend" → pressure rate (Nov 16).** A fair search of about 700 practice-skill × game-result combinations across receivers, offensive linemen and defensive linemen found that receiver ideas didn't hold up, while bend (cut force on the run the hoop drill) predicted NFL pressure rate after accounting for draft year, draft pick, body weight, edge vs. interior role and NFL athleticism score. It matches the project's original shape (a practice skill predicting a different game result) and reuses the cut force method. The receiver work stays in the paper as the story of how we got here and as evidence that cut force is a sound measurement.

**Plan B: adding other route types (Nov 11).** Because single slants are so noisy, the final result might come out weak. If it does, we can add other NFL routes where receivers make sharp cuts (in, out and hitch routes) to get more plays per receiver.

---

## Open Questions

- Does cut force predict NFL slant separation? The early look (Nov 16) says no. This needs to be confirmed in the joining step, after adjusting cut force for draft year.
- Why are the 2025 slant recordings shorter, and did the drill itself change? Year adjustment handles it statistically, but the paper should mention it.
- Which direction should the project take from here? The leading option (Nov 16): use **yards per route run** as the NFL performance measure and **speed through the cut** as the main Combine measure, with cut force kept as the tool that finds the cut, and in-game cut force as a supporting "drill translation" section. Needs Person B's agreement.
- Does the speed-through-the-cut result hold up under careful checks (each draft class separately, without outliers, with a proper model)? The fair search (Nov 16) suggests it's weak.
- ~~Should the project switch to defensive linemen and "bend"?~~ Decided Nov 16: yes.
- Does Combine bend show up as bend in real NFL pass rushes? (Person B's in-game bend file will answer this.)
- Does the bend result hold once Person A's careful version and Person B's pressure file replace the quick search versions?
- Should burst or turn rate be included alongside cut force in the final model, or is cut force enough by itself?
- If the slant result is weak, do we move to Plan B?
- How should the 1.5 yards-per-second noise threshold be explained or tested in the paper?
