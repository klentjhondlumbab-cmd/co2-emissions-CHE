w(country_data) == 0) {
  stop("No country-year rows found; check the ISO-3 code and years.")
}

country_data <- country_data[order(country_data$year), , drop = FALSE]
country_csv <- file.path("data", paste0(country_code, "_co2.csv"))
write.csv(country_data, country_csv, row.names = FALSE, na = "")

# READ BACK the country-specific file for the analysis
d <- read.csv(country_csv, stringsAsFactors = FALSE)
d <- d[order(d$year), , drop = FALSE]

valid_co2 <- d[!is.na(d$co2), , drop = FALSE]
if (nrow(valid_co2) == 0) stop("No usable annual CO2 data.")

# Reusable plotting helper (uses base R; no extra packages)
save_plot <- function(x, y, filename, title_text, y_label) {
  good <- !is.na(x) & is.finite(y)
  if (sum(good) < 2) {
    message("Not enough data for plot: ", filename)
    return(invisible(FALSE))
  }
  png(filename, width = 1440, height = 840, res = 160)
  plot(x[good], y[good], type = "o", pch = 16, cex = 0.55,
       col = "#21618C", lwd = 2,
       xlab = "Year", ylab = y_label, main = title_text)
  grid()
  dev.off()
  invisible(TRUE)
}

country_name <- d$country[1]

save_plot(d$year, d$co2,
          file.path("figures", paste0(country_code, "_annual_co2.png")),
          paste(country_name, "annual CO2 emissions"), "Million tonnes CO2/year")

save_plot(d$year, d$co2_per_capita,
          file.path("figures", paste0(country_code, "_per_capita.png")),
          paste(country_name, "CO2 emissions per capita"), "Tonnes CO2/person/year")

# Year-over-year percentage change; calculate only for adjacent years
d$change_pct <- NA_real_
if (nrow(d) >= 2) {
  for (i in 2:nrow(d)) {
    adjacent <- d$year[i] == d$year[i - 1] + 1
    usable <- !is.na(d$co2[i]) && !is.na(d$co2[i - 1]) && d$co2[i - 1] > 0
    if (adjacent && usable) {
      d$change_pct[i] <- 100 * (d$co2[i] / d$co2[i - 1] - 1)
    }
  }
}

save_plot(d$year, d$change_pct,
          file.path("figures", paste0(country_code, "_annual_change.png")),
          paste(country_name, "annual CO2 change"), "Change from previous year (%)")

# Save summary statistics and annual changes tables
first <- valid_co2[1, , drop = FALSE]
last <- valid_co2[nrow(valid_co2), , drop = FALSE]
peak <- valid_co2[which.max(valid_co2$co2), , drop = FALSE]

endpoint_change <- if (first$co2 > 0) {
  100 * (last$co2 / first$co2 - 1)
} else {
  NA_real_
}

pc <- d[!is.na(d$co2_per_capita), , drop = FALSE]
last_pc <- if (nrow(pc)) tail(pc$co2_per_capita, 1) else NA_real_

summary_table <- data.frame(
  country = country_name,
  iso_code = country_code,
  first_year = first$year,
  last_year = last$year,
  first_co2_mt = first$co2,
  last_co2_mt = last$co2,
  endpoint_change_percent = endpoint_change,
  peak_year = peak$year,
  peak_co2_mt = peak$co2,
  latest_co2_per_capita_t = last_pc
)

write.csv(summary_table,
          file.path("results", paste0(country_code, "_summary.csv")),
          row.names = FALSE)

write.csv(d[, c("year", "co2", "co2_per_capita", "change_pct")],
          file.path("results", paste0(country_code, "_yearly_changes.csv")),
          row.names = FALSE)

writeLines(c(paste("Source:", source_url),
             paste("Processed:", Sys.time()),
             capture.output(sessionInfo())),
           file.path("results", "session_info.txt"))

message("Completed country analysis for ", country_name, " (", country_code, "). Check data/, figures/, results/.")
