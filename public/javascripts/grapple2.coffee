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

  this.lastValue = ko.computed () =>
    point = this.points()[ this.points().length - 1 ]
    if point?
      point[1].toFixed(2)
    else 0

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
  this.active = ko.observable(false)

  for config in settings.series
    config.refreshInterval = this.refreshInterval()
    this.series.push new DataSeries(config)

  this.refresh = () =>
    $.when(series.refresh() for series in this.series()).then () =>
      this.points({ data: series.points(), label: series.label() } for series in this.series())

  window.setInterval this.refresh, this.refreshInterval()

  return this

Config = () ->
  this.graphiteHost = ko.observable("")
  this.format = ko.observable("")
  this.slides = ko.observableArray()
  this.currentSlideIndex = ko.observable(0)
  this.nextIndex = ko.computed () => 
    idx = this.currentSlideIndex()
    len = this.slides().length
    { next: ( idx + 1 ) % len,  prev: if idx is 0 then len - 1 else idx - 1 }

  slider = ko.computed () =>
    idx = this.currentSlideIndex()
    if idx >= 0
      markers = $(".slidemarkers a")
      window.history.pushState {}, "", "#" + idx

    totalWidth = $(window).width()
    portPosition = totalWidth * -idx
    $(".slides").transition x: "#{portPosition}px", 1000, '_default'

    slide.active(false) for slide in this.slides()
    this.slides()[idx]?.active(true)

  slider.extend throttle: 200

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

  this.rotate = (binding, evt) =>
    idx = if evt.keyCode?
      if evt.keyCode is 39 then this.nextIndex().next else this.nextIndex().prev
    else
      parseInt $(evt.target).attr("href").slice(1), 10

    this.currentSlideIndex idx
    
  this.load = () =>
    $.get("config/grapple.json").done (response) =>
      this.graphiteHost(response.graphiteHost);
      this.format(response.format)
      _(response.slides).each (settings) =>
        this.slides.push new Slide(settings)

  this.load()
  return this

ko.bindingHandlers.plot =
  init: (elt, value, allBindings, slide, context) ->
    format = context.$root.format()

    plot = $.plot elt, slide.points(),
      xaxis:
        mode: "time", 
        timeformat: format
        color: "white"
        tickLength: 0
      yaxis:
        color: "white"
        tickLength: 0
      grid:
        color: "#777"
        borderWidth: 0
      legend: false

    $(elt).data "plot", plot
    series.color(plot.getOptions().colors[i]) for series, i in slide.series()

    $("body").trigger "resize"

  update: (elt, value, allBindings, slide, context) ->
    plot = $(elt).data "plot"
    plot.setData slide.points()
    plot.resize()
    plot.setupGrid()
    plot.draw()

$ ->
  c = new Config()
  ko.applyBindings c
  $("body").trigger("resize")
