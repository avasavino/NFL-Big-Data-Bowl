# ============================================================
# Goal: measure "bend" for defensive linemen on the Combine run the hoop drill, using the cut force method
# ============================================================

library(tidyverse) 

# Load the Combine tracking file 
combine_tracking <- read_csv("data/combine_tracking.csv")

# Keep only the run the hoop drill, players only (not ball)
hoop <- combine_tracking |>
    filter(drill_name == "RUN_THE_HOOP_DRILL", 
            entity_type == "PLAYER")

# Put each try in time order and add a clock (10 frames/sec) 
hoop <- hoop |>
    arrange(nfl_id, attempt, time) |>
    group_by(nfl_id, attempt) |>
    mutate(frame = row_number(), 
            sec     = (frame - 1) / 10) |>
    ungroup()
cat("Players:", n_distinct(hoop$nfl_id), "\n")

# Picture: one player's path around the hoops, colored by speed 
plot_hoop <- hoop |>
    filter(nfl_id == 55877) |>
    ggplot(aes( x = x, y = y, colour = s)) + 
    geom_path(linewidth = 1) +
    coord_equal() + 
    scale_colour_viridis_c(name = "Speed\n(yd/s)") + 
    labs(title = "Run the hoop drill: a figure-8 around two hoops", 
        x = "Field x (yards)", y = "Field y (yards)")

ggsave("output/A_hoop_path.png", plot_hoop, width = 7, height = 5, dpi = 100)

# Turn rate and cut force for every frame
# group_by() so lag() never looks across two different players or tries
# abs() = size of the turn, ignoring direction (figure-8 turns left AND right)
hoop <- hoop |>
    group_by(nfl_id, attempt) |>
    mutate(ddir      = dir - lag(dir),
           ddir      = ((ddir + 180) %% 360) - 180,
           turn_rate = abs(ddir) * 10,
           turn_rate = if_else(s < 1.5, NA, turn_rate),
           cut_force = s * turn_rate * pi / 180) |>
    ungroup()

# For each try, keep the moment of hardest bend 
bend_tries <- hoop |>
    group_by(nfl_id, attempt) |>
    slice_max(cut_force, n = 1, with_ties = FALSE) |>
    ungroup() 

# One row per player: average the tries (10 playerrs ran it twice) 
bend <- bend_tries |>
    group_by(nfl_id) |>
    summarise(draft_year = first(draft_year), 
                attempts    = n(), 
                bend    = mean(cut_force), 
                bend_speed  = mean(s))

# Grade bend on a curve within each draft year
bend <- bend |>
    group_by(draft_year) |>
    mutate(bend_z = (bend - mean(bend)) / sd(bend)) |>
    ungroup()

print(bend)
print(summary(bend))

# Save handoff file
write_csv(bend, "output/combine_dl_bend.csv")
