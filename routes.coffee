routing = require "railway-routes"
mw = require "./middleware"

magic = require('imagemagick')
fs = require 'fs'
GridFS = require('GridFS').GridFS

NotFound = (msg) ->
  @name = "NotFound"
  Error.call this, msg
  Error.captureStackTrace this, arguments.callee

#site
app.get "/", mw.loadUser, (req, res) ->
  res.redirect "/mall/items" 

util.inherits NotFound, Error
app.get "/404", (req, res) ->
  throw new NotFound

app.get "/500", (req, res) ->
  throw new Error("An expected error")

app.get "/bad", (req, res) ->
  unknownMethod()

app.error (err, req, res, next) ->
  if err instanceof NotFound
    res.render "404.jade",
      status: 404
  else
    next err

if app.settings.env is "production"
  app.error (err, req, res) ->
    res.render "500.jade",
      status: 500
      locals:
        error: err

GridFS = new GridFS('anothermall_images')
Image_exhibitor_size = [36,100,180]
Image_item_size = [180,500,960]

app.get "/img/:id",(req,res)->
  imagename_mongod = req.params.id
  GridFS.get imagename_mongod,(err,filedata)->
    #res.writeHead 200, {'Content-Type': 'image/jpeg' }
    res.end filedata, 'binary'
    #fs.writeFile './tmp/'+imagename_mongod,filedata,'binary',(err)->
      #console.log "writeLocalImageFile ok~"





exports.init = (app) ->
  map = new routing.Map(app, handler)

  map.namespace "account", (account) ->
    middlewareSetting=
      middleware: mw.auth,
      middlewareExcept: ['new','create']
    account.resources "sessions",middlewareSetting
    account.resources "users",middlewareSetting

  map.namespace "mall", (mall) ->
    middlewareSetting = {middleware:mw.auth}
    mall.resources "items",{middleware:mw.loadUser}
    mall.resources "tickets",middlewareSetting
    mall.resources "carts",middlewareSetting

  #map.all "/:controller/:action"
  #map.all "/:controller/:id/:action"


handler = (ns, controller, action) ->
  try
    ctlFile = './controllers/' + ns + controller
    responseHandler =  require(ctlFile)[action]
  catch e
    console.log e
  return responseHandler || (req, res)->
    res.send('Handler not found for ' + ns + controller + '#' + action)









