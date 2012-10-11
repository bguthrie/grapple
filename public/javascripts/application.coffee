interval = (ms, fn) -> window.setInterval fn, ms
timeout  = (ms, fn) -> window.setTimeout fn, ms

Grapple = 
  resize: () ->
    totalHeight = $(window).height()
    headerHeight = $("header").height()
    footerHeight = $("footer").height()
    curtainHeight = totalHeight - headerHeight
    viewportHeight = curtainHeight - footerHeight

    console.log "header height", $("header").height(), "footer height", $("footer").height(), "curtain height", curtainHeight, "viewport height", viewportHeight

    $('#curtain').css width: $(window).width(), height: curtainHeight, top: headerHeight
    $('#placeholder').css width: $(window).width(), height: viewportHeight, top: headerHeight

  series: (slide) ->
    targets = $.map(slide.data.target, (t) -> "target=#{t}").join("&")
    graphiteUrl = "#{slide.host}/render?#{targets}&from=#{slide.data.from}&format=json"

    (callback) ->
      chartData = $.ajax graphiteUrl,
        method: "get",
        dataType: "jsonp",
        jsonp: "jsonp"

      chartData.error (response) ->
        console.log "error reloading", graphiteUrl

      chartData.done (response) ->
        datapoints = response.map (target) -> ( target.datapoints.map (p) -> [ p[1] * 1000, p[0] ] )
        callback $.extend(slide, datapoints: datapoints)

  begin: (root, allSlides) ->
    allSeries = $.map allSlides, (slide) -> Grapple.series(slide)
    slideIndex = 0

    for series in allSeries
      $("ul.slidemarkers").append $("<li>")

    behindCurtain = (renderSlide) ->
      $(".slidemarkers li").fadeTo 500, 0.2
      $('#curtain').fadeTo 500, 1.0, () ->
        renderSlide()
        $( $(".slidemarkers li")[slideIndex] ).fadeTo 1000, 0.6
        slideIndex = ( slideIndex + 1 ) % allSeries.length
        $('#curtain').fadeTo 1000, 0.0
        $("#curtain .loading").remove()

    renderNextSlide = () ->
      console.log "Rendering slide", slideIndex
      allSeries[slideIndex] (slide) ->
        behindCurtain () ->
          $.plot root, slide.datapoints, xaxis: { mode: "time" }, colors: slide.colors
          $("h1.title").text slide.title
          $("h2.subtitle").text slide.subtitle
          timeout 5000, renderNextSlide

    renderNextSlide()

$ ->
  settings = $.get("config/grapple.json")

  settings.fail (response) ->
    console.log "Error finding or parsing grapple.json"

  settings.done (response) ->
    Grapple.begin("#placeholder", response)

  $("h1.appname").fitText(3.0)
  $("h1.title").fitText(2.0)
  $("h2.subtitle").fitText(4.0)

  $("#curtain").css
    backgroundColor: $("body").css('backgroundColor')

  $(window).resize Grapple.resize
  Grapple.resize()

  $("#curtain .loading").fitText(1.0)