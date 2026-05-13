# Data Directory

This directory holds raw and processed datasets for the project.

## What is committed to GitHub

**No raw user-attributed data is committed.** See the main README for the
privacy rationale.

If file size and IRB guidance allow, the following anonymized/aggregated files
may be committed here:

- `analysis_summary.csv` — aggregate counts and date range
- (optionally) `documents_with_topics.csv` — text + topic proportions, with
  author identifiers replaced by stable integer IDs

## What is generated locally (not committed)

Running the scripts in `Code/` will populate this directory with:

| File | Created by | Contents |
|------|-----------|----------|
| `raw_posts.csv` | `01_collect_reddit_data.R` | Raw scraped threads from r/Tucson |
| `raw_comments.csv` | `01_collect_reddit_data.R` | Raw scraped comments, linked by `url` |
| `analysis_posts.csv` | `02_clean_data.R` | Cleaned, date-filtered, anonymized posts |
| `analysis_comments.csv` | `02_clean_data.R` | Cleaned, anonymized comments |
| `posts_with_sentiment.csv` | `03_sentiment_analysis.R` | Posts + VADER sentiment scores |
| `comments_with_sentiment.csv` | `03_sentiment_analysis.R` | Comments + VADER sentiment scores |
| `documents_with_topics.csv` | `04_topic_modeling.R` | Per-document topic proportions |

## Reproducing the data

From the repo root in R:
```r
source("Code/01_collect_reddit_data.R")
source("Code/02_clean_data.R")
```
Note that scraping is non-deterministic — Reddit content changes over time.
