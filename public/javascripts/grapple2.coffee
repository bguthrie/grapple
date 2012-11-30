RandomData =
  generator: (interval) ->
    totalSeconds = 3600
    totalPoints = totalSeconds / 10
    data = []
    date = new Date()
    now = Math.floor( date.getTime() / 1000 )
    startTime = now - totalSeconds

    refresh: (callback) ->
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

      callback data



Slide = (settings) ->
  for name, setting of settings
    this[name] = ko.observable(setting)

  this.datapoints = ko.observable([])

  if settings.data is "random"
    this.generator = RandomData.generator(this.refreshInterval())

  this.load = () =>
    this.generator.refresh (data) =>
      this.datapoints(data)

  this.load()
  return this

Config = (response) ->
  this.graphiteHost = ko.observable("")
  this.format = ko.observable("")
  this.slides = ko.observableArray()

  this.load = () =>
    $.get("config/grapple.json").done (response) =>
      this.graphiteHost(response.graphiteHost);
      this.format(response.format)
      _(response.slides).each (settings) =>
        this.slides.push new Slide(settings)

  this.load()
  return this

$ ->
  c = new Config()
  ko.applyBindings c
  console.log c
