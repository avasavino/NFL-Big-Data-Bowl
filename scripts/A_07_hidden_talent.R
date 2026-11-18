# ============================================================
# Goal : find linemen the draft undervalued (high bend, late pick)
#   and overvalued (low bend, early pick) 
# ============================================================

library(tidyverse) 
library(ggrepel) 

bend    <- read_csv("output/combine_dl_bend.csv", show_col_types = FALSE)
pressure    <- read_csv("output/nfl_dl_pressure.csv", show_col_types = FALSE) 
draft   <- read_csv("data/players.csv", show_col_types = FALSE) |>
    select(nfl_id, display_name, draft_round, draft_overall_pick)

linemen <- bend |>
    inner_join(pressure, by = "nfl_id") |>
    left_join(draft, by = "nfl_id") |>
    filter(rush_snaps >= 100) |>
    mutate(draft_pick = replace_na(draft_overall_pick, 260), 
        role    = if_else(edge_share >= 0.5, "Edge", "Interior"))

# What pressure would we expect from draft pick alone 
draft_only_model <- lm(pressure_rate ~ log(draft_pick) + factor(draft_year), 
                        data = linemen) 

linemen <- linemen |>
    mutate(expected = fitted(draft_only_model), 
            over_expected = pressure_rate - expected)

# Do high-bend players beat their draft expectations 
cor.test(linemen$bend_z, linemen$over_expected) |> print()

# Hidden gems: above avg bend (bend_z >= 0.5), drafted 100 or later 
gems <- linemen |>
    filter(bend_z >= 0.5, draft_pick >= 100) |>
    arrange(desc(pressure_rate)) |>
    transmute(player    = display_name, 
            year    = draft_year, 
            round   = draft_round, 
            pick    = draft_overall_pick, 
            role, 
            bend_z  = round(bend_z, 2),
            rushes  = rush_snaps, 
            pressure    = round(pressure_rate * 100, 1), 
            expected    = round(expected * 100, 1))
print(gems)

# Possible busts: below avg bend (bend_z <= -0.5), drafted in the first 64 picks 
busts <- linemen |>
    filter(bend_z <= -0.5, draft_pick <= 64) |>
    arrange(pressure_rate) |>
    transmute(player    = display_name, 
                year    = draft_year, 
                round   = draft_round, 
                pick    = draft_overall_pick, 
                role, 
                bend_z  = round(bend_z, 2), 
                rushes  = rush_snaps, 
                pressure    = round(pressure_rate * 100, 1), 
                expected    = round(expected * 100, 1))
print(busts) 

# Players to label by name on the chart 
label_these <- c("Cedric Johnson", "Javon Solomon", "Jack Sawyer", 
                    "Adetomiwa Adebawore", "Darius Robinson", "Alfred Collins", 
                    "Jared Verse")

plot_talent <- linemen |>
    ggplot(aes(x = bend_z, y = over_expected * 100)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "#52514e") +
    geom_smooth(method = "lm", colour = "#0b0b0b", se = FALSE, linewidth = 0.7) +
    geom_point(aes(colour = role, shape = role), size = 2.8) +
    geom_text_repel(data = linemen |> filter(display_name %in% label_these),
                    aes(label = display_name), size = 3, colour = "#52514e", seed = 1) +
    scale_colour_manual(values = c(Edge = "#2a78d6", Interior = "#eb6834")) +
    scale_shape_manual(values = c(Edge = 16, Interior = 17)) +
    labs(title = "High-bend linemen beat their draft slot",
            subtitle = "NFL pressure rate above or below what draft position predicted, 63 defensive linemen",
            x = "Combine bend, run the hoop drill (SDs above his draft class)",
            y = "Pressure vs. draft expectation\n(percentage points)", 
            colour = NULL, shape = NULL, 
            caption = "Expected pressure = prediction from draft pick and draft year only. Regular season, 100+ pass rushes.") + 
    theme_minimal(base_size = 12) + 
    theme(legend.position = "top", legend.justification = "left", 
    panel.grid.minor = element_blank(), 
    plot.title = element_text(face = "bold"), 
    plot.caption = element_text(size = 8, hjust = 0))

ggsave("output/A_hidden_talent.png", plot_talent, width = 8, height = 5.5, dpi = 150, bg = "white")
