# Blog 1: The Monty Hall Problem

## Research question

Why does switching doors increase the chance of winning in the Monty Hall problem, even though only two doors remain closed?

## Files

- `index.qmd`: article source, including the probability argument, the three-case table, and formatting.
- `figure.png`: cover illustration referenced by the article.
- `README.md`: project description and reproduction instructions.

The article is part of the existing Quarto website. The website's `_quarto.yml` file supplies the project configuration.

## Reproduce

Install [Quarto](https://quarto.org/). RStudio can be used to edit and render the article, but it is not required. This post contains no executable R code and requires no R packages, external datasets, or random seed.

To reproduce the article within the website:

1. Download or clone the complete website repository, including its `_quarto.yml` configuration and any assets referenced by that configuration.
2. Keep `index.qmd` and `figure.png` together in the original Blog 1 post folder. The article references the illustration using the relative path `figure.png`.
3. Open a terminal in the website project root and run:

   ```sh
   quarto render
   ```

   This renders the website using its existing configuration. Alternatively, open Blog 1's `index.qmd` in RStudio and click **Render** to render the article.
4. Open the generated HTML page to view the article. Its output location follows the website's Quarto configuration.

Keep the existing project configuration to reproduce the website's layout and navigation, in addition to the article's text, equations, table, and illustration.

## Method

The post derives the result by considering the player's initial choice. The car is equally likely to be behind any of three doors. The host knows where the car is, always opens an unchosen door containing a goat, and always offers the opportunity to switch.

The table fixes the initial choice at Door 1 and lists the three equally likely car locations. Staying wins in one case, while switching wins in two. The exact winning probabilities are therefore 1/3 for staying and 2/3 for switching.

The 100-door example applies the same reasoning: staying wins with probability 1/100, while switching wins with probability 99/100. These are theoretical calculations, so no simulation or data-processing script is needed to verify them.

## Limitations

The conclusions depend on the host following the stated rules. If the host does not know the car's location, can reveal the car, or selectively offers the opportunity to switch, the probabilities may differ. The cover illustration is an existing static asset and is included directly rather than generated during rendering.
