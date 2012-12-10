Grapple =
  sources: []

Grapple.sources.random = (series) ->
  interval = series.slide.refreshInterval()
  totalSeconds = 3600
  totalPoints = totalSeconds / 10
  data = []
  date = new Date()
  now = Math.floor( date.getTime() / 1000 )
  startTime = now - totalSeconds

  isReady: () -> true

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

    $.Deferred () ->
      @resolve data

Grapple.sources.graphite = (series) ->
  from   = series.slide.from()
  target = series.target()
  host   = series.slide.config.graphiteHost()

  isReady: () => from? and target? and host?

  refresh: () =>
    $.Deferred (def) =>
      request = $.ajax "#{host}/render", 
        method: "get"
        dataType: "jsonp"
        jsonp: "jsonp"
        timeout: 1000
        data: 
          target: target
          from: from
          format: "json"

      request.fail (response) -> # Due to what appears to be a bug in jQuery, this is never called if the hostname doesn't point to a valid server.
        def.reject "The server is slow or unreachable."

      request.done (response) ->
        if response.length is 0
          def.reject "That stat was not found."
        else
          datapoints = response[0].datapoints.map (p) -> [ p[1] * 1000, p[0] ]
          def.resolve datapoints

DataSeries = (slide, settings) ->
  this[setting] = ko.observable(settings[setting]) for setting in ["color", "label", "source", "target"]
  @points = ko.observable([])
  @errorMessage = ko.observable()
  @isValid = ko.computed () => !@errorMessage()?
  @slide = slide

  @sources = ko.computed () => ( name for name, fn of Grapple.sources )

  @lastValue = ko.computed () =>
    point = @points()[ @points().length - 1 ]
    if point? then parseFloat(point[1]).toFixed(1) else 0

  @size = ko.computed () =>
    0.5 * slide.config.headerHeight()

  @generator = ko.computed () =>
    @points []
    if sourceGen = Grapple.sources[@source()]
      sourceGen(this)

  @refresh = () =>
    $.Deferred (def) =>
      if @generator().isReady()
        refresh = @generator().refresh()

        refresh.done (points) => 
          @errorMessage null
          @points(points)
          def.resolve(points)

        refresh.fail (message) => @errorMessage message

  return this

Slide = (config, settings) ->
  this[setting] = ko.observable(settings[setting]) for setting in ["title", "subtitle"]

  @config = config
  @points = ko.observableArray()
  @active = ko.observable(false)
  @from = ko.observable(settings.from || "-1week")
  @refreshInterval = ko.observable(settings.refreshInterval || 10)
  @series = ko.observableArray(new DataSeries(this, config) for config in settings.series)

  @markerSize = ko.computed () =>
    0.7 * @config.headerHeight()

  @height       = @config.curtainHeight
  @width        = @config.width
  @footerHeight = ko.observable()

  @chartHeight = ko.computed () =>
    @height() - @footerHeight()

  @resize = (binding, evt) =>
    if $(evt.target).is(".slide")
      @footerHeight $(evt.target).find("footer").height()

  @addSeries = (series) => 
    newIndex = @series.indexOf(series) + 1
    @series.splice newIndex, 0, new DataSeries(this, {})

  @removeSeries = (series) =>
    @series.remove series

  @refresh = () =>
    $.when(series.refresh() for series in @series()).then () =>
      @points({ data: series.points(), label: series.label() } for series in @series())
      window.setTimeout @refresh, @refreshInterval() * 1000

  @refresh()

  return this

Root = () ->
  @graphiteHost      = ko.observable()
  @format            = ko.observable()
  @slides            = ko.observableArray()
  @settingsVisible   = ko.observable(false)

  @height            = ko.observable()
  @width             = ko.observable()
  @headerHeight      = ko.observable()

  prevLoc = parseInt(window.location.hash.slice(1), 10)
  @currentSlideIndex = ko.observable(prevLoc || 0)

  @slideCount = ko.computed () => 
    @slides().length

  @nextIndex = ko.computed () => 
    idx = @currentSlideIndex()
    len = @slides().length
    { next: ( idx + 1 ) % len,  prev: if idx is 0 then len - 1 else idx - 1 }

  @curtainHeight = ko.computed () =>
    @height() - @headerHeight()

  @rootFontSize = ko.computed () =>
    "#{@width() / 14.0}%" # Magic numbers are magic.

  @slideContainerWidth = ko.computed () =>
    @width() * @slideCount()

  slider = ko.computed () =>
    idx = @currentSlideIndex()
    if idx >= 0 then window.history.pushState {}, "", "#" + idx

    portPosition = @width() * -idx
    $(".slides").transition x: "#{portPosition}px", 200, '_default'

    slide.active(false) for slide in @slides()
    @slides()[idx]?.active(true)

  slider.extend throttle: 50

  @resize = (binding, evt) =>
    @height       $(evt.target).height()
    @width        $(evt.target).width()
    @headerHeight $(evt.target).find("header").height()

  @newSlide = (binding, evt) =>
    newSlideIndex = @slideCount()
    @slides.push new Slide(this, title: "", subtitle: "", series: [])
    @currentSlideIndex newSlideIndex
    @settingsVisible true

  @rotate = (binding, evt) =>
    idx = if evt.keyCode? and $(":focus").length is 0
      switch evt.keyCode
        when 39, 32, 9 # Right arrow, space, tab
          @nextIndex().next
        when 37 # Left arrow
          @nextIndex().prev
    else if target = $(evt.currentTarget).attr("href")
      parseInt target.slice(1), 10

    @currentSlideIndex idx if idx?

  @fullscreen = (binding, evt) =>
    $("body")[0].webkitRequestFullscreen()

  @showSettings = (binding, evt) =>
    @settingsVisible !@settingsVisible()
    
  @load = () =>
    $.get("config/grapple.json").done (response) =>
      @graphiteHost(response.graphiteHost)
      @format(response.format)
      @slides.push(new Slide(this, settings)) for settings in response.slides

  @load()

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
    plot.getOptions().colors = (series.color() for series in slide.series())
    plot.setData slide.points()
    plot.resize()
    plot.setupGrid()
    plot.draw()

$ ->
  ko.applyBindings new Root()
  $("body").trigger("resize")
