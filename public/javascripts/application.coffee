interval = (ms, fn) -> window.setInterval fn, ms
timeout  = (ms, fn) -> window.setTimeout fn, ms

RandomData =
  generator: () ->
    totalSeconds = 3600
    totalPoints = totalSeconds / 10
    data = []
    date = new Date()
    now = Math.floor( date.getTime() / 1000 )
    startTime = now - totalSeconds

    refresh: () ->
      if data.length > 0
        data = data.slice 1

      while data.length < totalPoints
        previous = if data.length > 0
          data[data.length - 1]
        else
          [ startTime, 50 ]

        [ oldTime, oldY ] = previous
        y = oldY + Math.random() * 10 - 5
        time = oldTime + 10

        data.push [ time, y ]

      data

window.Grapple =
  resize: () ->
    totalHeight = $(window).height()
    totalWidth = $(window).width()
    headerHeight = $("header").height()
    curtainHeight = totalHeight - headerHeight
    slidemarkerHeight = 0.7 * headerHeight
    chartLabelFontSize = 0.35 * headerHeight

    $("#viewport").css height: curtainHeight, width: totalWidth, top: headerHeight, fontSize: chartLabelFontSize
    $('.slidemarkers li').css width: slidemarkerHeight, height: slidemarkerHeight

    _.each $('.slide'), (s) ->
      $s = $(s)
      $s.css height: curtainHeight, width: width: totalWidth
      $s.find('.placeholder').css height: $s.height() - $s.find(".footer").height()

      if plot = $s.data('plot')
        plot.resize()
        plot.setupGrid()
        plot.draw()
        plot.redrawLegend("")

    fontSize = $("#legend").css "fontSize"
    $("#legend .color").css width: fontSize, height: fontSize

  begin: (config) ->
    slideIndex = 0
    viewport = $("#viewport")
    slideContainer = viewport.find(".slides")

    slides = config.slides.map (slide) ->
      Grapple.Slide.chart $.extend(slide, host: config.graphiteHost)

    for slide in slides
      $("ul.slidemarkers").append $("<li>")
      slideContainer.append $("<div>").addClass("slide")

    # curtain = $("#curtain")
    containers = slideContainer.find(".slide")
    markers = $(".slidemarkers li")

    renderFirstSlide = (container, slide, data) ->
      width = $(window).width()
      container.transition x: "-#{width}px", () ->
        slide.render container, data
        viewport.find(".loading").fadeOut () ->
          container.transition x: "0px"

    renderNextSlide = () ->
      console.log "Rendering slide", slideIndex
      slide = slides[slideIndex]
      marker = $(markers[slideIndex])
      container = $(containers[slideIndex])

      # TODO Position all slides next to each other.

      slide.refresh (data) ->
        renderFirstSlide(container, slide, data) if viewport.find(".loading").length > 0

    renderNextSlide()



  Slide:

    chart: (slide) ->
      spec = slide.data

      if spec is "random"
        generator = RandomData.generator()
      else
        targets = (spec.target.map (t) -> "target=#{t}").join("&")
        graphiteUrl = "#{slide.host}/render?#{targets}&from=#{slide.data.from}&format=json"

      labels = slide.labels || spec.target
      series = labels.map (label) -> { label: label, data: [] }
      plot = null

      render = (root, datapoints) ->
        if plot? 
          @rerender; return

        s.data = datapoints[i] for s, i in series

        placeholder = $("<div>").addClass("placeholder")
        title = $("<h1>").addClass("title").text(slide.title)
        subtitle = $("<h2>").addClass("subtitle").text(slide.subtitle)
        legend = $("<div>").addClass("legend").text("Legend")
        footer = $("<div>").addClass("footer").append(legend, title, subtitle)
        $(root).append(placeholder, footer)

        title.fitText(2.0)
        subtitle.fitText(4.0)
        legend.fitText(4.5)

        placeholder.css height: root.height() - footer.height()

        plot = $.plot placeholder, series,
          xaxis: { mode: "time", timeformat: "%m/%d %I%p", color: "white" },
          yaxis: { color: "white" },
          grid: { color: "#777", borderWidth: 1 },
          colors: slide.colors
          legend: { container: legend, show: true, position: "sw", noColumns: series.length, backgroundOpacity: 0.0 }

        plot.redrawLegend = () ->
          labels = legend.find(".legendLabel").map -> $(this).text()
          colors = legend.find(".legendColorBox").map -> $(this).find("> div > div").css("borderColor")
          colorSize = legend.css "fontSize"

          legend.find("table").remove()
          for pair in _.zip(labels, colors)
            [label, color] = pair

            seriesLegend = $("<div>").addClass("series").append(
              $("<div>").addClass("color").css(backgroundColor: color, width: colorSize, height: colorSize),
              $("<div>").addClass("label").text(label))

            legend.append seriesLegend

        $(root).data("plot", plot)
        plot.redrawLegend()

        interval 10000, () ->
          refresh (datapoints) ->
            rerender datapoints

      rerender = (datapoints) ->
        s.data = datapoints[i] for s, i in series
        plot.setData(series)
        plot.setupGrid()
        plot.draw()
        plot.redrawLegend()

      refresh = (callback) ->
        if generator
          callback [ generator.refresh() ]
        else
          chartData = $.ajax graphiteUrl, method: "get", dataType: "jsonp", jsonp: "jsonp"

          chartData.error (response) ->
            console.log "error reloading", graphiteUrl

          chartData.done (response) ->
            datapoints = response.map (target) -> ( target.datapoints.map (p) -> [ p[1] * 1000, p[0] ] )
            callback datapoints

      refresh: refresh, render: render

$ ->
  settings = $.get("config/grapple.json")

  settings.fail (response) ->
    $("#curtain .loading").text "error"
    $("#curtain .more").text("could not load or parse configuration | ")
    $("#curtain .more").append($("<a>").text("help").attr("href", "https://github.com/bguthrie/grapple/blob/master/README.md"))

    Grapple.resize()
    $("#curtain .loading").fitText(1.0)

  settings.done (response) ->
    Grapple.begin(response)
    Grapple.resize()
    $("#curtain .loading").fitText(1.0)

  $("h1.appname").fitText(3.0)
  $("#viewport .loading").fitText(1.0)

  $(window).resize Grapple.resize
