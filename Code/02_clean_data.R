# ===========================================================================
# Script:   02_clean_data.R
# Project:  Tucson Homelessness Digital Traces
# Purpose:  Build the analysis dataset from the raw scrape:
#             - parse dates and filter to project window (2024-2025)
#             - remove [deleted] / [removed] / common bot content
#             - anonymize (replace usernames with stable integer IDs)
#             - link comments to their parent thread
#             - write summary stats
#
# Inputs:   Data/raw_posts.csv
#           Data/raw_comments.csv
# Outputs:  Data/analysis_posts.csv
#           Data/analysis_comments.csv
#           Results/data_summary.csv
# ===========================================================================

# --- Packages --------------------------------------------------------------
required <- c("dplyr", "readr", "lubridate", "stringr", "tidyr")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install)

library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(tidyr)

# --- Ensure output directory exists ---------------------------------------
if (!dir.exists("Results")) dir.create("Results")

# --- Load raw data --------------------------------------------------------
posts_raw    <- read_csv("Data/raw_posts.csv",    show_col_types = FALSE)
comments_raw <- read_csv("Data/raw_comments.csv", show_col_types = FALSE)

cat(sprintf("Loaded %d raw posts and %d raw comments.\n",
            nrow(posts_raw), nrow(comments_raw)))

# Helper: safely parse `date` column whether it arrives as Date or string
parse_date_safe <- function(x) {
  suppressWarnings(as.Date(x))
}

# --- Clean posts ----------------------------------------------------------
posts_clean <- posts_raw %>%
  mutate(
    date      = parse_date_safe(date),
    title     = ifelse(is.na(title), "", title),
    text      = ifelse(is.na(text),  "", text),
    full_text = str_squish(paste(title, text))
  ) %>%
  # project date window
  filter(!is.na(date),
         date >= ymd("2025-05-01"),
         date <= ymd("2026-05-31")) %>%
  # drop deleted/removed
  filter(!str_detect(full_text, "^\\[deleted\\]"),
         !str_detect(full_text, "^\\[removed\\]")) %>%
  # anonymize: map author -> stable integer
  mutate(author_id = as.integer(factor(author))) %>%
  select(-author) %>%
  distinct(url, .keep_all = TRUE)

# --- Clean comments -------------------------------------------------------
comments_clean <- comments_raw %>%
  mutate(date = parse_date_safe(date)) %>%
  filter(!is.na(date),
         date >= ymd("2025-05-01"),
         date <= ymd("2026-05-31")) %>%
  filter(!comment %in% c("[deleted]", "[removed]"),
         !is.na(comment),
         nchar(comment) > 1) %>%
  # filter common automod / bot patterns
  filter(!str_detect(comment, "^I am a bot"),
         !str_detect(comment, "performed automatically")) %>%
  mutate(author_id = as.integer(factor(author))) %>%
  select(-author)

# --- Link comments only to retained posts ---------------------------------
analysis_comments <- comments_clean %>%
  semi_join(posts_clean, by = "url")

# --- Save analysis datasets -----------------------------------------------
write_csv(posts_clean,        "Data/analysis_posts.csv")
write_csv(analysis_comments,  "Data/analysis_comments.csv")

# --- Summary table --------------------------------------------------------
summary_tbl <- tibble(
  metric = c(
    "raw_posts",            "raw_comments",
    "analysis_posts",       "analysis_comments",
    "date_range_start",     "date_range_end",
    "unique_post_authors",  "unique_comment_authors",
    "median_score_post",    "median_comments_per_post"
  ),
  value = c(
    nrow(posts_raw),                       nrow(comments_raw),
    nrow(posts_clean),                     nrow(analysis_comments),
    as.character(min(posts_clean$date)),   as.character(max(posts_clean$date)),
    length(unique(posts_clean$author_id)),
    length(unique(analysis_comments$author_id)),
    median(posts_clean$score, na.rm = TRUE),
    round(nrow(analysis_comments) / max(nrow(posts_clean), 1), 1)
  )
)

write_csv(summary_tbl, "Results/data_summary.csv")
cat("\nData summary:\n")
print(summary_tbl)

cat(sprintf("\nWrote %d analysis posts and %d analysis comments.\n",
            nrow(posts_clean), nrow(analysis_comments)))
