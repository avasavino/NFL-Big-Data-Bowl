library(tidyverse)  # turn on the tidyverse toolbox (read_csv, mutate, ggplot, etc.)
library(ggrepel)  # labels that move out of each other's way

bend <- read_csv("output/combine_dl_bend.csv", show_col_types = FALSE)  # Person A's Combine bend, one row per lineman
pressure <- read_csv("output/nfl_dl_pressure.csv", show_col_types = FALSE)  # my NFL pass-rush results, one row per lineman
weight <- read_csv("data/combine_results.csv", show_col_types = FALSE) |>  # Combine measurements
  select(nfl_id, combine_weight)  # keep only player ID and body weight
draft <- read_csv("data/players.csv", show_col_types = FALSE) |>  # player names and draft info
  select(nfl_id, display_name, draft_overall_pick)  # keep only ID, name and draft pick

linemen <- bend |>  # start from the linemen with Combine bend
  inner_join(pressure, by = "nfl_id") |>  # keep those who also have NFL pass rushes
  left_join(weight, by = "nfl_id") |>  # attach body weight
  left_join(draft, by = "nfl_id") |>  # attach name and draft pick
  filter(rush_snaps >= 100) |>  # keep linemen with at least 100 NFL pass rushes, same as the main model
  mutate(
    log_pick = log(replace_na(draft_overall_pick, 260)),  # undrafted players get pick 260, then squish the scale with log, same as the main model
    role = if_else(edge_share >= 0.5, "Edge", "Interior")  # edge rusher if at least half his rushes came from the edge
  )

main_model <- lm(  # the same main model as scripts/C_join_and_model.R
  pressure_rate ~ bend_z + factor(draft_year) + log_pick + combine_weight + edge_share,  # pressure explained by bend plus the controls
  data = linemen  # use the 100+ rush linemen
)

slope <- coef(main_model)[["bend_z"]]  # extra pressure rate for each 1 standard deviation of bend
slope_se <- summary(main_model)$coefficients["bend_z", "Std. Error"]  # how uncertain that slope is
p_value <- summary(main_model)$coefficients["bend_z", "Pr(>|t|)"]  # chance of a slope this big from luck alone
mean_bend <- mean(linemen$bend_z)  # the group's average bend
mean_pressure <- mean(linemen$pressure_rate)  # the group's average pressure rate

linemen <- linemen |>  # add the adjusted pressure rate for each player
  mutate(adjusted_pressure = mean_pressure + slope * (bend_z - mean_bend) + resid(main_model))  # his pressure rate with draft year, pick, weight and role evened out

fit_line <- tibble(bend_z = seq(min(linemen$bend_z), max(linemen$bend_z), length.out = 100)) |>  # 100 evenly spaced bend values across the range
  mutate(
    fit = mean_pressure + slope * (bend_z - mean_bend),  # the model's line through the middle of the data
    low = fit - 1.96 * slope_se * abs(bend_z - mean_bend),  # bottom of the 95% band for the slope
    high = fit + 1.96 * slope_se * abs(bend_z - mean_bend)  # top of the 95% band for the slope
  )

labeled <- linemen |>  # pick a few players to name on the chart
  filter(rank(bend_z) <= 3 | rank(-bend_z) <= 3)  # the 3 lowest and 3 highest bend players

cat("Players:", nrow(linemen), "\n")  # how many linemen are on the chart
cat("Slope:", round(slope * 100, 2), "percentage points of pressure per 1 SD of bend, p =", signif(p_value, 2), "\n")  # the headline number

adjusted_plot <- ggplot(linemen, aes(x = bend_z, y = adjusted_pressure * 100)) +  # bend across, adjusted pressure (as a percent) up
  geom_ribbon(data = fit_line, aes(y = NULL, ymin = low * 100, ymax = high * 100), fill = "#52514e", alpha = 0.12) +  # light gray band showing slope uncertainty
  geom_line(data = fit_line, aes(y = fit * 100), color = "#0b0b0b", linewidth = 0.7) +  # the model's line
  geom_point(aes(color = role, shape = role), size = 2.8, stroke = 0.6) +  # one dot per lineman, colored and shaped by role
  geom_text_repel(data = labeled, aes(label = display_name), size = 3, color = "#52514e", min.segment.length = 0, box.padding = 0.6, point.padding = 0.4, seed = 1) +  # name the 6 most extreme bend players, kept clear of the dots
  scale_x_continuous(expand = expansion(mult = c(0.1, 0.12))) +  # extra room at both ends so the names fit
  scale_color_manual(values = c(Edge = "#2a78d6", Interior = "#eb6834")) +  # blue for edge, orange for interior
  scale_shape_manual(values = c(Edge = 16, Interior = 17)) +  # circles for edge, triangles for interior, so color isn't the only clue
  labs(
    title = "More bend at the Combine, more pressure in the NFL",  # the finding in plain words
    subtitle = sprintf(  # the numbers behind it, filled in from the model
      "+%.2f percentage points of pressure per 1 SD of bend (p = %.3f), %d defensive linemen",
      slope * 100, p_value, nrow(linemen)
    ),
    x = "Combine bend, run the hoop drill (SDs above his draft class)",  # what the bottom axis means
    y = "Adjusted NFL pressure rate (%)",  # what the side axis means
    color = NULL,  # no legend title
    shape = NULL,  # no legend title
    caption = "Pressure rate adjusted for draft year, draft pick, Combine weight and edge share. Regular season, 100+ pass rushes. Band = 95% CI for the slope."  # how it was adjusted
  ) +
  theme_minimal(base_size = 12) +  # a clean, simple look
  theme(
    plot.background = element_rect(fill = "#fcfcfb", color = NA),  # off-white background
    panel.grid.minor = element_blank(),  # remove the faint in-between grid lines
    panel.grid.major = element_line(color = "#e8e7e2", linewidth = 0.3),  # keep main grid lines light
    plot.title = element_text(color = "#0b0b0b", face = "bold"),  # dark bold title
    plot.subtitle = element_text(color = "#52514e"),  # gray subtitle
    plot.caption = element_text(color = "#52514e", size = 8, hjust = 0),  # small gray note at the bottom left
    axis.title = element_text(color = "#52514e"),  # gray axis titles
    axis.text = element_text(color = "#52514e"),  # gray axis numbers
    legend.position = "top",  # legend above the chart
    legend.justification = "left",  # legend lined up on the left
    legend.text = element_text(color = "#0b0b0b")  # dark legend text
  )

print(adjusted_plot)  # show the chart
ggsave("output/B_05_adjusted_pressure_vs_bend.png", adjusted_plot, width = 8, height = 5.5, dpi = 150, bg = "#fcfcfb")  # save it for the paper
