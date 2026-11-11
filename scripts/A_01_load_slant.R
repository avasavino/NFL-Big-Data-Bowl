# ============================================================
# A_01_load_slant.R  —  Person A, step 1
# Goal: pull ONLY the slant drill out of the big Combine tracking file,
#       add a clock (seconds since the route started), save a small copy,
#       and draw pictures so we can SEE what a slant looks like.
# Output: output/A_slant_tracking.rds   (small copy, not uploaded to GitHub)
#         output/A_slant_paths.png      (picture of the route shapes)
#         output/A_slant_speed.png      (picture of speed over time)
# ============================================================

library(tidyverse)   # turn on the tidyverse toolbox (read_csv, filter, ggplot, etc.)

# ---- 1. Load the Combine tracking file ----
# read_csv() reads the spreadsheet-like text file into R as a table.
combine_tracking <- read_csv("data/combine_tracking.csv")

# ---- 2. Keep only the slant drill, and only the player (not the football) ----
# filter() keeps rows where the test is TRUE. "==" means "is exactly equal to".
# "&" means BOTH tests must be true.
slant <- combine_tracking |>
  filter(drill_name == "SLANT_ROUTE_LEFT",   # only the slant drill
         entity_type == "PLAYER")            # drop the rows that track the ball

# ---- 3. Put rows in time order and add a clock ----
# arrange() sorts rows: by player, then by try (attempt), then by time.
# group_by() makes R treat each player's each try as its own little pile.
# row_number() counts 1, 2, 3... inside each pile (the "frame" number).
# Each frame is 1/10 of a second, so seconds = (frame - 1) / 10.
slant <- slant |>
  arrange(nfl_id, attempt, time) |>
  group_by(nfl_id, attempt) |>
  mutate(frame = row_number(),               # 1, 2, 3, ... within each try
         sec   = (frame - 1) / 10) |>        # 0.0, 0.1, 0.2, ... seconds
  ungroup()                                  # un-pile so later steps see one big table

# ---- 4. Quick checks (printed to the screen) ----
# n_distinct() counts how many different values there are.
cat("Players:", n_distinct(slant$nfl_id), "\n")              # cat() just prints text
cat("Rows (frames):", nrow(slant), "\n")                     # nrow() = number of rows

# How many tries did each player get? count() tallies; the second count() tallies the tallies.
slant |> distinct(nfl_id, attempt) |> count(nfl_id) |> count(n, name = "players")

# ---- 5. Save a small copy so later scripts don't reload the giant file ----
# saveRDS() saves an R table to a file. .rds files are ignored by Git (see .gitignore).
saveRDS(slant, "output/A_slant_tracking.rds")

# ---- 6. Picture 1: the route shape for 12 random players ----
set.seed(1)                                   # makes the "random" pick the same every time
some_players <- sample(unique(slant$nfl_id), 12)   # sample() picks 12 player IDs at random
                                                    # unique() lists each ID only once

plot_paths <- slant |>
  filter(nfl_id %in% some_players) |>         # %in% = "is one of these"
  ggplot(aes(x = x, y = y,                    # aes() says which columns go on which axis
             colour = s,                      # colour the line by speed (s)
             group = attempt)) +              # draw each try as its own line
  geom_path(linewidth = 1) +                  # geom_path() connects dots in time order
  facet_wrap(~ nfl_id) +                      # facet_wrap() = one mini-chart per player
  coord_equal() +                             # make 1 yard across = 1 yard up (no stretching)
  scale_colour_viridis_c(name = "Speed\n(yd/s)") +   # a colour-blind-friendly colour scale
  labs(title = "Combine slant routes: a smooth S-curve, not a hard cut",
       x = "Field x (yards)", y = "Field y (yards)")

# ggsave() saves the last chart to a picture file.
ggsave("output/A_slant_paths.png", plot_paths, width = 10, height = 8, dpi = 100)

# ---- 7. Picture 2: speed over time for the same 12 players ----
plot_speed <- slant |>
  filter(nfl_id %in% some_players) |>
  ggplot(aes(x = sec, y = s, group = attempt)) +
  geom_line() +                               # geom_line() draws a line left to right
  facet_wrap(~ nfl_id) +
  labs(title = "Speed only goes UP on a slant: receivers don't brake",
       x = "Seconds since start", y = "Speed (yards per second)")

ggsave("output/A_slant_speed.png", plot_speed, width = 10, height = 8, dpi = 100)
