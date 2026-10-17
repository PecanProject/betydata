#!/usr/bin/env Rscript
# Quarto runs project pre-render scripts from the project root. An explicit root
# also supports manual rebuilds from another working directory.
args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[[1]] else "."
source(file.path(root, "scripts", "site-data.R"))
summary <- build_site_data(root)
message("Generated public website data: ", summary$observations, " observations; ",
        summary$variables, " measured variable names.")
