# ===========================================================================
# Script:   04_topic_modeling.R
# Project:  Tucson Homelessness Digital Traces
# Purpose:  Identify recurring themes in homelessness-related Reddit content
#           using a Structural Topic Model (STM).
#
#           Why STM?
#             - Well-suited to short, social-media-style text.
#             - Native support for document-level covariates (date, source),
#               so we can later study how topic prevalence shifts over time.
#             - Widely used in computational social science.
#
#           Tuning K:
#             The number of topics K is set to 15 below. For a real analysis,
#             use stm::searchK() to compare exclusivity and semantic
#             coherence across candidate K values. That step is slow; we
#             leave it commented out below.
#
# Inputs:   Data/posts_with_sentiment.csv
#           Data/comments_with_sentiment.csv
# Outputs:  Data/documents_with_topics.csv
#           Results/topic_top_terms.csv
#           Results/topic_prevalence.csv
# ===========================================================================

# --- Packages --------------------------------------------------------------
required <- c("stm", "tm", "dplyr", "readr", "stringr",
              "tidytext", "lubridate", "tibble")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install)

library(stm)
library(dplyr)
library(readr)
library(stringr)
library(tidytext)
library(lubridate)
library(tibble)

# --- Build a unified document corpus -------------------------------------
posts <- read_csv("Data/posts_with_sentiment.csv", show_col_types = FALSE) %>%
  transmute(
    doc_id   = paste0("p_", row_number()),
    date,
    text     = full_text,
    source   = "post",
    compound
  )

comments <- read_csv("Data/comments_with_sentiment.csv", show_col_types = FALSE) %>%
  transmute(
    doc_id   = paste0("c_", row_number()),
    date,
    text     = comment,
    source   = "comment",
    compound
  )

docs <- bind_rows(posts, comments) %>%
  filter(!is.na(text), nchar(text) >= 20)   # drop trivially short docs

cat(sprintf("Corpus: %d documents.\n", nrow(docs)))

# --- Text preprocessing via stm::textProcessor ----------------------------
processed <- textProcessor(
  documents          = docs$text,
  metadata           = docs,
  lowercase          = TRUE,
  removestopwords    = TRUE,
  removenumbers      = TRUE,
  removepunctuation  = TRUE,
  stem               = FALSE,
  verbose            = TRUE,
  customstopwords    = c("tucson", "arizona", "https", "http", "www",
                         "just", "like", "get", "one", "people",
                         "really", "even", "also", "going")
)

out <- prepDocuments(
  processed$documents,
  processed$vocab,
  processed$meta,
  lower.thresh = 5       # drop terms appearing in <5 docs
)

# Optional: pick K empirically (slow). Uncomment to run.
# search_results <- searchK(out$documents, out$vocab,
#                           K = c(8, 12, 15, 20, 25),
#                           data = out$meta, verbose = TRUE)
# plot(search_results)

# --- Fit the STM ----------------------------------------------------------
K <- 15
set.seed(42)

fit <- stm(
  documents  = out$documents,
  vocab      = out$vocab,
  K          = K,
  data       = out$meta,
  prevalence = ~ s(as.numeric(date)) + source,
  max.em.its = 75,
  init.type  = "Spectral",
  verbose    = TRUE
)

# --- Extract top terms per topic ------------------------------------------
top_terms <- labelTopics(fit, n = 10)

top_terms_df <- tibble(
  topic       = seq_len(K),
  frex_terms  = apply(top_terms$frex,  1, paste, collapse = ", "),
  prob_terms  = apply(top_terms$prob,  1, paste, collapse = ", "),
  lift_terms  = apply(top_terms$lift,  1, paste, collapse = ", ")
)

write_csv(top_terms_df, "Results/topic_top_terms.csv")

# --- Per-document topic proportions ---------------------------------------
theta <- fit$theta
colnames(theta) <- paste0("topic_", seq_len(K))

docs_with_topics <- bind_cols(out$meta, as_tibble(theta))
write_csv(docs_with_topics, "Data/documents_with_topics.csv")

# --- Overall topic prevalence --------------------------------------------
prev <- tibble(
  topic      = paste0("topic_", seq_len(K)),
  prevalence = colMeans(theta)
) %>% arrange(desc(prevalence))

write_csv(prev, "Results/topic_prevalence.csv")

cat("\nTop topics by overall prevalence:\n")
print(prev)
