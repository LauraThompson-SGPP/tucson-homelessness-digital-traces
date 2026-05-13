# ===========================================================================
# Script:   05_visualizations.R
# Project:  Tucson Homelessness Digital Traces
# Purpose:  Generate publication-quality figures for the project:
#             - volume of posts/comments over time
#             - mean sentiment by month, posts vs. comments
#             - topic prevalence bar chart with top terms
#             - word cloud of high-frequency comment terms
#
# Inputs:   Data/posts_with_sentiment.csv
#           Data/comments_with_sentiment.csv
#           Results/topic_top_terms.csv
#           Results/topic_prevalence.csv
# Outputs:  Results/fig_volume.png
#           Results/fig_sentiment_trend.png
#           Results/fig_topic_prevalence.png
#           Results/fig_wordcloud.png
# ===========================================================================

# --- Packages --------------------------------------------------------------
required <- c("ggplot2", "dplyr", "readr", "lubridate", "wordcloud",
              "tidytext", "stringr", "scales", "RColorBrewer")
to_install <- setdiff(required, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install)

library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(wordcloud)
library(tidytext)
library(stringr)
library(scales)
library(RColorBrewer)

theme_set(theme_minimal(base_size = 12))

# Project palette (Warm Terracotta)
COL_POST    <- "#B85042"
COL_COMMENT <- "#A7BEAE"

# --- Load -----------------------------------------------------------------
posts       <- read_csv("Data/posts_with_sentiment.csv",    show_col_types = FALSE)
comments    <- read_csv("Data/comments_with_sentiment.csv", show_col_types = FALSE)
topic_terms <- read_csv("Results/topic_top_terms.csv",      show_col_types = FALSE)
topic_prev  <- read_csv("Results/topic_prevalence.csv",     show_col_types = FALSE)

# --- 1. Volume over time --------------------------------------------------
volume <- bind_rows(
  posts    %>% mutate(source = "Posts")    %>% select(date, source),
  comments %>% mutate(source = "Comments") %>% select(date, source)
) %>%
  mutate(month = floor_date(date, "month")) %>%
  count(month, source)

p_volume <- ggplot(volume, aes(x = month, y = n, color = source)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.6) +
  scale_color_manual(values = c("Posts" = COL_POST, "Comments" = COL_COMMENT)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Reddit discussion of homelessness in r/Tucson",
    subtitle = "Monthly post and comment volume, 2024–2025",
    x = NULL, y = "Count", color = NULL
  ) +
  theme(legend.position = "bottom")

ggsave("Results/fig_volume.png", p_volume,
       width = 8, height = 4.5, dpi = 200)

# --- 2. Sentiment trend ---------------------------------------------------
sent <- bind_rows(
  posts    %>% mutate(source = "Posts")    %>% select(date, compound, source),
  comments %>% mutate(source = "Comments") %>% select(date, compound, source)
) %>%
  mutate(month = floor_date(date, "month")) %>%
  group_by(month, source) %>%
  summarise(mean_sent = mean(compound, na.rm = TRUE),
            n         = n(),
            .groups   = "drop") %>%
  filter(n >= 5)   # avoid noisy means from tiny months

p_sent <- ggplot(sent, aes(x = month, y = mean_sent, color = source)) +
  geom_hline(yintercept = 0, color = "grey60", linetype = "dashed") +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.6) +
  scale_color_manual(values = c("Posts" = COL_POST, "Comments" = COL_COMMENT)) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 months") +
  labs(
    title    = "Sentiment trend, Tucson homelessness discussion",
    subtitle = "Mean VADER compound score by month (-1 = most negative, +1 = most positive)",
    x = NULL, y = "Mean sentiment", color = NULL
  ) +
  theme(legend.position = "bottom")

ggsave("Results/fig_sentiment_trend.png", p_sent,
       width = 8, height = 4.5, dpi = 200)

# --- 3. Topic prevalence bar chart ---------------------------------------
topic_labeled <- topic_prev %>%
  mutate(topic_num = as.integer(str_extract(topic, "\\d+"))) %>%
  left_join(topic_terms, by = c("topic_num" = "topic")) %>%
  mutate(
    label_text = str_sub(frex_terms, 1, 60),
    topic_id   = factor(topic, levels = topic[order(prevalence)])
  )

p_topic <- ggplot(topic_labeled, aes(x = prevalence, y = topic_id)) +
  geom_col(fill = COL_POST) +
  geom_text(aes(label = label_text),
            hjust = 0, x = 0.002, size = 3.2, color = "white") +
  scale_x_continuous(labels = percent_format(accuracy = 0.1)) +
  labs(
    title    = "Topic prevalence in Tucson homelessness discussion",
    subtitle = "Average share of documents per topic, with top FREX terms",
    x = "Prevalence", y = NULL
  )

ggsave("Results/fig_topic_prevalence.png", p_topic,
       width = 9, height = 6, dpi = 200)

# --- 4. Word cloud of comments -------------------------------------------
data("stop_words")

words <- comments %>%
  unnest_tokens(word, comment) %>%
  anti_join(stop_words, by = "word") %>%
  filter(
    !str_detect(word, "^\\d+$"),
    nchar(word) > 2,
    !word %in% c("tucson", "https", "http", "www",
                 "homeless", "homelessness", "people",
                 "just", "like", "get", "one", "really")
  ) %>%
  count(word, sort = TRUE) %>%
  slice_max(n, n = 150)

png("Results/fig_wordcloud.png",
    width = 1200, height = 800, res = 150)
par(mar = c(0, 0, 0, 0))
wordcloud(
  words        = words$word,
  freq         = words$n,
  min.freq     = 1,
  max.words    = 150,
  random.order = FALSE,
  rot.per      = 0.15,
  colors       = brewer.pal(8, "Dark2"),
  scale        = c(4, 0.5)
)
dev.off()

message("All figures written to Results/")
