library(tidyverse)

slants <- read_rds("output/B_slants.rds") |>
  mutate(
    team_coverage_man_zone = replace_na(team_coverage_man_zone, "UNKNOWN"),
    receiver_alignment = replace_na(receiver_alignment, "UNKNOWN"),
    down = factor(down)
  )

expected_model <- lm(
  separation_at_pass_forward ~ cushion + team_coverage_man_zone + receiver_alignment +
    lined_up_position + down + yards_to_go,
  data = slants,
  na.action = na.exclude
)

print(summary(expected_model))

slants <- slants |>
  mutate(sep_oe_play = residuals(expected_model))

players <- slants |>
  group_by(nfl_id) |>
  summarise(
    n_slants = n(),
    avg_sep = mean(separation_at_pass_forward),
    n_modeled = sum(!is.na(sep_oe_play)),
    sum_oe = sum(sep_oe_play, na.rm = TRUE),
    .groups = "drop"
  )

play_var <- var(slants$sep_oe_play, na.rm = TRUE)
player_means <- players |> filter(n_modeled > 0)
player_var <- var(player_means$sum_oe / player_means$n_modeled) - mean(play_var / player_means$n_modeled)
shrink_k <- play_var / player_var

cat("Shrinkage: each player is pulled toward 0 as if he had", round(shrink_k, 1), "extra average slants\n")

separation <- players |>
  mutate(sep_oe = sum_oe / (n_modeled + shrink_k)) |>
  select(nfl_id, n_slants, avg_sep, sep_oe) |>
  arrange(desc(sep_oe))

print(summary(separation))
print(head(separation, 10))

write_csv(separation, "output/nfl_slant_separation.csv")
