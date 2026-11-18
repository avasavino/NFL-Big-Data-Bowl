# ============================================================
# Goal: check if bend is just bend weight and straight-line speed, 
#   or if it measures something new 
# ============================================================

library(tidyverse) 

# My bend scores 
bend <- read_csv("output/combine_dl_bend.csv")

# Traditional Combine measures, only the columns needed 
traditional <- read_csv("data/combine_results.csv") |>
    select(nfl_id, combine_weight, forty, ten_yd_split, three_cone, ngs_athleticism_score)

# Glue them together by player ID 
compare <- bend |>
    left_join(traditional, by = "nfl_id")

# Not every lineman ran every drill - count how many have each measure 
compare |>
    summarise(have_weight = sum(!is.na(combine_weight)), 
                have_forty = sum(!is.na(forty)),
                have_ten = sum(!is.na(ten_yd_split)),
                have_cone = sum(!is.na(three_cone)), 
                have_ngs = sum(!is.na(ngs_athleticism_score))) |>
    print()

# Correlation of bend with each traditional measure
compare |>
    summarise(weight    = cor(bend_z, combine_weight, use = "complete.obs"), 
                forty    = cor(bend_z, forty, use = "complete.obs"),
                ten_yd    = cor(bend_z, ten_yd_split, use = "complete.obs"), 
                three_cone  = cor(bend_z, three_cone, use = "complete.obs"),
                athleticism = cor(bend_z, ngs_athleticism_score, use = "complete.obs")) |>
    print()

# Are the two biggest links real or luck 
print(cor.test(compare$bend_z, compare$combine_weight))
print(cor.test(compare$bend_z, compare$forty))

# How much of bend can weight + 40 time+ athleticism explain togther 
overlap_model <- lm(bend_z ~ combine_weight + forty + ngs_athleticism_score, 
                    data = compare)
cat("Share of bend explained by weight + 40 + athleticism:", 
    round(summary(overlap_model)$r.squared, 2), "\n")

# Scatter plot: bend vs body weight, one dot per lineman
plot_weight <- compare |>
    ggplot(aes(x = combine_weight, y = bend_z)) +
    geom_point() +
    geom_smooth(method = "lm") +
    labs(title = "Lighter linemen bend a bit more, but weight explains only part of it", 
        x = "Body weight (lbs)", 
        y = "Bend (graded within draft year)")

ggsave("output/A_bend_vs_weight.png", plot_weight, width = 7, height = 5, dpi = 100)

