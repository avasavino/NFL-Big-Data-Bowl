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
- **Step 4 – Comparing cut force to stopwatch times** (`A_03_compare_stopwatch.R`): In progress.
- **Next – Joining with Person B's NFL data**: Not started. Person B's file (`nfl_slant_separation.csv`) is already finished and pushed.

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

## Step 4: Comparing Cut Force to Stopwatch Times (In Progress)

**File:** `scripts/A_03_compare_stopwatch.R`
**Will create:** `output/A_cutforce_vs_forty.png`

### What this step does
Teams already have stopwatch times from the Combine, like the 40-yard dash, the 3-cone drill and the short shuttle. If cut force simply repeated what those times already show, it wouldn't be useful. This step checks whether cut force measures something new. The competition prompt asks directly where tracking data "adds context" beyond traditional drill times.

### What I'm doing
Joining my cut force scores to each receiver's stopwatch times, calculating correlations, and making a scatter plot of cut force against 40-yard dash time.

### Early results
These were checked ahead of time and still need to be confirmed when I run the script:

- Of the 107 receivers, 97 have a 40-yard dash time, but only 33 ran the 3-cone drill and only 38 ran the short shuttle. Most receivers skip the agility drills, while every one of them ran the slant, so tracking data can fill a gap.
- Cut force has almost no relationship with 40-yard dash time (correlation 0.07, p-value 0.47), the 3-cone (0.08) or the shuttle (−0.02).

### What it means
If confirmed, cut force captures a skill that the stopwatch drills don't, which would support the main argument that tracking data adds new information. However, being unrelated to the 40 is only valuable if cut force also predicts NFL performance. A random number would also be unrelated to the 40. The next step, joining with Person B's NFL data, will answer that.

### What I found
*(To fill in after running.)*

---

## Key Decisions

**Studying wide receivers on the slant route (Nov 11).** Receivers have the best NFL performance measure in the data, all 107 ran the slant drill, and the slant is easy for coaches to picture.

**Splitting the work into a Combine side and an NFL side (Nov 11).** Each person only edits files starting with their own letter (A or B), so we can work at the same time without overwriting each other in GitHub. The two halves connect through player ID.

**Replacing "braking" with "cut force" (Nov 11).** The data showed receivers never slow down on the slant, so there was nothing to measure for braking. Cut force (speed × turn rate) captures how sharply a receiver can turn without losing speed.

**Using only regular-season NFL games (Nov 11).** The competition asks about regular-season performance. Preseason games involve backups and simple game plans, and playoff games are few. This leaves 2,114 NFL slants from 78 receivers (down from 100 receivers if all game types were included).

**Keeping all players instead of dropping small samples (Nov 11).** We checked and found that NFL separation on a single slant is mostly luck: the typical difference between players is about 0.34 yards, while play-to-play randomness is about 2 yards. Even with 10 slants, a player's average is only about 22% skill. It takes about 35 slants to be half skill, half luck. Dropping players with fewer than 10 slants would remove 37% of receivers, many of them backups and busts, which are exactly the players the competition wants us to identify. Instead, each player's NFL score is "shrunk" toward the average based on how many slants he ran, the same way a hitter who goes 2-for-3 isn't assumed to be a .667 hitter. As a backup check, we'll rerun the final result using only players with 10 or more slants.

**Plan B: adding other route types (Nov 11).** Because single slants are so noisy, the final result might come out weak. If it does, we can add other NFL routes where receivers make sharp cuts (in, out and hitch routes) to get more plays per receiver.

---

## Open Questions

- Does cut force predict NFL slant separation? This is the main question, and it gets answered when we join the two halves.
- Should burst or turn rate be included alongside cut force in the final model, or is cut force enough by itself?
- If the slant result is weak, do we move to Plan B?
- How should the 1.5 yards-per-second noise threshold be explained or tested in the paper?
