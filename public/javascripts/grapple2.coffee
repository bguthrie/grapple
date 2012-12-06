RandomDataGenerator = (interval) ->
  totalSeconds = 3600
  totalPoints = totalSeconds / 10
  data = []
  date = new Date()
  now = Math.floor( date.getTime() / 1000 )
  startTime = now - totalSeconds

  this.refresh = () ->
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

    $.Deferred () ->
      this.resolve data

  return this

DataSeries = (settings) ->
  for name, setting of settings
    this[name] = ko.observable(setting)

  this.points = ko.observable([])

  if settings.source is "random"
    this.generator = new RandomDataGenerator(this.refreshInterval())

  this.refresh = () =>
    $.Deferred (def) =>
      this.generator.refresh().done (points) =>
        this.points(points)
        def.resolve(points)

  return this

Slide = (settings) ->
  for name, setting of settings
    this[name] = ko.observable(setting)

  this.series = ko.observableArray()
  this.points = ko.observableArray()

  for config in settings.series
    config.refreshInterval = this.refreshInterval()
    this.series.push new DataSeries(config)

  this.rotate = () ->
    console.log "shifting"

  this.resize = () =>


  this.refresh = () =>
    $.when(series.refresh() for series in this.series()).then () =>
      this.points({ data: series.points(), label: series.label() } for series in this.series())

  window.setInterval this.refresh, this.refreshInterval()

  return this

Config = (response) ->
  this.graphiteHost = ko.observable("")
  this.format = ko.observable("")
  this.slides = ko.observableArray()

  this.resize = () =>
    totalHeight = $(window).height()
    totalWidth = $(window).width()
    headerHeight = $("header").height()
    curtainHeight = totalHeight - headerHeight
    slidemarkerHeight = 0.7 * headerHeight
    legendMarkerHeight = 0.5 * headerHeight
    chartLabelFontSize = 0.35 * headerHeight

    $("#viewport").css height: curtainHeight, width: totalWidth, top: headerHeight, fontSize: chartLabelFontSize
    $(".slidemarkers a").css width: slidemarkerHeight, height: slidemarkerHeight
    $(".legend .color").css width: legendMarkerHeight, height: legendMarkerHeight

    this.resizeSlides()

  this.resizeSlides = () =>
    totalHeight = $(window).height()
    totalWidth = $(window).width()
    headerHeight = $("header").height()
    curtainHeight = totalHeight - headerHeight

    slides = $(".slide")
    $(".slides").css width: totalWidth * slides.length

    $("[data-fit-text]").each () ->
      $this = $(this)
      compressionFactor = parseFloat($this.attr('data-fit-text') || "1.0")
      fontSize = $this.width() / (compressionFactor * 10)
      $this.css(fontSize: fontSize);

    for s, i in slides
      $s = $(s)
      $s.css height: curtainHeight, width: totalWidth, left: totalWidth * i
      $s.find('.placeholder').css height: $s.height() - $s.find(".footer").height()

  this.load = () =>
    $.get("config/grapple.json").done (response) =>
      this.graphiteHost(response.graphiteHost);
      this.format(response.format)
      _(response.slides).each (settings) =>
        this.slides.push new Slide(settings)

  this.load()
  return this

PlotHandler = () ->
  this.plot = null

  this.init = (elt, value, allBindings, slide, context) ->
    format = context.$root.format()

    plot = $.plot elt, slide.points(),
      xaxis:
        mode: "time", 
        timeformat: format
        color: "white"
      yaxis:
        color: "white"
      grid:
        color: "#777"
        borderWidth: 1
      colors:
        slide.colors
      legend: false

    this.plot = plot
    series.color(plot.getOptions().colors[i]) for series, i in slide.series()

    $("body").trigger "resize"

  this.update = (elt, value, allBindings, slide, context) ->
    plot = this.plot
    plot.setData slide.points()
    plot.resize()
    plot.setupGrid()
    plot.draw()

  return this

ko.bindingHandlers.plot = new PlotHandler()

$ ->
  c = new Config()
  ko.applyBindings c
  $("body").trigger("resize")
