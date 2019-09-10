# . data_tab ----
data_tab <- tabItem(
  tabName = "data_tab",
  downloadButton("download", "Download Session Data"),
  downloadButton("download_data", "Download All Data"),
  downloadButton("download_stats", "Download All Stats"),
  h3("Performance for All Subjects"),
  plotOutput("overall_plot", height = "600px"),
  h3("Current Session Data"),
  dataTableOutput("data_table")
)
