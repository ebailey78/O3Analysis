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
    op <- data[, list(EXCEED_ALL = sum(VALUE >= standard())), by = "STATE_CODE"]
    
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
    
    op <- data[, list(TOTAL = length(VALUE), EXCEED = sum(VALUE >= standard())), by = "STATE_CODE"]

    op$PERCENT <- paste0(round((op$EXCEED / op$TOTAL) * 100, 0), "%") 

    totData <- totalReadings()
    op <- merge(op, totData, by = "STATE_CODE", all.x = TRUE, all.y = FALSE)
    
    session$sendCustomMessage("percentUpdate", op)
    
    return(op)
    
  })
  
  output$tableOutput <- renderTable({
    
    data <- outputData()

    
    data$STATE_CODE <- sapply(data$STATE_CODE, function(sc) {
      return(names(states)[states == sc])
    })
    
    data$inSeason <- paste0(data$EXCEED, "/", data$TOTAL, " (", data$PERCENT, ")")
    data$seasonCapture <- paste0(data$EXCEED, "/", data$EXCEED_ALL, " (", round((data$EXCEED / data$EXCEED_ALL * 100), 0), "%)")
    
    data <- data[, c("STATE_CODE", "inSeason", "seasonCapture"), with = FALSE]
    
    setnames(data, c("State", "Exceedences in Season", "Exceedence Capture"))
    
    return(data)
    
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
           + ylab("Exceedence Capture (%)") + coord_flip())
    
  }, width = 600, height = 600)
  
  observe({
    outputData()
  })
  
})
