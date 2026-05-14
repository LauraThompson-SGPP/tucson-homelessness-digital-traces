# ===========================================================================
# Script:   01_collect_reddit_data.R
# Project:  Tucson Homelessness Digital Traces
# Purpose:  Scrape Reddit posts and comments from r/Tucson related to
#           homelessness using the RedditExtractoR package.
#
#           NOTE: No Reddit API key is required. RedditExtractoR queries
#           Reddit's public JSON endpoints (the same data you can see by
#           appending ".json" to any Reddit URL in a browser).
#
# Inputs:   None.
# Outputs:  Data/raw_posts.csv      -- one row per thread (post + metadata)
#           Data/raw_comments.csv   -- one row per comment, linked to thread
#                                      via the `url` column.
# ===========================================================================

# --- Install (if needed) and load packages --------------------------------
required <- c("RedditExtractoR", "dplyr", "readr", "lubridate", "purrr")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install)

library(RedditExtractoR)
library(dplyr)
library(readr)
library(lubridate)
library(purrr)

# --- Configuration --------------------------------------------------------
SUBREDDIT  <- "Tucson"

KEYWORDS <- c(
  "homeless", "homelessness", "encampment", "unhoused",
  "panhandling", "Santa Rita Park", "Prop 312",
  "Gospel Rescue Mission", "Sister Jose", "Z Mansion"
)

# Reddit's native search returns different results depending on sort order;
# running multiple sorts and deduping maximizes coverage.
SORT_OPTIONS <- c("new", "top", "relevance")

# Time-period filter for the search call ("hour","day","week","month",
# "year","all"). We use "year" then date-filter further in script 02.
PERIOD       <- "year"

# Ensure output directory exists
if (!dir.exists("Data")) dir.create("Data")

# --- Stage 1: Find thread URLs -------------------------------------------
message("Stage 1: searching for relevant threads...")

all_urls <- list()

for (kw in KEYWORDS) {
  for (sort_opt in SORT_OPTIONS) {
    message(sprintf("  query='%s'  sort=%s", kw, sort_opt))

    result <- tryCatch(
      find_thread_urls(
        subreddit = SUBREDDIT,
        keywords  = kw,
        sort_by   = sort_opt,
        period    = PERIOD
      ),
      error = function(e) { message("    error: ", e$message); NULL }
    )

    if (!is.null(result) && is.data.frame(result) && nrow(result) > 0) {
      
      result$keyword   <- kw
      result$sort_used <- sort_opt
      all_urls[[length(all_urls) + 1]] <- result
    }
    Sys.sleep(2)  # be polite to Reddit's servers
  }
}

posts_df <- bind_rows(all_urls) %>% distinct(url, .keep_all = TRUE)
message(sprintf("Found %d unique threads matching keywords.", nrow(posts_df)))

write_csv(posts_df, "Data/raw_posts.csv")

# --- Stage 2: Pull full thread content (comments + vote info) ------------
# get_thread_content() returns a list with $threads (richer post data,
# including scores) and $comments (one row per comment).
message("Stage 2: pulling comments for each thread...")

chunk_size <- 25                    # process in chunks to limit blast radius
chunks <- split(posts_df$url,
                ceiling(seq_along(posts_df$url) / chunk_size))

all_threads  <- list()
all_comments <- list()

for (i in seq_along(chunks)) {
  message(sprintf("  chunk %d of %d (%d threads)",
                  i, length(chunks), length(chunks[[i]])))

  content <- tryCatch(
    get_thread_content(chunks[[i]]),
    error = function(e) { message("    error: ", e$message); NULL }
  )


    if (!is.null(content) && is.list(content)) {
    if (!is.null(content$threads))  all_threads[[i]]  <- content$threads
    if (!is.null(content$comments)) all_comments[[i]] <- content$comments
  }

  Sys.sleep(3)  # rate-limit politeness
}

# Coerce everything to character to avoid type-mismatch across chunks
threads_df  <- bind_rows(lapply(all_threads,  function(df) {
  df %>% mutate(across(everything(), as.character))
}))
comments_df <- bind_rows(lapply(all_comments, function(df) {
  df %>% mutate(across(everything(), as.character))
}))

# Overwrite raw_posts with the richer thread data (now includes scores)
write_csv(threads_df,  "Data/raw_posts.csv")
write_csv(comments_df, "Data/raw_comments.csv")

message(sprintf("Done. Saved %d threads and %d comments to Data/.",
                nrow(threads_df), nrow(comments_df)))
