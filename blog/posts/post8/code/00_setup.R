# Base R only; Quarto rendering uses knitr.
if (getRversion() < '4.3.0') stop('Use R 4.3 or later.')
for (pkg in c('knitr','rmarkdown')) if (!requireNamespace(pkg, quietly=TRUE)) install.packages(pkg, repos='https://cloud.r-project.org')
message('Ready: analysis uses base R; rendering uses knitr and Quarto.')
