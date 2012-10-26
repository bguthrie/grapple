interval = (ms, fn) -> window.setInterval fn, ms
timeout  = (ms, fn) -> window.setTimeout fn, ms

RandomData =
  generator: (interval) ->
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
          [ startTime, 1 ]

        [ oldTime, oldY ] = previous
        y = Math.max( 0.0, oldY + Math.random() - 0.48 )
        time = oldTime + interval

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
    $('.slidemarkers a').css width: slidemarkerHeight, height: slidemarkerHeight

    Grapple.resizeSlides()

  resizeSlides: () ->
    totalHeight = $(window).height()
    totalWidth = $(window).width()
    headerHeight = $("header").height()
    curtainHeight = totalHeight - headerHeight

    slides = $(".slide")
    $(".slides").css width: totalWidth * slides.length

    for s, i in slides
      $s = $(s)
      $s.css height: curtainHeight, width: totalWidth, left: totalWidth * i
      $s.find('.placeholder').css height: $s.height() - $s.find(".footer").height()
      $s.data('plot')?.redraw()

  slideTo: (slideIndex, callback) ->
    return if Grapple.sliding
    Grapple.sliding = true

    if slideIndex >= 0
      markers = $(".slidemarkers a")
      window.history.pushState {}, "", "#" + slideIndex
      $.when(
        markers.transition opacity: 0.2, 500, '_default'
      ).then(
        $(markers[slideIndex]).transition opacity: 0.8, 500, '_default')

    totalWidth = $(window).width()
    portPosition = totalWidth * -slideIndex
    $(".slides").transition x: "#{portPosition}px", 1000, '_default', () ->
      Grapple.sliding = false
      callback() if callback?

  defaults:
    graphiteHost: "localhost"
    refreshInterval: 10000
    transitionInterval: 20000
    format: "%m/%d %I%p"
    rotate: true

  sliding: false
  paused: false

  indexFromUrl: (url) ->
    parseInt url.slice(1), 10

  assembleSlides: (viewport, slides) ->
    slideContainer = viewport.find(".slides")

    for slide, i in slides
      $(".slidemarkers").append $("<a>").attr("href", "#" + i)
      slideContainer.append $("<div>").addClass("slide").attr("id", i)

    $(".slidemarkers a").click (evt) ->
      Grapple.slideTo Grapple.indexFromUrl($(this).attr("href"))
      evt.preventDefault()

    Grapple.resizeSlides()

    slideContainer.find(".slide")

  renderSettings: (viewport, config) ->
    basicSettings = 
      graphiteHost:       { label: "Graphite host", type: "text", default: "http://graphite.example.com" }
      transitionInterval: { label: "Slide transition interval", type: "text", default: 20000 }
      format:             { label: "Date/time format", type: "text", default: "%l:%M%p" }

    slideSettings =
      data:     { label: "Data Source", type: "select", default: "graphite", items: [["Graphite", "graphite"], ["Random", "random"]] }
      title:    { label: "Slide title", type: "text", default: "" }
      subtitle: { label: "Subtitle",    type: "text", default: "" }
      colors:   { label: "Colors",      type: "text", default: "RGB or hex (comma-separated)" }
      labels:   { label: "Labels",      type: "text", default: "String (comma-separated)" }

    dataSettings =
      random:
        refreshInterval: { label: "Data refresh interval", type: "text", default: 1000 }

      graphite:
        refreshInterval: { label: "Data refresh interval", type: "text", default: 10000 }
        from:            { label: "Duration",    type: "text", default: "Graphite duration (ex: -1week)" }
        target:          { label: "Targets",     type: "text", default: "Graphite targets (comma-separated)" }

    inputFor = (name, setting, config) ->
      label = $("<label>").text(setting.label)
      value = config[name] || setting.default
      input = if setting.type is "select"
        options = for item in setting.items
          $("<option>").val(item[1]).text(item[0]).attr(selected: item[1] is value)
        $("<select>").attr(name: name, disabled: true).append(options)
      else
        $("<input>").attr(name: name, type: setting.type, value: value, readonly: true)

      $("<p>").append(label, input)

    settings = viewport.find(".settings")
    form = settings.find("form")

    form.append $("<h3>").text("Settings")
    fset = $("<fieldset>")
    form.append fset
    for settingName, setting of basicSettings
      fset.append inputFor(settingName, setting, config)

    form.append $("<h3>").text("Slides")
    for slide in config.slides
      fset = $("<fieldset>")
      form.append fset
      for settingName, setting of $.extend(slideSettings, dataSettings[slide.data])
        fset.append inputFor(settingName, setting, slide)

    $("header nav a.settings").click (evt) -> settings.fadeIn() if settings.is(":hidden"); evt.preventDefault()
    settings.find("nav a.close").click (evt) -> settings.fadeOut() unless settings.is(":hidden"); evt.preventDefault()
    settings.click (evt) -> evt.stopPropagation(); evt.preventDefault()
    viewport.click (evt) -> settings.fadeOut() unless settings.is(":hidden"); evt.preventDefault()

  begin: (viewport, config) ->
    config = $.extend {}, Grapple.defaults, config
    viewport = $(viewport)

    $("h1.appname").fitText(3.0)
    viewport.find(".loading").fitText(1.0)
    $("header").fitText(5.0)

    Grapple.renderSettings(viewport, config)

    slides = config.slides.map (slide) ->
      extensions = host: config.graphiteHost, format: config.format
      slide = $.extend {}, extensions, slide
      Grapple.Slide.chart slide

    containers = Grapple.assembleSlides viewport, slides
    currentIndex = Grapple.indexFromUrl(window.location.hash) || 0

    $(window).resize Grapple.resize
    Grapple.resize()

    Grapple.slideTo -1, () ->
      slide = slides[currentIndex]
      slide.refresh (data) ->
        slide.render $(containers[currentIndex]), data
        viewport.find(".loading").fadeOut () ->
          Grapple.slideTo(currentIndex)

      for slide, i in slides
        if i isnt currentIndex
          slide.refresh (data) ->
            slide.render $(containers[i]), data

    if config.transitionInterval? && config.transitionInterval isnt ""
      interval config.transitionInterval, () ->
        currentIndex = ( currentIndex + 1 ) % slides.length
        Grapple.slideTo currentIndex

    $(window).on 'keyup', (evt) ->
      unless Grapple.sliding
        if evt.keyCode is 37
          currentIndex = if currentIndex is 0 then slides.length - 1 else currentIndex - 1
          Grapple.slideTo currentIndex
        else if evt.keyCode is 39
          currentIndex = ( currentIndex + 1 ) % slides.length
          Grapple.slideTo currentIndex

  Slide:

    chart: (slide) ->
      spec = slide.data

      if spec is "random"
        generator = RandomData.generator(slide.refreshInterval)
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
          xaxis:
            mode: "time", 
            timeformat: slide.format
            color: "white"
          yaxis:
            color: "white"
          grid:
            color: "#777"
            borderWidth: 1
          colors:
            slide.colors
          legend:
            container: legend
            show: true

        $.extend plot, Grapple.RedrawablePlot, legend: legend

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

  RedrawablePlot:
    redrawLegend: () ->
      labels = @legend.find(".legendLabel").map -> $(this).text()
      colors = @legend.find(".legendColorBox").map -> $(this).find("> div > div").css("borderColor")
      colorSize = @legend.css "fontSize"

      @legend.find("table").remove()
      for pair in _.zip(labels, colors)
        [label, color] = pair

        seriesLegend = $("<div>").addClass("series").append(
          $("<div>").addClass("color").css(backgroundColor: color, width: colorSize, height: colorSize),
          $("<div>").addClass("label").text(label))

        @legend.append seriesLegend

    redraw: () ->
      @resize()
      @setupGrid()
      @draw()
      @redrawLegend()


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
