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

    Grapple.resizeSlides()

  resizeSlides: () ->
    totalHeight = $(window).height()
    totalWidth = $(window).width()
    headerHeight = $("header").height()
    curtainHeight = totalHeight - headerHeight

    slides = $(".slide")

    widthOfAllSlides = totalWidth * slides.length
    $(".slides").css width: widthOfAllSlides

    for s, i in slides
      $s = $(s)
      $s.css height: curtainHeight, width: totalWidth, left: totalWidth * i
      $s.find('.placeholder').css height: $s.height() - $s.find(".footer").height()
      $s.data('plot')?.redraw()

  slideTo: (slideIndex, callback) ->
    console.log "Sliding to", slideIndex
    if slideIndex >= 0
      markers = $(".slidemarkers li")
      markers.transition opacity: 0.2, 500, '_default', () ->
        $(markers[slideIndex]).transition opacity: 0.8, 500

    totalWidth = $(window).width()
    portPosition = totalWidth * -slideIndex
    $(".slides").transition x: "#{portPosition}px", 1000, '_default', callback

  defaults:
    graphiteHost: "localhost"
    refreshInterval: 10000
    transitionInterval: 20000
    format: "%m/%d %I%p"
    rotate: true

  begin: (viewport, config) ->
    config = $.extend {}, Grapple.defaults, config
    viewport = $(viewport)
    slideIndex = 0
    slideContainer = viewport.find(".slides")

    slides = config.slides.map (slide) ->
      slide = $.extend {}, { host: config.graphiteHost, refreshInterval: config.refreshInterval, format: config.format }, slide
      Grapple.Slide.chart slide

    for slide, i in slides
      $("ul.slidemarkers").append $("<li>")
      slideContainer.append $("<div>").addClass("slide").attr("id", i)

    Grapple.resizeSlides()
    containers = slideContainer.find(".slide")

    _.each slides, (slide, i) ->
      slide.refresh (data) ->
        if i is 0
          Grapple.slideTo -1, () ->
            slide.render $(containers[i]), data
            viewport.find(".loading").fadeOut () ->
              Grapple.slideTo(i)
        else
          slide.render $(containers[i]), data

    if config.rotate
      interval config.transitionInterval, () ->
        slideIndex = ( slideIndex + 1 ) % slides.length
        Grapple.slideTo(slideIndex)

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

      render = (root, datapoints) ->
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
          xaxis: { mode: "time", timeformat: slide.format, color: "white" },
          yaxis: { color: "white" },
          grid: { color: "#777", borderWidth: 1 },
          colors: slide.colors
          legend: { container: legend, show: true, position: "sw", noColumns: series.length, backgroundOpacity: 0.0 }

        plot.redraw = () ->
          @resize()
          @setupGrid()
          @draw()
          @redrawLegend()

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

        interval slide.refreshInterval, () ->
          refresh (datapoints) ->
            update plot, datapoints

      update = (plot, datapoints) ->
        s.data = datapoints[i] for s, i in series
        plot.setData(series)
        plot.redraw()

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

      refresh: refresh, render: render, slide: slide

$ ->
  settings = $.get("config/grapple.json")
  viewport = $("#viewport")

  settings.fail (response) ->
    viewport.find(".loading").text "error"
    viewport.find(".more").
      text("could not load or parse configuration | ").
      append($("<a>").text("help").attr("href", "https://github.com/bguthrie/grapple/blob/master/README.md"))

  settings.done (response) ->
    viewport.find(".loading").text("please wait")
    Grapple.begin(viewport, response)
    Grapple.resize()

  $("h1.appname").fitText(3.0)
  viewport.find(".loading").fitText(1.0)

  $(window).resize Grapple.resize
