interval = (ms, fn) -> window.setInterval fn, ms
timeout  = (ms, fn) -> window.setTimeout fn, ms

Grapple = 
  resize: () ->
    totalHeight = $(window).height()
    headerHeight = $("header").height()
    footerHeight = $("footer").height()
    curtainHeight = totalHeight - headerHeight
    viewportHeight = curtainHeight - footerHeight
    slidemarkerHeight = 0.7 * headerHeight
    chartLabelFontSize = 0.35 * headerHeight

    $('#curtain').css width: $(window).width(), height: curtainHeight, top: headerHeight
    $('.slide').css width: $(window).width(), height: viewportHeight, top: headerHeight, fontSize: chartLabelFontSize
    $('.slidemarkers li').css width: slidemarkerHeight, height: slidemarkerHeight

    _.each $('.slide'), (s) ->
      if plot = $(s).data('plot')
        plot.resize()
        plot.setupGrid()
        plot.draw()
        plot.redrawLegend("#legend")

    fontSize = $("#legend").css "fontSize"
    $("#legend .color").css width: fontSize, height: fontSize

  begin: (config) ->
    slideIndex = 0

    slides = config.slides.map (slide) ->
      Grapple.Slide.chart $.extend(slide, host: config.graphiteHost)

    for slide in slides
      $("ul.slidemarkers").append $("<li>")
      $("#viewport").append $("<div>").addClass("slide")

    curtain = $("#curtain")
    containers = $(".slide")
    markers = $(".slidemarkers li")

    renderNextSlide = () ->
      console.log "Rendering slide", slideIndex
      slide = slides[slideIndex]
      marker = $(markers[slideIndex])
      container = $(containers[slideIndex])

      if slides.length is 1
        slide.refresh (data) ->
          if curtain.find(".loading").length > 0
            curtain.fadeTo 1000, 1.0, () ->
              container.show()
              slide.render container, data
              curtain.find(".loading").remove()
              marker.fadeTo 1000, 0.6
              curtain.fadeTo 1000, 0.0
          else
            slide.render container, data

        timeout config.refreshInterval, renderNextSlide

      else
        slide.refresh (data) ->
          markers.fadeTo 1000, 0.2
          curtain.fadeTo 1000, 1.0, () ->
            containers.hide()
            container.show()
            slide.render container, data

            marker.fadeTo 1000, 0.6
            curtain.fadeTo 1000, 0.0
            curtain.find(".loading").remove()

            slideIndex = ( slideIndex + 1 ) % slides.length
            timeout config.refreshInterval, renderNextSlide

    renderNextSlide()

  Slide:
    chart: (slide) ->
      spec = slide.data
      targets = (spec.target.map (t) -> "target=#{t}").join("&")
      graphiteUrl = "#{slide.host}/render?#{targets}&from=#{slide.data.from}&format=json"
      labels = slide.labels || spec.target
      series = labels.map (label) -> { label: label, data: [] }

      render: (root, datapoints) ->
        s.data = datapoints[i] for s, i in series

        if plot = $(root).data("plot")
          plot.setData(series)
          plot.setupGrid()
          plot.draw()
          plot.redrawLegend("#legend")
        else
          plot = $.plot root, series,
            xaxis: { mode: "time", timeformat: "%m/%d %I%p", color: "white" },
            yaxis: { color: "white" },
            grid: { color: "#777", borderWidth: 1 },
            colors: slide.colors
            legend: { container: "#legend", show: true, position: "sw", noColumns: series.length, backgroundOpacity: 0.0 }

          plot.redrawLegend = (legend) ->
            legend = $(legend)
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
          plot.redrawLegend("#legend")
          $("h1.title").text slide.title
          $("h2.subtitle").text slide.subtitle

      refresh: (callback) ->
        chartData = $.ajax graphiteUrl, method: "get", dataType: "jsonp", jsonp: "jsonp"

        chartData.error (response) ->
          console.log "error reloading", graphiteUrl

        chartData.done (response) ->
          datapoints = response.map (target) -> ( target.datapoints.map (p) -> [ p[1] * 1000, p[0] ] )
          callback datapoints


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
  $("h1.title").fitText(2.0)
  $("h2.subtitle").fitText(4.0)
  $("#legend").fitText(4.5)
  $("#curtain .loading").fitText(1.0)

  $("#curtain").css
    backgroundColor: $("body").css('backgroundColor')

  $(window).resize Grapple.resize
