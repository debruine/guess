saveData <- function(data, stats, id, outputDir = "responses") {
  # Create a unique file name
  dataName <- sprintf("%s_data.csv", id)
  statsName <- sprintf("%s_stats.csv", id)
  
  # Write the files to the local system
  readr::write_csv(
    x = data,
    path = file.path(outputDir, dataName)
  )
  
  readr::write_csv(
    x = stats,
    path = file.path(outputDir, statsName)
  )
}


loadData <- function(outputDir = "responses", 
                     pattern = "*_data.csv") {
  # read all the files into a list
  files <- list.files(outputDir, 
                      pattern = pattern, 
                      full.names = TRUE)
  
  if (length(files) == 0) {
    # create empty data frame with correct columns
    data <- data.frame()
  } else {
    data <- lapply(files, function(f) {
      readr::read_csv(f) %>%
        mutate(session_id = gsub("responses/", "", f))
    })
    
    # Concatenate all data together into one data.frame
    data <- do.call(bind_rows, data)
  }
  
  data
}

tog_interface <- function(enabled = TRUE) {
  elems <- c("sample_again", "d_guess", "guess_A", "guess_0", 
             "guess_B", "guess_A2", "guess_A5", "guess_A8", 
             "guess_00", "guess_B2", "guess_B5", "guess_B8")
  
  if (enabled) {
    lapply(elems, enable)
    hide("next_trial")
    show("sample_again")
  } else {
    lapply(elems, disable)
    show("next_trial")
    hide("sample_again")
  }
}

setButtonClass <- function(id = NULL, class = NULL) {
  buttonsA <- c("guess_A", "guess_A2", "guess_A5", "guess_A8")
  buttons0 <- c("guess_0", "guess_00")
  buttonsB <- c("guess_B", "guess_B2", "guess_B5", "guess_B8")
  
  lapply(buttonsA, removeClass, class="A")
  lapply(buttons0, removeClass, class="null")
  lapply(buttonsB, removeClass, class="B")
  
  if (!is.null(id) & !is.null(class)) {
    addClass(id, class)
  }
}

presets <- function(..., session = session) {
  # default
  pre <- list(
    show_violin = F,
    show_boxplot = F,
    show_points = T,
    show_barplot = F,
    show_meanse = F,
    n_obs = 1,
    max_samples = 10000,
    one_two = T,
    trinary = T,
    accumulate = F,
    prob_null = 50,
    show_debug = F
  )
  
  change <- list(...)
  lapply(names(change), function(x) pre[[x]] <<- change[[x]])
  
  cbs <- c("show_violin", "show_boxplot", "show_points", "show_barplot", "show_meanse",
           "one_two", "trinary", "accumulate", "show_debug")
  sli <- c("n_obs", "prob_null")
  num <- c("max_samples")
  
  lapply(cbs, function(x) {
    updateCheckboxInput(session, x, value = pre[[x]])
  })
  lapply(sli, function(x) {
    updateSliderInput(session, x, value = pre[[x]])
  })
  lapply(num, function(x) {
    updateNumericInput(session, x, value = pre[[x]])
  })
}

summary_tri_plot <- function(data) {
  # TODO: too rigid, needs flexibility for other levels combos
  mutate(data, 
         bin = factor(real, levels = c(-.8, -.5, -.2, 0, .2, .5, .8)),
         version = case_when(
           trinary & !accumulate ~ "1: Trinary Single",
           trinary & accumulate ~ "2: Trinary Accumulate",
           !trinary & !accumulate ~ "3: Effect Size Single",
           !trinary & accumulate ~ "4: Effect Size Accumulate",
           TRUE ~ "Other Version"
           )) %>%
    group_by(bin, version) %>%
    summarise(correct = mean(correct)*100,
              `A>B` = mean(guess_dir == "A>B")*100,
              `A=B` = mean(guess_dir == "A=B")*100,
              `B>A` = mean(guess_dir == "B>A")*100
              ) %>%
    gather(response, pcnt, `A>B`:`B>A`, factor_key = T) %>%
    ggplot() +
    geom_col(aes(x = bin, y = correct, fill=bin), alpha = 0.25,
             position = position_identity(), show.legend = FALSE) +
    geom_line(aes(x = bin, y = pcnt, group = response, color = response), size = 2) +
    xlab("The true effect size (d)") +
    ylab("Percent response per effect size") +
    scale_x_discrete(drop = FALSE) +
    scale_fill_manual(values = c("#DD4B39","#DD4B39","#DD4B39",
                                 "#605CA8", 
                                 "#0073B7","#0073B7","#0073B7"),
                      drop = FALSE)  +
    scale_colour_manual(values = c("#DD4B39",
                                 "#605CA8", 
                                 "#0073B7"),
                      drop = FALSE)  +
    theme_minimal() + facet_wrap(~version, ncol = 1)
}

summary_guess_plot <- function(data) {
  ggplot(data, aes(real, guess_es)) +
    geom_abline(slope = 1, intercept = 0, color = "grey30") +
    geom_point() +
    geom_smooth(method = "lm") +
    xlab("The true effect size (d)") +
    ylab("Your guessed effect size (d)") +
    coord_cartesian(xlim = c(-1, 1), ylim = c(-1, 1)) +
    theme_minimal()
}

current_plot <- function(data, 
                         points  = FALSE, 
                         violin  = FALSE, 
                         boxplot = FALSE,
                         barplot = FALSE,
                         meanse = FALSE,
                         stats = FALSE,
                         m1 = 0, m2 = 0, sd = 1,
                         pt_width = 0.35) {
  p <- data %>%
    ggplot(aes(group, val, color = group, shape = group)) +
    coord_cartesian(ylim = c(-4, 4.5)) +
    ylab("") +
    scale_x_discrete(drop = F) +
    scale_y_continuous(breaks = c(-4, -2, 0, 2, 4)) +
    scale_colour_manual(values = c("red", "steelblue3"), drop = F) +
    scale_shape_manual(values = c(15, 19), drop = F) +
    theme_minimal()
  
  if (barplot) {
    p <- p + 
      stat_summary(fun.y=mean,
                   position=position_dodge(width=0.95),
                   geom="bar", fill = "white") +
      stat_summary(fun.data=mean_cl_normal,
                   position=position_dodge(0.95),
                   geom="errorbar", width = 0.25)
  }
  
  if (points) {
    pt_size <- max(1, 5.6 - log(nrow(data))) # not < 1
    p <- p + geom_point(size = pt_size, 
                        position = position_jitter(seed = 20, width = pt_width, height = 0))
  }
  
  if (violin & nrow(data) > 1) {
    p <- p + geom_violin(alpha = 0.3)
  }
  
  if (boxplot & nrow(data) > 1) {
    p <- p + geom_boxplot(width = 0.25, alpha = 0.3)
  }
  
  if (meanse & nrow(data) > 1) {
    p <- p + stat_summary(geom = "crossbar", fatten = 1, fun.y = mean, fun.ymax = mean, fun.ymin = mean) +
      stat_summary(geom = "errorbar", fun.data = mean_se, width = 0.15)
  }
  
  if (stats) {
    means <- data %>%
      add_row(group = "B", val = NA) %>%
      group_by(group) %>%
      summarise(m = mean(val, na.rm = TRUE),
                sd = sd(val, na.rm = TRUE)) %>%
      ungroup() %>%
      mutate(sd_pooled = sqrt(mean(sd))) %>%
      select(-sd) %>%
      spread(group, m)
    d <- (means$B - means$A)/means$sd_pooled

    p <- p + stat_summary(fun.data = function(x) {
      m <- mean(x) %>% round(2)
      s <- sd(x) %>% round(2)
      l <- paste0("sample M = ", m, ", SD = ", s)
      data.frame(y = 3.8, label = l)
    }, geom = "text", size = 5) +
      annotate("text", y = 4.6, x = 1.5, 
               label = sprintf("sample d = %1.2f", d),
               size = 5) +
      annotate("text", y = 4.2, x = 1, 
               label = sprintf("pop M = %1.2f, SD = %1.2f", m1, sd),
               color = "red", size = 5) +
      annotate("text", y = 4.2, x = 2, 
               label = sprintf("pop M = %1.2f, SD = %1.2f", m2, sd),
               color = "steelblue3", size = 5)
  }
  
  p + theme(legend.position = "none")
}