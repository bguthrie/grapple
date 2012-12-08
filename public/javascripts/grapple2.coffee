RandomDataSource = (interval) ->
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

GraphiteDataSource = (host, source, from) ->
  graphiteUrl = "#{host}/render?target=#{source}&from=#{from}&format=json"

  this.refresh = () =>
    $.Deferred (def) =>
      console.log graphiteUrl
      request = $.ajax(graphiteUrl, method: "get", dataType: "jsonp", jsonp: "jsonp")

      request.error (response) ->
        console.log(response)
        def.resolve []

      request.done (response) ->
        target = response[0]
        datapoints = target.datapoints.map (p) -> [ p[1] * 1000, p[0] ]
        def.resolve datapoints

  return this

DataSeries = (slide, settings) ->
  this[setting] = ko.observable(settings[setting]) for setting in ["color", "label", "source", "from"]
  this.from = ko.observable(settings.from || "-1week")
  this.points = ko.observable([])

  this.lastValue = ko.computed () =>
    point = this.points()[ this.points().length - 1 ]
    if point?
      parseFloat(point[1]).toFixed(1)
    else 0

  this.generator = ko.computed () =>
    if this.source() is "random"
      new RandomDataSource(slide.refreshInterval())
    else
      new GraphiteDataSource(slide.graphiteHost(), this.source(), this.from())

  this.refresh = () =>
    $.Deferred (def) =>
      this.generator().refresh().done (points) =>
        this.points(points)
        def.resolve(points)

  return this

Slide = (config, settings) ->
  this[setting] = ko.observable(settings[setting]) for setting in ["title", "subtitle", "refreshInterval"]
  this.points = ko.observableArray()
  this.active = ko.observable(false)
  this.graphiteHost = config.graphiteHost
  this.series = ko.observableArray(new DataSeries(this, config) for config in settings.series)

  this.refresh = () =>
    $.when(series.refresh() for series in this.series()).then () =>
      this.points({ data: series.points(), label: series.label() } for series in this.series())

  window.setInterval this.refresh, this.refreshInterval()

  return this

Config = () ->
  this.graphiteHost = ko.observable()
  this.format = ko.observable()
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

    $(".viewport").css height: curtainHeight, width: totalWidth, top: headerHeight, fontSize: chartLabelFontSize
    $(".slidemarkers a").css width: slidemarkerHeight, height: slidemarkerHeight
    $(".legend .color").css width: legendMarkerHeight, height: legendMarkerHeight

    rootFontSize = totalWidth / 14.0 # Magic numbers are magic.
    $("body").css fontSize: "#{rootFontSize}%"

    slides = $(".slide")
    $(".slides").css width: totalWidth * slides.length

    for s, i in slides
      $s = $(s)
      $s.css height: curtainHeight, width: totalWidth, left: totalWidth * i
      $s.find('.placeholder').css height: $s.height() - $s.find(".footer").height()  

  this.rotate = (binding, evt) =>
    idx = if evt.keyCode?
      switch evt.keyCode
        when 39, 32, 9 # Right arrow, space, tab
          this.nextIndex().next
        when 37 # Left arrow
          this.nextIndex().prev
    else
      parseInt $(evt.target).attr("href").slice(1), 10

    this.currentSlideIndex idx if idx?

  this.fullscreen = (binding, evt) =>
    $("body")[0].webkitRequestFullscreen()
    $("body").trigger 
    
  this.load = () =>
    $.get("config/grapple.json").done (response) =>
      this.graphiteHost(response.graphiteHost)
      this.format(response.format)
      _(response.slides).each (settings) =>
        this.slides.push new Slide(this, settings)

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
      colors: ( s.color() for s in slide.series() )

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
