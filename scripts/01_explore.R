# ============================================================
# 01_explore.R — First look at the Big Data Bowl 2027 data
# Goal: learn WHO is in the data and WHAT the NFL stats look like.
# We only load the SMALL files here. The huge game tracking files come later.
# ============================================================

# library() turns on a package (a toolbox of extra functions).
# tidyverse = a bundle of popular data tools (read_csv, filter, count, etc.)
library(tidyverse)

# read_csv() reads a .csv file (a spreadsheet saved as plain text) into R.
# The "<-" arrow means "save the thing on the right into the name on the left."
players  <- read_csv("data/players.csv")                  # one row per player: name, position, draft pick
combine  <- read_csv("data/combine_results.csv")          # one row per player: 40 time, vertical, etc.
careers  <- read_csv("data/player_career_successes.csv")  # one row per player: snaps, starts, Pro Bowls
drills   <- read_csv("data/combine_tracking.csv")         # 10 rows per second of every Combine drill

# ---- 1. How many players, and what positions? ----
# count() tallies how many rows have each value (like a tally chart).
# The "|>" pipe means "take this, THEN do the next thing to it."
combine |> count(combine_position)

# ---- 2. Which drills were tracked, and for which position group? ----
# distinct() keeps one copy of each unique combo; n_distinct() counts unique values.
drills |>
  group_by(drill_type, drill_name) |>             # group_by() = sort rows into piles
  summarise(players = n_distinct(nfl_id),          # summarise() = one result per pile
            .groups = "drop") |>                   # .groups = "drop" just un-piles afterward
  arrange(drill_type, desc(players)) |>            # arrange() sorts; desc() = biggest first
  print(n = Inf)                                   # n = Inf means "show every row, don't cut off"

# ---- 3. How many players actually PLAYED in the NFL? ----
# left_join() glues two tables together by a shared column (like VLOOKUP in Excel).
# mutate() makes a new column. if_else(test, yes, no) picks a value based on a test.
career_summary <- combine |>
  left_join(careers, by = "nfl_id") |>
  mutate(total_snaps = career_offensive_snaps + career_defensive_snaps)

career_summary |>
  group_by(combine_position) |>
  summarise(players         = n(),                         # n() = number of rows in the pile
            played_100_plus = sum(total_snaps >= 100, na.rm = TRUE),  # na.rm = TRUE skips blanks
            median_snaps    = median(total_snaps, na.rm = TRUE))
