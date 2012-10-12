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
    $('#placeholder').css width: $(window).width(), height: viewportHeight, top: headerHeight, fontSize: chartLabelFontSize
    $('.slidemarkers li').css width: slidemarkerHeight, height: slidemarkerHeight

    fontSize = $("#legend").css "fontSize"
    $("#legend .color").css width: fontSize, height: fontSize

  begin: (config) ->
    slides = config.slides.map (slide) ->
      Grapple.Slide.chart $.extend(slide, host: config.graphiteHost)

    slideIndex = 0

    for slide in slides
      $("ul.slidemarkers").append $("<li>")

    behindCurtain = (renderSlide) ->
      $(".slidemarkers li").fadeTo 500, 0.2
      $('#curtain').fadeTo 500, 1.0, () ->
        renderSlide()
        $( $(".slidemarkers li")[slideIndex] ).fadeTo 1000, 0.6
        slideIndex = ( slideIndex + 1 ) % slides.length
        $('#curtain').fadeTo 1000, 0.0
        $("#curtain .loading").remove()

    renderNextSlide = () ->
      console.log "Rendering slide", slideIndex
      slide = slides[slideIndex]
      slide.refresh (data) ->
        behindCurtain () ->
          slide.render "#placeholder", data
          timeout config.refreshInterval, renderNextSlide

    renderNextSlide()

  Slide:
    chart: (slide) ->
      spec = slide.data
      targets = (spec.target.map (t) -> "target=#{t}").join("&")
      graphiteUrl = "#{slide.host}/render?#{targets}&from=#{slide.data.from}&format=json"
      labels = slide.labels || spec.target

      render: (root, datapoints) ->
        series = _.zip(labels, datapoints).map (s) -> { label: s[0], data: s[1] }

        $.plot root, series,
          xaxis: { mode: "time", timeformat: "%m/%d %I%p", color: "white" },
          yaxis: { color: "white" },
          grid: { color: "#777", borderWidth: 1 },
          colors: slide.colors
          legend: { container: "#legend", show: true, position: "sw", noColumns: series.length, backgroundOpacity: 0.0 }

        labels = $("#legend .legendLabel").map -> console.log(this); $(this).text()
        colors = $("#legend .legendColorBox").map -> $(this).find("> div > div").css("borderColor")
        legend = _.zip labels, colors
        colorSize = $("#legend").css "fontSize"

        $("#legend table").remove()
        for pair in _.zip(labels, colors)
          [label, color] = pair

          seriesLegend = $("<div>").addClass("series").append(
            $("<div>").addClass("color").css(backgroundColor: color, width: colorSize, height: colorSize),
            $("<div>").addClass("label").text(label))

          $("#legend").append seriesLegend

        $("h1.title").text slide.title
        $("h2.subtitle").text slide.subtitle

      refresh: (callback) ->
        console.log "Refreshing data"
        chartData = $.ajax graphiteUrl, method: "get", dataType: "jsonp", jsonp: "jsonp"

        chartData.error (response) ->
          console.log "error reloading", graphiteUrl

        chartData.done (response) ->
          datapoints = response.map (target) -> ( target.datapoints.map (p) -> [ p[1] * 1000, p[0] ] )
          callback datapoints


$ ->
  settings = $.get("config/grapple.json")

  settings.fail (response) ->
    console.log "Error finding or parsing grapple.json"

  settings.done (response) ->
    Grapple.begin(response)
    Grapple.resize()
    $("#curtain .loading").fitText(1.0)

  $("h1.appname").fitText(3.0)
  $("h1.title").fitText(2.0)
  $("h2.subtitle").fitText(4.0)
  $("#legend").fitText(4.5)

  $("#curtain").css
    backgroundColor: $("body").css('backgroundColor')

  $(window).resize Grapple.resize