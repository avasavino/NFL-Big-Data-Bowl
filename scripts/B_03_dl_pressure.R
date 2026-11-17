library(tidyverse)

combine_dl <- read_csv("data/combine_results.csv", show_col_types = FALSE) |>
  filter(combine_position == "DL") |>
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
    lined_up_position = col_character(),
    player_get_off = col_double(),
    time_to_pressure = col_double(),
    sack = col_double()
  )
)

rush_snaps <- plays |>
  inner_join(combine_dl, by = "nfl_id") |>
  inner_join(regular_season, by = "game_id") |>
  filter(!is.na(player_get_off) | !is.na(time_to_pressure)) |>
  mutate(
    pressure = !is.na(time_to_pressure),
    fast_pressure = pressure & time_to_pressure <= 2.5,
    sack = replace_na(sack, 0)
  )

pressure <- rush_snaps |>
  group_by(nfl_id) |>
  summarise(
    rush_snaps = n(),
    pressures = sum(pressure),
    pressure_rate = pressures / rush_snaps,
    sacks = sum(sack),
    sack_rate = sacks / rush_snaps,
    fast_pressures = sum(fast_pressure),
    fast_pressure_rate = fast_pressures / rush_snaps,
    edge_share = mean(lined_up_position == "EDGE", na.rm = TRUE),
    .groups = "drop"
  )

overall_rate <- mean(rush_snaps$pressure)
snap_var <- var(rush_snaps$pressure)
player_var <- var(pressure$pressure_rate) - mean(snap_var / pressure$rush_snaps)
shrink_k <- snap_var / player_var

cat("Shrinkage k:", round(shrink_k, 1), "rush snaps\n")

pressure <- pressure |>
  mutate(pressure_rate_shrunk = (pressures + shrink_k * overall_rate) / (rush_snaps + shrink_k)) |>
  select(nfl_id, rush_snaps, pressures, pressure_rate, pressure_rate_shrunk,
         sacks, sack_rate, fast_pressures, fast_pressure_rate, edge_share) |>
  arrange(desc(rush_snaps))

regulars <- pressure |> filter(rush_snaps >= 100)

tibble(
  dl_with_rush_snaps = nrow(pressure),
  dl_with_100_plus = nrow(regulars),
  total_rush_snaps = sum(pressure$rush_snaps),
  overall_pressure_rate = overall_rate,
  median_rate_100_plus = median(regulars$pressure_rate),
  median_snaps_100_plus = median(regulars$rush_snaps)
) |>
  print(width = Inf)

print(summary(pressure))

write_csv(pressure, "output/nfl_dl_pressure.csv")
write_rds(rush_snaps |> select(game_id, play_id, nfl_id), "output/B_dl_rush_snaps.rds")
