library(tidyverse)  # turn on the tidyverse toolbox (read_csv, filter, mutate, etc.)

rush_snaps <- read_rds("output/B_dl_rush_snaps.rds") |>  # load the DL rush snaps that B_03 saved
  mutate(across(c(game_id, play_id, nfl_id), as.integer))  # make the ID columns whole numbers so they match the tracking files

alignments <- read_csv(  # read the play-by-play file, but only the columns we need
  "data/player_play.csv",  # the file with one row per player per NFL play
  col_types = cols_only(  # name each column we want and its type, and skip the rest
    game_id = col_integer(),  # which game
    play_id = col_integer(),  # which play in that game
    nfl_id = col_integer(),  # which player
    lined_up_position = col_character()  # where he lined up on that play (EDGE, INTERIOR_LINE, ...)
  )
)

season_bend <- function(year) {  # a recipe that measures bend on every rush in one season
  frames <- data.table::fread(  # read one season's tracking file quickly
    sprintf("data/game_tracking_%d.csv", year),  # build the file name, like data/game_tracking_2023.csv
    select = c("game_id", "play_id", "nfl_id", "time", "s", "dir", "event")  # only load these 7 columns to save memory
  )
  frames <- as_tibble(frames) |>  # turn it into a regular tidyverse table
    semi_join(rush_snaps, by = c("game_id", "play_id", "nfl_id"))  # keep only rows for DL rush snaps from B_03

  plays <- frames |>  # start from this season's rush-snap frames
    group_by(game_id, play_id, nfl_id) |>  # treat each player on each play as its own pile
    arrange(time, .by_group = TRUE) |>  # put each pile in time order
    mutate(
      snap_time = first(time[event %in% "ball_snap"]),  # the moment the ball was snapped
      end_time = min(  # the rush window ends at whichever comes first:
        time[event %in% c("pass_forward", "qb_sack") & time >= snap_time],  # the pass or the sack after the snap
        snap_time + 3  # or 3 seconds after the snap
      )
    ) |>
    filter(!is.na(snap_time), time >= snap_time, time <= end_time) |>  # keep only frames inside the rush window
    mutate(
      ddir = ((dir - lag(dir) + 180) %% 360) - 180,  # change in direction since the last frame, fixed so 359 to 1 counts as a 2-degree turn
      turn_rate = if_else(s < 1.5, NA_real_, abs(ddir) * 10),  # degrees turned per second, blank when he is nearly standing still
      lateral_accel = s * turn_rate * pi / 180  # sideways acceleration: speed times turn rate (turn rate changed to radians)
    ) |>
    filter(any(!is.na(lateral_accel))) |>  # drop rushes where he never moved fast enough to measure a turn
    summarise(game_bend_play = max(lateral_accel, na.rm = TRUE), .groups = "drop") |>  # one number per rush: his hardest sideways acceleration
    mutate(season = year)  # remember which season this rush came from

  cat(year, ":", nrow(plays), "rush snaps with game bend\n")  # print how many rushes we measured this season
  rm(frames)  # delete the big tracking table
  gc()  # give that memory back to the computer before the next season
  plays  # hand back this season's rushes
}

play_bend <- map(2023:2025, season_bend) |>  # run the recipe for each of the 3 seasons
  list_rbind() |>  # stack the 3 seasons into one table
  left_join(alignments, by = c("game_id", "play_id", "nfl_id"))  # attach where he lined up on each rush

players <- play_bend |>  # start from every measured rush
  group_by(nfl_id) |>  # one pile per player
  summarise(
    n_rushes = n(),  # how many rushes we measured for him
    game_bend = mean(game_bend_play),  # his average bend per rush
    sum_bend = sum(game_bend_play),  # his total bend, used for shrinkage below
    .groups = "drop"  # un-pile the table
  )

overall_bend <- mean(play_bend$game_bend_play)  # the average bend across all rushes
play_var <- var(play_bend$game_bend_play)  # how much bend bounces around from rush to rush
player_var <- var(players$game_bend) - mean(play_var / players$n_rushes)  # how much players truly differ, after removing luck
shrink_k <- play_var / player_var  # how many average rushes to blend in with each player
median_n <- median(players$n_rushes)  # the typical number of rushes per player

cat("Shrinkage k:", round(shrink_k, 1), "rushes\n")  # print k
cat("Reliability at median n_rushes (", median_n, "):", round(median_n / (median_n + shrink_k), 2), "\n")  # print how much we trust a typical player's number

role_plays <- play_bend |>  # start from every measured rush
  filter(lined_up_position %in% c("EDGE", "INTERIOR_LINE")) |>  # keep only edge and interior rushes, and drop the rare other spots
  group_by(season, lined_up_position) |>  # one pile per season and alignment
  mutate(
    role_average = mean(game_bend_play),  # the average bend for that alignment in that season
    bend_oe_play = game_bend_play - role_average  # how much more bend he showed than expected for his role
  ) |>
  ungroup()  # un-pile the table

role_plays |>  # show the role averages so we can check them
  distinct(season, lined_up_position, role_average) |>  # one row per season and alignment
  arrange(lined_up_position, season) |>  # sort them so they're easy to read
  print()  # show them on screen

role_players <- role_plays |>  # start from the role-adjusted rushes
  group_by(nfl_id) |>  # one pile per player
  summarise(
    role_n = n(),  # how many edge or interior rushes he has
    game_bend_oe = mean(bend_oe_play),  # his average bend over expected for his role
    sum_oe = sum(bend_oe_play),  # his total bend over expected, used for shrinkage below
    edge_rushes = sum(lined_up_position == "EDGE"),  # how many of his rushes were from the edge
    interior_rushes = sum(lined_up_position == "INTERIOR_LINE"),  # how many were from the interior
    .groups = "drop"  # un-pile the table
  )

oe_play_var <- var(role_plays$bend_oe_play)  # how much role-adjusted bend bounces around from rush to rush
oe_player_var <- var(role_players$game_bend_oe) - mean(oe_play_var / role_players$role_n)  # how much players truly differ, after removing luck
oe_k <- oe_play_var / oe_player_var  # how many zero-bend rushes to blend in with each player
oe_median_n <- median(role_players$role_n)  # the typical number of role rushes per player

cat("Role-adjusted shrinkage k:", round(oe_k, 1), "rushes\n")  # print k
cat("Role-adjusted reliability at median n_rushes (", oe_median_n, "):", round(oe_median_n / (oe_median_n + oe_k), 2), "\n")  # print how much we trust a typical player's number

game_bend <- players |>  # start from the per-player table
  mutate(game_bend_shrunk = (sum_bend + shrink_k * overall_bend) / (n_rushes + shrink_k)) |>  # pull small samples toward the overall average
  left_join(role_players, by = "nfl_id") |>  # attach the role-adjusted numbers
  mutate(game_bend_oe_shrunk = sum_oe / (role_n + oe_k)) |>  # pull small samples toward 0, which means "average for his role"
  select(nfl_id, n_rushes, game_bend, game_bend_shrunk,  # the original columns, unchanged
         game_bend_oe, game_bend_oe_shrunk, edge_rushes, interior_rushes) |>  # the new columns at the end
  arrange(desc(n_rushes))  # sort players with the most rushes first

print(summary(game_bend))  # show a quick summary of every column

write_csv(game_bend, "output/nfl_dl_game_bend.csv")  # save the file for Person A
