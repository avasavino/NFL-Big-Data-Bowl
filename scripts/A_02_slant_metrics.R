# ===============================================================
# A_02_slant_metrics.R - Person A, step 2 
# Goal: find each reciever's sharpest turn on the Combine slant
#   and measure how hard that turn was ("cut force")
# ===============================================================

library(tidyverse)

slant <- readRDS("output/A_slant_tracking.rds")

# Pick one player to study- once math works then we can do all 107 
one <- slant |>
    filter(nfl_id == 55884)

# Look at onlt the columns we care about - seconds, speed, direction
one |>
    select(sec, s, dir) |>
    print(n = 50)

# How fast is he turning?
one <- one |>
# ddir * 10 turns it into degrees per second since each frame is 1/10 of a second 
# ddir = how many degrees he turned since last frame
    mutate(ddir     = dir - lag(dir),
            ddir    = ((ddir + 180) %% 360) - 180, 
            turn_rate = ddir * 10, 
            turn_rate = if_else(s < 1.5, NA, turn_rate))

one |>
    select(sec, s, dir, ddir, turn_rate) |>
    print(n = 50)

# Find the row with the biggest turn rate = the moment of the cut 
one |>
    slice_max(turn_rate, n = 1) |>
    select(sec, s, dir, turn_rate) |>
    print()

# Cut force = speed x turning speed (sideways push)
# pi / 180 converts degrees to radians (the physics formula needs radians)
# 1g (pull of gravity) = 10.73 yds/sec squared 
one <- one |>
    mutate(cut_force = s * turn_rate * pi / 180, 
        cut_g   = cut_force / 10.73)

# Fine the moment of the hardest cut (biggest cut force)
one |>
    slice_max(cut_force, n = 1) |>
    select(sec, s, dir, turn_rate, cut_force, cut_g) |>
    print()

# ============================================================
# ALL RECEIVERS: same math, but grouped so each player-try its seperate
# ============================================================

# group_by() so lag() never looks across two different players 
all_frames <- slant |>
    group_by(nfl_id, attempt) |>
    mutate(ddir     = dir - lag(dir),
            ddir    = ((ddir + 180) %% 360) - 180, 
            turn_rate = ddir * 10, 
            turn_rate = if_else(s <1.5, NA, turn_rate), 
            cut_force = s * turn_rate * pi / 180) |>
    ungroup()

# For each player-try, keep only the moment of the hardest cut 
cuts <- all_frames |>
    group_by(nfl_id, attempt) |>
    slice_max(cut_force, n =1, with_ties = FALSE) |>
    ungroup() |>
    select(nfl_id, attempt, 
            cut_frame   = frame, 
            # how many seconds into the route he made the hardest cut
            time_to_cut     = sec, 
            # his speed at that moment 
            cut_speed   = s, 
            turn_rate, 
            cut_force)
    print(cuts) 
    # Gives min, middle, max of every column 
    print(summary(cuts))

# Burst = speed gaines in the 0.5 seconds after the hardest cut 
after_cut <- all_frames |>
    inner_join(cuts |> select(nfl_id, attempt, cut_frame, cut_speed), 
        by = c("nfl_id", "attempt")) |>
    filter(frame == cut_frame + 5) |>
    mutate(burst_half_s = s - cut_speed) |>
    select(nfl_id, attempt, burst_half_s)

# Glue burst onto the cuts table 
cuts <- cuts |>
    left_join(after_cut, by = c("nfl_id", "attempt"))

# One row per player: average the tries (only 3 players had 2 tries) 
player_metrics <- cuts |>
    group_by(nfl_id) |>
    summarise(attempts    = n(), 
        time_to_cut     = mean(time_to_cut), 
        cut_speed   = mean(cut_speed), 
        turn_rate   = mean(turn_rate), 
        cut_force   = mean(cut_force), 
        burst_half_s    = mean(burst_half_s)) 
print(player_metrics)

# Save the handoff file for Person B (one row per receiver) 
write_csv(player_metrics, "output/combine_slant_metrics.csv")

