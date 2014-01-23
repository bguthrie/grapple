express = require 'express'
user = require './routes/user'
http = require 'http'
path = require 'path'
request = require 'request'

app = express()

app.configure ->
  app.set 'port', process.env.PORT || 3456
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(path.join(__dirname, 'public'))

app.configure 'development', () ->
  app.use express.errorHandler()

app.get '/', (req, res) ->
  res.render 'index'

app.get '/proxy', (req, res) ->
  url = req.query.url
  delete req.query.url
  request(uri: url, qs: req.query).pipe(res)

http.createServer(app).listen app.get('port'), ->
  console.log "Express server listening on port #{app.get('port')}"
