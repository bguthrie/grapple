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

  begin: (config) ->
    slides = $.map config.slides, (slide) -> Grapple.Slide.chart($.extend(slide, host: config.graphiteHost))
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
      slides[slideIndex].refresh (data) ->
        behindCurtain () ->
          slide.render "#placeholder", data
          timeout config.refreshInterval, renderNextSlide

    renderNextSlide()

  Slide:
    chart: (slide) ->
      spec = slide.data
      targets = $.map(spec.target, (t) -> "target=#{t}").join("&")
      graphiteUrl = "#{slide.host}/render?#{targets}&from=#{slide.data.from}&format=json"

      render: (root, datapoints) ->
        console.log "Rendering data"
        $.plot root, datapoints, xaxis: { mode: "time", timeformat: "%m/%d %I%p", color: "white" }, yaxis: { color: "white" }, grid: { color: "#333" }, colors: slide.colors
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

  $("#curtain").css
    backgroundColor: $("body").css('backgroundColor')

  $(window).resize Grapple.resize