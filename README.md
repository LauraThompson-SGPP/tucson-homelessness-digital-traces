# Tucson Homelessness — Digital Traces

A digital traces analysis of public sentiment on homelessness in Tucson, Arizona, using Reddit data from r/Tucson over the 2024–2025 period.

## Project Overview

This project scrapes posts and comments from r/Tucson related to homelessness, then applies sentiment analysis and topic modeling to surface patterns in public discussion across the 2024–2025 window.

**Research question:** How has public sentiment toward homelessness in Tucson, AZ evolved across 2024–2025, and what themes recur in that discussion?

## Repository Structure

```
.
├── README.md
├── Code/                                    # R scripts, run in numerical order
│   ├── 01_collect_reddit_data.R
│   ├── 02_clean_data.R
│   ├── 03_sentiment_analysis.R
│   ├── 04_topic_modeling.R
│   └── 05_visualizations.R
├── Data/                                    # Raw and cleaned datasets
│   └── README.md
└── Results/                                 # Figures, tables, summaries
    └── README.md
```

## How to Reproduce

### Requirements
- **R** 4.1 or higher
- Each script installs its own packages on first run. Key packages used:
  - `RedditExtractoR` (data collection)
  - `tidyverse`, `lubridate` (data wrangling)
  - `vader` (sentiment analysis)
  - `stm`, `tidytext` (topic modeling)
  - `ggplot2`, `wordcloud` (visualization)

### Steps
1. Clone this repository.
2. Open the project in RStudio (or any R environment) and set the working directory to the repository root.
3. Run the scripts in order. Each writes its outputs to `Data/` or `Results/`:

   | Script | Purpose | Inputs | Outputs |
   |--------|---------|--------|---------|
   | `01_collect_reddit_data.R` | Scrape r/Tucson via RedditExtractoR | (none) | `Data/raw_posts.csv`, `Data/raw_comments.csv` |
   | `02_clean_data.R` | Filter, dedupe, anonymize | raw CSVs | `Data/analysis_posts.csv`, `Data/analysis_comments.csv`, `Results/data_summary.csv` |
   | `03_sentiment_analysis.R` | VADER sentiment scoring | analysis CSVs | `Data/posts_with_sentiment.csv`, `Data/comments_with_sentiment.csv`, `Results/sentiment_*.csv` |
   | `04_topic_modeling.R` | Structural topic modeling | sentiment CSVs | `Data/documents_with_topics.csv`, `Results/topic_*.csv` |
   | `05_visualizations.R` | Figures | sentiment + topic CSVs | `Results/fig_*.png` |

### Important Notes
- **No Reddit API key is required.** `RedditExtractoR` queries Reddit's public JSON endpoints. This is a deliberate methodological choice — the originally planned Pushshift workflow is no longer publicly available (Reddit restricted Pushshift access to verified moderators in 2023).
- The initial scrape may take **30 minutes to several hours** depending on volume. Be patient and let it run.
- Reddit content is dynamic (posts may be deleted/edited after scraping). Re-running the collection script will not yield byte-identical data.
- VADER scoring of comments is the slowest analytic step (potentially 30+ min for large corpora).

## Data Availability

**Raw Reddit data is not committed to this repository.** Two reasons:

1. **Privacy.** Reddit posts are public, but commit-and-publishing usernames in a GitHub repo creates a permanent, easily-searchable record that could enable de-anonymization or reverse-lookup of individuals discussing a sensitive topic. Standard practice in computational social science is to keep raw user-attributed data out of public repositories.
2. **Reproducibility caveats.** Reddit content is dynamic — deletions, edits, and account removals mean that any committed snapshot will diverge from what `01_collect_reddit_data.R` would pull on a later date.

What *can* be committed (and is, where the file size and IRB guidance allow): an **aggregated/anonymized analysis dataset** with usernames stripped, post text hashed to short IDs, and sentiment scores attached. See `Data/README.md` for which files are present versus regenerated.

## Tools

| Tool | Purpose | Covered in class? |
|------|---------|-------------------|
| R / tidyverse | Data wrangling | Yes |
| **RedditExtractoR** | Reddit scraping (no API key required) | **No** |
| **VADER (`vader` R package)** | Sentiment lexicon designed for social media text | **No** |
| **`stm` (Structural Topic Model)** | Topic modeling with covariates | **No** |
| ggplot2, wordcloud | Visualization | Yes |

RedditExtractoR uses Reddit's public JSON endpoints (no authentication needed) and exposes both thread-search and comment-extraction functions. It was selected after the originally planned Pushshift-based workflow proved unworkable.

## Challenges

1. **API access landscape.** Initially planned to use PRAW (Python) with a Reddit API key, then `pushshiftR` (R) for date-bounded search. Reddit's 2023 API policy changes paywalled the official API for many use cases and restricted Pushshift access to verified moderators. Pivoted to `RedditExtractoR`, which avoids both gates.
2. **Date-range search limitations.** Reddit's native search (which `RedditExtractoR` wraps) does not allow precise date filtering. Mitigated by (a) running multiple keyword and sort-order combinations to maximize coverage, then (b) date-filtering after the pull in `02_clean_data.R`.
3. **Anonymization vs. reproducibility.** Balancing privacy against the need to share a dataset others can verify. Resolved by withholding raw data, committing aggregated outputs, and providing the collection script for re-running.

## Next Steps

- Add **YouTube comments on local Tucson news coverage** as a second platform for source triangulation.
- Align sentiment shifts with **real-world Tucson events** (encampment sweeps, Prop 312 voting, council decisions, news cycles).
- Compare against another Arizona city (Phoenix) to test whether observed patterns are local or regional.

## Author

[Your Name], PhD student, University of Arizona
Course: Digital Traces

## License / Use

Code: MIT (or your preference). Data: not redistributed; see above.
