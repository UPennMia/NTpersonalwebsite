# Two-source web scraping for Blog 2
# Source 1: U.S. Department of Labor
# Source 2: MERIC
#
# Run with:
# wages <- scrape_blog2("path/to/your/blog/post")
#
# Refresh both websites:
# wages <- scrape_blog2("path/to/your/blog/post", refresh = TRUE)

scrape_blog2 <- function(output_dir, refresh = FALSE) {
  
  packages <- c("rvest", "xml2", "httr", "stringr")
  
  missing <- packages[
    !vapply(packages, requireNamespace,
            quietly = TRUE, FUN.VALUE = logical(1))
  ]
  
  if (length(missing)) {
    stop(
      "First install these packages in the Console:\n",
      'install.packages(c("',
      paste(missing, collapse = '", "'),
      '"))',
      call. = FALSE
    )
  }
  
  output_dir <- normalizePath(
    output_dir, winslash = "/", mustWork = TRUE
  )
  
  folders <- c(
    "data/raw/dol",
    "data/raw/meric",
    "data/cleaned",
    "results/figures",
    "results/table"
  )
  
  for (folder in folders) {
    dir.create(
      file.path(output_dir, folder),
      recursive = TRUE,
      showWarnings = FALSE
    )
  }
  
  check <- function(condition, message) {
    if (!isTRUE(condition)) stop(message, call. = FALSE)
  }
  
  clean_text <- function(x) {
    stringr::str_squish(
      gsub("\u00a0", " ", as.character(x), fixed = TRUE)
    )
  }
  
  save_csv <- function(x, relative_path) {
    write.csv(
      x,
      file.path(output_dir, relative_path),
      row.names = FALSE,
      na = "",
      fileEncoding = "UTF-8"
    )
  }
  
  # Save the original HTML before parsing.
  # Later renders reuse it unless refresh = TRUE.
  get_page <- function(site, url) {
    
    folder <- file.path(output_dir, "data/raw", site)
    html_file <- file.path(folder, "page.html")
    
    if (refresh || !file.exists(html_file)) {
      
      message("Downloading: ", url)
      
      # Space requests and identify the educational project.
      Sys.sleep(2)
      
      response <- httr::GET(
        url,
        httr::user_agent(
          "Blog2StudentProject/1.0 (educational web scraping)"
        ),
        httr::timeout(60)
      )
      
      httr::stop_for_status(response)
      
      bytes <- httr::content(response, as = "raw")
      
      check(
        length(bytes) > 1000,
        paste("Unexpectedly short response from", site)
      )
      
      # Check that the response is parseable before saving it.
      candidate <- xml2::read_html(bytes)
      
      check(
        length(rvest::html_elements(candidate, "table")) > 0,
        paste("No HTML tables returned by", site,
              "- inspect the website before continuing.")
      )
      
      writeBin(bytes, html_file)
      
      save_csv(
        data.frame(
          source = site,
          url = url,
          retrieved_utc = format(
            Sys.time(),
            tz = "UTC",
            format = "%Y-%m-%d %H:%M:%S"
          ),
          http_status = httr::status_code(response),
          md5 = unname(tools::md5sum(html_file))
        ),
        paste0("data/raw/", site, "/source_metadata.csv")
      )
      
    } else {
      message("Using saved HTML: ", site)
    }
    
    xml2::read_html(html_file)
  }
  
  # -------------------------------------------------------
  # 1. Department of Labor: minimum wages
  # -------------------------------------------------------
  
  dol <- get_page(
    "dol",
    "https://www.dol.gov/agencies/whd/mw-consolidated"
  )
  
  dol_text <- clean_text(rvest::html_text2(dol))
  
  wage_date <- stringr::str_match(
    dol_text,
    "Effective Date:\\s*([A-Za-z]+ [0-9]{1,2}, [0-9]{4})"
  )[1, 2]
  
  check(
    !is.na(wage_date),
    "Could not identify the DOL effective date."
  )
  
  # Important: remove superscript footnote markers.
  # Otherwise a wage such as 10.85 followed by footnote 3
  # could incorrectly become 10.853.
  xml2::xml_remove(rvest::html_elements(dol, "sup"))
  
  dol_tables <- rvest::html_table(
    dol, fill = TRUE, trim = TRUE
  )
  
  dol_id <- which(vapply(
    dol_tables,
    function(x) {
      ncol(x) == 3 &&
        any(grepl(
          "Greater than federal", names(x), fixed = TRUE
        ))
    },
    logical(1)
  ))
  
  check(
    length(dol_id) == 1,
    "DOL table structure changed; inspect data/raw/dol/page.html."
  )
  
  dol_table <- as.data.frame(dol_tables[[dol_id]])
  
  federal <- as.numeric(stringr::str_extract(
    names(dol_table)[2],
    "[0-9]+\\.[0-9]{2}"
  ))
  
  check(
    is.finite(federal) && federal > 0,
    "Could not identify the federal minimum wage."
  )
  
  categories <- c(
    "above_federal",
    "equal_federal",
    "no_or_lower_state_floor"
  )
  
  raw_wages <- do.call(
    rbind,
    lapply(seq_len(3), function(j) {
      data.frame(
        category = categories[j],
        raw_cell = clean_text(dol_table[[j]]),
        stringsAsFactors = FALSE
      )
    })
  )
  
  raw_wages <- raw_wages[
    nzchar(raw_wages$raw_cell), , drop = FALSE
  ]
  
  raw_wages$abbr <- stringr::str_extract(
    raw_wages$raw_cell, "^[A-Z]{2}\\b"
  )
  
  save_csv(raw_wages, "data/raw/dol/extracted_cells.csv")
  
  state_map <- setNames(
    c(state.name, "District of Columbia"),
    c(state.abb, "DC")
  )
  
  raw_wages <- raw_wages[
    !is.na(raw_wages$abbr) &
      raw_wages$abbr %in% names(state_map),
    ,
    drop = FALSE
  ]
  
  check(
    nrow(raw_wages) == 51 &&
      !anyDuplicated(raw_wages$abbr),
    "DOL must contain each of the 50 states and DC exactly once."
  )
  
  raw_wages$state <- unname(state_map[raw_wages$abbr])
  
  amounts <- stringr::str_extract_all(
    raw_wages$raw_cell,
    "(?<=\\$)[0-9]+(?:\\.[0-9]+)?"
  )
  
  raw_wages$multi_rate <- lengths(amounts) > 1L
  
  wage_ranges <- t(vapply(
    amounts,
    function(x) {
      
      x <- as.numeric(x)
      
      # The federal floor applies to FLSA-covered employment.
      if (!length(x)) x <- federal
      
      x <- pmax(x, federal)
      
      c(low = min(x), high = max(x))
    },
    numeric(2)
  ))
  
  raw_wages$wage_low <- wage_ranges[, 1]
  raw_wages$wage_high <- wage_ranges[, 2]
  
  raw_wages$wage <- ifelse(
    raw_wages$multi_rate,
    NA_real_,
    raw_wages$wage_low
  )
  
  raw_wages$effective_date <- wage_date
  
  # -------------------------------------------------------
  # 2. MERIC: cost-of-living indices
  # -------------------------------------------------------
  
  meric <- get_page(
    "meric",
    "https://meric.mo.gov/data/cost-living-data-series"
  )
  
  headings <- clean_text(
    rvest::html_text2(
      rvest::html_elements(meric, "h2, h3")
    )
  )
  
  period_heading <- headings[
    grepl("^Cost of Living[-– ]", headings) &
      !grepl("Indices", headings, fixed = TRUE)
  ]
  
  check(
    length(period_heading) >= 1,
    "Could not identify the MERIC reporting period."
  )
  
  cost_period <- sub(
    "^Cost of Living[-– ]*", "", period_heading[1]
  )
  
  meric_tables <- rvest::html_table(
    meric, fill = TRUE, trim = TRUE
  )
  
  meric_id <- which(vapply(
    meric_tables,
    function(x) {
      all(
        c("State", "Index", "Housing", "Grocery") %in%
          names(x)
      )
    },
    logical(1)
  ))
  
  check(
    length(meric_id) == 1,
    "MERIC table structure changed; inspect data/raw/meric/page.html."
  )
  
  raw_costs <- as.data.frame(meric_tables[[meric_id]])
  raw_costs$cost_period <- cost_period
  
  save_csv(raw_costs, "data/raw/meric/extracted_table.csv")
  
  costs <- data.frame(
    state = clean_text(raw_costs$State),
    cost_index = as.numeric(
      gsub(",", "", as.character(raw_costs$Index))
    ),
    cost_period = cost_period,
    stringsAsFactors = FALSE
  )
  
  costs <- costs[
    costs$state %in% unname(state_map), , drop = FALSE
  ]
  
  check(
    nrow(costs) == 51 && !anyDuplicated(costs$state),
    "MERIC must contain each of the 50 states and DC exactly once."
  )
  
  check(
    all(is.finite(costs$cost_index)) &&
      all(costs$cost_index > 0),
    "MERIC contains missing or invalid cost indices."
  )
  
  check(
    setequal(raw_wages$state, costs$state),
    "State names do not match between the two websites."
  )
  
  # -------------------------------------------------------
  # 3. Join, calculate purchasing power, and save results
  # -------------------------------------------------------
  
  combined <- merge(
    raw_wages,
    costs,
    by = "state",
    all = FALSE,
    sort = TRUE
  )
  
  check(nrow(combined) == 51, "The merge lost observations.")
  
  combined$adjusted_low <-
    combined$wage_low / (combined$cost_index / 100)
  
  combined$adjusted_high <-
    combined$wage_high / (combined$cost_index / 100)
  
  combined$adjusted <-
    combined$wage / (combined$cost_index / 100)
  
  # Preserve multiple-rate states separately.
  multiple <- combined[
    combined$multi_rate, , drop = FALSE
  ]
  
  main <- combined[
    !combined$multi_rate, , drop = FALSE
  ]
  
  main$nominal_rank <- rank(
    -main$wage, ties.method = "min"
  )
  
  main$adjusted_rank <- rank(
    -main$adjusted, ties.method = "min"
  )
  
  main$rank_gain <- main$nominal_rank - main$adjusted_rank
  
  main <- main[order(-main$adjusted), , drop = FALSE]
  rownames(main) <- NULL
  
  check(
    nrow(main) >= 30 &&
      all(is.finite(main$adjusted)) &&
      all(main$wage >= federal),
    "The cleaned analysis sample failed validation."
  )
  
  save_csv(combined, "data/cleaned/all_jurisdictions.csv")
  save_csv(main, "data/cleaned/analysis_sample.csv")
  save_csv(multiple, "data/cleaned/multi_rate_states.csv")
  
  save_csv(
    main[, c(
      "state", "wage", "cost_index", "adjusted",
      "nominal_rank", "adjusted_rank", "rank_gain"
    )],
    "results/table/full_rankings.csv"
  )
  
  save_csv(
    head(main[, c("state", "wage", "cost_index", "adjusted")], 10),
    "results/table/top_10.csv"
  )
  
  save_csv(
    multiple[, c(
      "state", "wage_low", "wage_high",
      "cost_index", "adjusted_low", "adjusted_high"
    )],
    "results/table/multi_rate_sensitivity.csv"
  )
  
  save_csv(
    data.frame(
      check = c(
        "Merged jurisdictions",
        "Single-rate sample",
        "Multiple-rate states"
      ),
      count = c(
        nrow(combined), nrow(main), nrow(multiple)
      )
    ),
    "results/table/data_validation.csv"
  )
  
  message(
    "Complete: ", nrow(combined), " jurisdictions merged; ",
    nrow(main), " in the main sample; ",
    nrow(multiple), " in the multiple-rate appendix."
  )
  
  main
}