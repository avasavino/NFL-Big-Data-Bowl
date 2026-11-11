library(tidyverse)

combine_wr <- read_csv("data/combine_results.csv", show_col_types = FALSE) |>
  filter(combine_position == "WR") |>
  select(nfl_id)

regular_season <- read_csv("data/games.csv", show_col_types = FALSE) |>
  filter(season_type == "REG") |>
  select(game_id)

plays <- read_csv(
  "data/player_play.csv",
  col_types = cols_only(
    game_id = col_double(),
    play_id = col_double(),
    nfl_id = col_double(),
    down = col_double(),
    yards_to_go = col_double(),
    lined_up_position = col_character(),
    receiver_alignment = col_character(),
    team_coverage_man_zone = col_character(),
    route_ran = col_character(),
    separation_at_pass_forward = col_double(),
    cushion = col_double()
  )
)

slants <- plays |>
  inner_join(combine_wr, by = "nfl_id") |>
  inner_join(regular_season, by = "game_id") |>
  filter(route_ran == "SLANT", !is.na(separation_at_pass_forward))

slants |>
  summarise(
    slants = n(),
    receivers = n_distinct(nfl_id),
    median_sep = median(separation_at_pass_forward),
    min_sep = min(separation_at_pass_forward),
    max_sep = max(separation_at_pass_forward)
  ) |>
  print()

slants |>
  count(nfl_id) |>
  pull(n) |>
  quantile() |>
  print()

sep_hist <- ggplot(slants, aes(x = separation_at_pass_forward)) +
  geom_histogram(binwidth = 0.5, boundary = 0, fill = "steelblue", color = "white") +
  geom_vline(xintercept = median(slants$separation_at_pass_forward), linetype = "dashed") +
  labs(
    title = "Separation on NFL slants",
    x = "Yards from nearest defender when the ball is thrown",
    y = "Number of slants"
  ) +
  theme_minimal(base_size = 14)

print(sep_hist)
ggsave("output/B_01_separation_hist.png", sep_hist, width = 8, height = 5, bg = "white")

write_rds(slants, "output/B_slants.rds")
