library(shiny)
library(data.table)
library(ggplot2)

shinyServer(function(input, output, session) {
  
  standard <- reactive({
    as.numeric(input$ozoneStandard) / 1000
  })
  
  subsetReadings <- reactive({
    
    yR <- input$yearSlider
    
    r <- readings[readings$YEAR >= yR[[1]] & readings$YEAR <= yR[[2]], ]
    
    return(r)
    
  })
  
  totalReadings <- reactive({
    
    data <- subsetReadings()
    op <- data[, list(EXCEED_ALL = sum(VALUE > standard())), by = "STATE_CODE"]
    
    return(op)
    
  })
  
  targetReadings <- reactive({
    
    data <- subsetReadings()
    controlSeason <- input$seasonSlider

    minDate <- as.numeric(format(as.POSIXct(controlSeason$min), "%m%d"))
    
    maxDate <- as.numeric(format(as.POSIXct(controlSeason$max), "%m%d"))

    return(data[data$DAY >= minDate & data$DAY <= maxDate, ])
    
  })
  
  outputData <- reactive({
    
    data <- targetReadings()
    
    op <- data[, list(TOTAL = length(VALUE), EXCEED = sum(VALUE > standard())), by = "STATE_CODE"]

    op$PERCENT <- paste0(round((op$EXCEED / op$TOTAL) * 100, 0), "%") 

    totData <- totalReadings()
    op <- merge(op, totData, by = "STATE_CODE", all.x = TRUE, all.y = FALSE)
    
    session$sendCustomMessage("percentUpdate", op)
    
    return(op)
    
  })
  
  dataTable <- reactive({
    
    data <- outputData()
    
    data$STATE_CODE <- sapply(data$STATE_CODE, function(sc) {
      return(names(states)[states == sc])
    })
    
    data <- rbind(data, list("Total", sum(data$TOTAL), sum(data$EXCEED), paste0(round(sum(data$EXCEED)/sum(data$TOTAL)*100, 0), "%"), sum(data$EXCEED_ALL)))
    
    data$inSeason <- paste0(data$EXCEED, "/", data$TOTAL, " (", data$PERCENT, ")")
    data$seasonCapture <- paste0(data$EXCEED, "/", data$EXCEED_ALL, " (", round((data$EXCEED / data$EXCEED_ALL * 100), 0), "%)")
    
    data <- data[, c("STATE_CODE", "inSeason", "seasonCapture"), with = FALSE]
    
    setnames(data, c("State", "Exceedances in Season", "Exceedance Capture"))
    
    return(data)
    
  })
  
  output$tableOutput <- renderTable({
    
    session$sendCustomMessage("tableTooltips", TRUE)
    
    return(dataTable())
    
  }, include.rownames = FALSE)
  
  output$graphOutput <- renderPlot({
    
    data <- outputData()
    data$EXPERC <- round(data$EXCEED / data$EXCEED_ALL * 100, 0)
        
    data$STATE_CODE <- sapply(data$STATE_CODE, function(sc) {
      return(names(states)[states == sc])
    })
    
    data <- data[, c("STATE_CODE", "EXPERC"), with = FALSE]
    
    return(ggplot(data, aes(x = STATE_CODE, y = EXPERC)) 
           + geom_bar(stat = "identity") + xlab("State") 
           + scale_y_continuous(limits = c(0, 100))
           + ylab("Exceedance Capture (%)") + coord_flip())
    
  }, width = 600, height = 600)
  
  output$downloadSummary <- downloadHandler(filename = paste0("ozone-summary-", Sys.Date(), ".csv"),
                                         content = function(file) {
                                           write.csv(dataTable(), file = file, row.names = FALSE)    
  })
  
  output$downloadRaw <- downloadHandler(filename = paste0("ozone-raw", Sys.Date(), ".csv"),
                                            content = function(file) {
                                              write.csv(targetReadings(), file = file, row.names = FALSE)    
                                            })
  
  calcSeason <- observeEvent(input$calcSeason, ({
    
    sl <- input$seasonLength - 1
    std <- standard()
    
    data <- subsetReadings()
    
    sd <- as.Date("2004-03-01")
    ed <- sd + sl
    win <- list(list(startDate = sd, endDate = ed, count = 0))
    
    while(ed <= as.Date("2004-10-31")) {
     
      s <- as.numeric(format(sd, "%m%d"))
      e <- as.numeric(format(ed, "%m%d"))
      
      sub <- data[data$DAY >= s & data$DAY <= e, ]
      
      exceed <- sum(sub$VALUE > std)
      
      if(exceed > win[[1]]$count) {
        win <- list(list(startDate = as.POSIXct(sd), endDate = as.POSIXct(ed), count = exceed))
      } else if(exceed == win[[1]]$count) {
        win <- c(win, list(startDate = as.POSIXct(sd), endDate = as.POSIXct(ed), count = exceed))
      }
      
      sd <- sd + 1
      ed <- sd + sl
      
    }
    
    session$sendCustomMessage("optimalSeason", win[[1]])  
    
    if(length(win) > 1) {
      print("Multiple Seasons Found")
    }
    
  }))
  
  observe({
    outputData()
  })
  
})
