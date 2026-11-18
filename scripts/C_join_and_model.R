# ============================================================
# Goal: does Combine bend predict NFL pressure rate, after 
#   accounting for draft year, draft pick, weight and role?
# ============================================================

library(tidyverse) 

# A: bend on the run the hoop drill 
bend <- read_csv("output/combine_dl_bend.csv")

# B: NFL regular-season pass rush results 
pressure <- read_csv("output/nfl_dl_pressure.csv")

# Body weight from the Combine 
weight <- read_csv("data/combine_results.csv") |>
    select(nfl_id, combine_weight)

# Player names and draft pick 
draft <- read_csv("data/players.csv") |>
    select(nfl_id, display_name, draft_overall_pick)

# Gluy by player ID 
# inner_join - keeps linement who have BOTH bend and NFL pressure 
linemen <- bend |>
    inner_join(pressure, by = "nfl_id") |>
    left_join(weight, by = "nfl_id") |>
    left_join(draft, by = "nfl_id")
cat("Linemen with bend AND NFL rushes:", nrow(linemen), "\n")

# Keep only linement with at least 100 NFL pass rushes 
linemen <- linemen |>
    filter(rush_snaps >= 100) 
cat("With 100+ rushes:", nrow(linemen), "\n")

# Undrafted players have no pick number - give them 260 (after last pick) 
# log() squishes the scale - pick 1 vs 10 matters more than pick 200 vs 210 
linemen <- linemen |>
    mutate(draft_pick = replace_na(draft_overall_pick, 260), 
        log_pick = log(draft_pick))

#THE MAIN MODEL 
# pressure rate explained by bend
main_model <- lm(pressure_rate ~ bend_z + factor(draft_year) + log_pick +
                    combine_weight + edge_share, 
                data = linemen)
print(summary(main_model))

# Check 1: Person B's "shrunk" pressure rate (small samples pulled toward average)
shrunk_model <- lm(pressure_rate_shrunk ~ bend_z + factor(draft_year) + log_pick +
                       combine_weight + edge_share,
                   data = linemen)
print(summary(shrunk_model)$coefficients["bend_z", ])

# Check 2: does it hold in EVERY draft class?
linemen |>
    group_by(draft_year) |>
    summarise(players = n(),
              correlation = cor(bend_z, pressure_rate)) |>
    print()

# Check 3: split into edge rushers and interior linemen
# Edge = lined up on the edge for at least half his rushes 
linemen <- linemen |>
    mutate(role = if_else(edge_share >= 0.5, "Edge", "Interior"))

linemen |> count(role) |> print()

# Same model on each group 
edge_model <- lm(pressure_rate ~ bend_z + factor(draft_year) + log_pick + combine_weight, 
                data = linemen |> filter(role == "Edge"))
interior_model <- lm(pressure_rate ~ bend_z + factor(draft_year) + log_pick + combine_weight, 
                    data = linemen |> filter(role == "Interior"))

print(summary(edge_model)$coefficients["bend_z", ])
print(summary(interior_model)$coefficients["bend_z", ])

# Split linemen into 3 equal groups by bend: low, middle, high
linemen <- linemen |>
    mutate(bend_group = ntile(bend_z, 3),
            bend_group = factor(bend_group, labels = c("Low bend", "Middle bend", "High bend")))

# Average pressure rate in each group 
bend_groups <- linemen |>
    group_by(bend_group) |>
    summarise(players = n(), 
                pressure = mean(pressure_rate))
print(bend_groups)

# Bar chart 
plot_groups <- bend_groups |>
    ggplot(aes(x = bend_group, y = pressure * 100)) + 
    geom_col(fill = "steelblue") + 
    geom_text(aes(label = sprintf("%.1f%%", pressure * 100)), vjust = -0.5) +
    labs(title = "High-bend linemen pressure the quarterback more often", 
        subtitle = "NFL regular season, 63 defensive linemen with 100+ pass rushes", 
        x = "Bend at the Combine (run the hoop drill)", 
        y = "Pressure rate (%)")

ggsave("output/C_pressure_by_bend_group.png", plot_groups, width = 7, height = 5, dpi = 100)
