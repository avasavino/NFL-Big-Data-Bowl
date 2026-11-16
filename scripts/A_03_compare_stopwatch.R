# ============================================================
# Goal: check if cut force is just the 40-yd dash in disguise 
# ============================================================

library(tidyverse)

# My slant scores (one row per receiver)
metrics <- read_csv("output/combine_slant_metrics.csv")

# The regular stopwatch Combine results - only some columns
stopwatch <- read_csv("data/combine_results.csv") |>
    select(nfl_id, forty, three_cone, short_shuttle)

# Glue them together by player ID 
compare <- metrics |>
    left_join(stopwatch, by = "nfl_id")

# Not every player ran each drill - count how many & how many times 
compare |>
    summarise(have_forty   = sum(!is.na(forty)),
                have_three_cone = sum(!is.na(three_cone)),
                have_shuttle    = sum(!is.na(short_shuttle))) |>
    print()

# Correlation: does cut force line up with the 40 time?
print(cor.test(compare$cut_force, compare$forty))

# Scatter plot: each dot is one receiver
plot_forty <- compare |>
    ggplot(aes(x = forty, y = cut_force)) +
    geom_point() +
    geom_smooth (method = "lm") +
    labs(title = "Cut force has almost nothing to do with 40-yard dash time",
        x = "40-yard dash (seconds, lower = faster)", 
        y = "Cut force (yards per second squared)")
        
ggsave("output/A_cutforce_vs_forty.png", plot_forty, width = 7, height = 5, dpi = 100)
