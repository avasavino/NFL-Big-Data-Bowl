library(tidyverse)

rush_snaps <- read_rds("output/B_dl_rush_snaps.rds") |>
  mutate(across(c(game_id, play_id, nfl_id), as.integer))

season_bend <- function(year) {
  frames <- data.table::fread(
    sprintf("data/game_tracking_%d.csv", year),
    select = c("game_id", "play_id", "nfl_id", "time", "s", "dir", "event")
  )
  frames <- as_tibble(frames) |>
    semi_join(rush_snaps, by = c("game_id", "play_id", "nfl_id"))

  plays <- frames |>
    group_by(game_id, play_id, nfl_id) |>
    arrange(time, .by_group = TRUE) |>
    mutate(
      snap_time = first(time[event %in% "ball_snap"]),
      end_time = min(
        time[event %in% c("pass_forward", "qb_sack") & time >= snap_time],
        snap_time + 3
      )
    ) |>
    filter(!is.na(snap_time), time >= snap_time, time <= end_time) |>
    mutate(
      ddir = ((dir - lag(dir) + 180) %% 360) - 180,
      turn_rate = if_else(s < 1.5, NA_real_, abs(ddir) * 10),
      lateral_accel = s * turn_rate * pi / 180
    ) |>
    filter(any(!is.na(lateral_accel))) |>
    summarise(game_bend_play = max(lateral_accel, na.rm = TRUE), .groups = "drop")

  cat(year, ":", nrow(plays), "rush snaps with game bend\n")
  rm(frames)
  gc()
  plays
}

play_bend <- map(2023:2025, season_bend) |> list_rbind()

players <- play_bend |>
  group_by(nfl_id) |>
  summarise(
    n_rushes = n(),
    game_bend = mean(game_bend_play),
    sum_bend = sum(game_bend_play),
    .groups = "drop"
  )

overall_bend <- mean(play_bend$game_bend_play)
play_var <- var(play_bend$game_bend_play)
player_var <- var(players$game_bend) - mean(play_var / players$n_rushes)
shrink_k <- play_var / player_var
median_n <- median(players$n_rushes)

cat("Shrinkage k:", round(shrink_k, 1), "rushes\n")
cat("Reliability at median n_rushes (", median_n, "):", round(median_n / (median_n + shrink_k), 2), "\n")

game_bend <- players |>
  mutate(game_bend_shrunk = (sum_bend + shrink_k * overall_bend) / (n_rushes + shrink_k)) |>
  select(nfl_id, n_rushes, game_bend, game_bend_shrunk) |>
  arrange(desc(n_rushes))

print(summary(game_bend))

write_csv(game_bend, "output/nfl_dl_game_bend.csv")
