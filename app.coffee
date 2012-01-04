express = require 'express'
global.app = module.exports = express.createServer();
mongoose = require("mongoose")
mongoStore = require("connect-mongodb")
mailer = require("mailer")
stylus = require("stylus")
markdown = require("markdown").markdown
connectTimeout = require("connect-timeout")
util = require("util")
path = require("path")

models = require("./models")
db = undefined
Exhibitor = undefined
Category = undefined
Item = undefined
User = undefined
Address = undefined
Ticket = undefined
LoginToken = undefined
ShoppingCart = undefined
Settings =
  development: {}
  test: {}
  production: {}

app.async = require 'async'

app.configure ->
  app.set "views", __dirname + "/views"
  app.use express.favicon()
  app.use express.bodyParser({uploadDir: '/tmp'})
  app.use express.cookieParser()
  app.use connectTimeout(time: 30000)
  app.use express.session(
    store: mongoStore(app.set("db-uri"))
    secret: "topsecret"
  )
  app.use express.logger(format: "\u001b[1m:method\u001b[0m \u001b[33m:url\u001b[0m :response-time ms")
  app.use express.methodOverride()
  app.use stylus.middleware(src: __dirname + "/public")
  app.use express.static(__dirname + "/public")
  app.set "mailOptions",
    host: "localhost"
    port: "25"
    from: "sjerrys@gmail.com"



app.configure 'development', ()->
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }))

app.configure 'production', ()->
  app.use(express.errorHandler())

app.helpers require("./helpers").helpers
app.dynamicHelpers require("./helpers").dynamicHelpers


app.configure "development", ->
  app.set "db-uri", "mongodb://localhost/anothermall-development"
  app.use express.errorHandler(dumpExceptions: true)
  app.set "view options",
    pretty: true

app.configure "test", ->
  app.set "db-uri", "mongodb://localhost/anothermall-test"
  app.set "view options",
    pretty: true

app.configure "production", ->
  app.set "db-uri", "mongodb://localhost/anothermall-production"




#load models
models.defineModels mongoose, ->
  app.Category = Category = mongoose.model "Category"
  app.Exhibitor = Exhibitor = mongoose.model "Exhibitor"
  app.Item = Item = mongoose.model "Item"
  app.User = User = mongoose.model "User"
  app.Address = Address = mongoose.model "Address"
  app.Ticket = Ticket = mongoose.model "Ticket"
  app.ShoppingCart = ShoppingCart = mongoose.model "ShoppingCart"
  app.LoginToken = LoginToken = mongoose.model "LoginToken"
  db = mongoose.connect app.set "db-uri"


require('./routes').init app




app.listen 3000
console.log "server run on port %d in %s mode", app.address().port, app.settings.env