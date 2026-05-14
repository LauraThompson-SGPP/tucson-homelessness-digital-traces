# ===========================================================================
# Script:   03_sentiment_analysis.R
# Project:  Tucson Homelessness Digital Traces
# Purpose:  Score sentiment on cleaned posts and comments using VADER
#           (Valence Aware Dictionary and sEntiment Reasoner). VADER is a
#           lexicon-based scorer tuned for social media text -- it handles
#           slang, emoji, intensifiers, and negation better than generic
#           lexicons (Bing, AFINN, NRC).
#
#           VADER returns four scores per document:
#             compound  -- standardized [-1, 1] overall sentiment
#             pos / neu / neg -- proportional breakdown
#
#           Conventional thresholds:
#             compound >=  0.05 -> positive
#             compound <= -0.05 -> negative
#             otherwise         -> neutral
#
# Inputs:   Data/analysis_posts.csv
#           Data/analysis_comments.csv
# Outputs:  Data/posts_with_sentiment.csv
#           Data/comments_with_sentiment.csv
#           Results/sentiment_summary.csv
#           Results/sentiment_posts_monthly.csv
#           Results/sentiment_comments_monthly.csv
# ===========================================================================

# --- Packages --------------------------------------------------------------
required <- c("vader", "dplyr", "readr", "lubridate", "tidyr")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install)

library(vader)
library(dplyr)
library(readr)
library(lubridate)
library(tidyr)

# --- Load cleaned data ----------------------------------------------------
posts    <- read_csv("Data/analysis_posts.csv",    show_col_types = FALSE)
comments <- read_csv("Data/analysis_comments.csv", show_col_types = FALSE)

# --- Scoring helper -------------------------------------------------------
# vader_df() handles a character vector and returns a data frame of scores.
# It IS slow on large inputs (esp. comments). Expect minutes-to-an-hour.
score_text <- function(text_vec) {
  text_vec <- ifelse(is.na(text_vec) | text_vec == "", " ", text_vec)
  scores <- vader_df(text_vec)
  scores %>% select(compound, pos, neu, neg)
}

# --- Score posts ----------------------------------------------------------
cat("Scoring posts...\n")
post_text   <- posts$full_text
post_scores <- score_text(post_text)
posts_sent  <- bind_cols(posts, post_scores)

write_csv(posts_sent, "Data/posts_with_sentiment.csv")
cat(sprintf("  scored %d posts.\n", nrow(posts_sent)))

# --- Score comments -------------------------------------------------------
cat("Scoring comments (this is the slow step)...\n")
comment_scores <- score_text(comments$comment)
comments_sent  <- bind_cols(comments, comment_scores)

write_csv(comments_sent, "Data/comments_with_sentiment.csv")
cat(sprintf("  scored %d comments.\n", nrow(comments_sent)))

# --- Aggregations: monthly time series ------------------------------------
posts_monthly <- posts_sent %>%
  mutate(month = floor_date(date, "month")) %>%
  group_by(month) %>%
  summarise(
    n_posts         = n(),
    mean_compound   = mean(compound,   na.rm = TRUE),
    median_compound = median(compound, na.rm = TRUE),
    pct_negative    = mean(compound <= -0.05, na.rm = TRUE),
    pct_positive    = mean(compound >=  0.05, na.rm = TRUE),
    .groups = "drop"
  )

comments_monthly <- comments_sent %>%
  mutate(month = floor_date(date, "month")) %>%
  group_by(month) %>%
  summarise(
    n_comments      = n(),
    mean_compound   = mean(compound,   na.rm = TRUE),
    median_compound = median(compound, na.rm = TRUE),
    pct_negative    = mean(compound <= -0.05, na.rm = TRUE),
    pct_positive    = mean(compound >=  0.05, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(posts_monthly,    "Results/sentiment_posts_monthly.csv")
write_csv(comments_monthly, "Results/sentiment_comments_monthly.csv")

# --- Overall summary ------------------------------------------------------
overall <- tibble(
  source       = c("posts", "comments"),
  n            = c(nrow(posts_sent), nrow(comments_sent)),
  mean_compound = c(mean(posts_sent$compound,    na.rm = TRUE),
                    mean(comments_sent$compound, na.rm = TRUE)),
  pct_negative = c(mean(posts_sent$compound    <= -0.05, na.rm = TRUE),
                   mean(comments_sent$compound <= -0.05, na.rm = TRUE)),
  pct_positive = c(mean(posts_sent$compound    >=  0.05, na.rm = TRUE),
                   mean(comments_sent$compound >=  0.05, na.rm = TRUE))
)

write_csv(overall, "Results/sentiment_summary.csv")

cat("\nOverall sentiment summary:\n")
print(overall)
