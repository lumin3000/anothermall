express = require("express")
connect = require("connect")
jade = require("jade")
app = module.exports = express.createServer()
mongoose = require("mongoose")
mongoStore = require("connect-mongodb")
mailer = require("mailer")
stylus = require("stylus")
markdown = require("markdown").markdown
connectTimeout = require("connect-timeout")
util = require("util")
path = require("path")
models = require("./models")
pinyin = require("./pinyin")
magic = require('imagemagick')
fs = require 'fs'
GridFS = require('GridFS').GridFS
db = undefined
Exhibitor = undefined
Category = undefined
Item = undefined
User = undefined
LoginToken = undefined
Settings =
  development: {}
  test: {}
  production: {}

renderJadeFile = (template, options) ->
  fn = jade.compile(template, options)
  fn options.locals

emails =
  send: (template, mailOptions, templateOptions) ->
    mailOptions.to = mailOptions.to
    renderJadeFile path.join(__dirname, "views", "mailer", template), templateOptions, (err, text) ->
      mailOptions.body = text
      keys = Object.keys(app.set("mailOptions"))
      k = undefined
      i = 0
      len = keys.length

      while i < len
        k = keys[i]
        mailOptions[k] = app.set("mailOptions")[k]  unless mailOptions.hasOwnProperty(k)
        i++
      console.log "[SENDING MAIL]", util.inspect(mailOptions)
      if app.settings.env is "production"
        mailer.send mailOptions, (err, result) ->
          console.log err  if err

  sendWelcome: (user) ->
    @send "welcome.jade",
      to: user.email
      subject: "Welcome to AnotherMall"
    ,
      locals:
        user: user


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

GridFS = new GridFS('anothermall_images')

Image_exhibitor_size = [36,100,180]
Image_item_size = [180,500,960]

#load models
models.defineModels mongoose, ->
  app.Category = Category = mongoose.model "Category"
  app.Exhibitor = Exhibitor = mongoose.model "Exhibitor"
  app.Item = Item = mongoose.model "Item"
  app.User = User = mongoose.model "User"
  app.LoginToken = LoginToken = mongoose.model "LoginToken"
  db = mongoose.connect app.set "db-uri"


#auth
authenticateFromLoginToken = (req, res, next) ->
  cookie = JSON.parse(req.cookies.logintoken)
  LoginToken.findOne
    email: cookie.email
    series: cookie.series
    token: cookie.token
  , ((err, token) ->
    unless token
      res.redirect "/sessions/new"
      return
    User.findOne
      email: token.email
    , (err, user) ->
      if user
        req.session.user_id = user.id
        req.currentUser = user
        token.token = token.randomToken()
        token.save ->
          res.cookie "logintoken", token.cookieValue,
            expires: new Date(Date.now() + 2 * 604800000)
            path: "/"

          next()
      else
        res.redirect "/sessions/new"
  )
loadUser = (req, res, next) ->
  if req.session.user_id
    User.findById req.session.user_id, (err, user) ->
      if user
        req.currentUser = user
        next()
      else
        res.redirect "/sessions/new"
  else if req.cookies.logintoken
    authenticateFromLoginToken req, res, next
  else
    res.redirect "/sessions/new"
NotFound = (msg) ->
  @name = "NotFound"
  Error.call this, msg
  Error.captureStackTrace this, arguments.callee


#helper
saveItemPicture = (file,imagename_mongod,next)->
  saveImage file,imagename_mongod,Image_item_size,next

saveAvatar = (file,imagename_mongod,next)->
  saveImage file,imagename_mongod,Image_exhibitor_size,next

saveImage = (file,imagename_mongod,sizeArray,next)->
  sizeArray.forEach (el,idx)->
    tempFile = "#{file}_#{idx}"
    magic.resize {srcPath:file,dstPath:tempFile,quality:0.9,width:el},(err)->
      fs.readFile (tempFile),(err,buffer)->
        GridFS.put buffer,("#{imagename_mongod}_#{idx}.jpg"),'w',(err,r)->
          fs.unlink (tempFile), ->
            fs.unlink(file,next) if idx == sizeArray.length-1


#site
app.get "/", loadUser, (req, res) ->
  res.redirect "/items" 

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


app.get "/img/:id",(req,res)->
  imagename_mongod = req.params.id
  GridFS.get imagename_mongod,(err,filedata)->
    #res.writeHead 200, {'Content-Type': 'image/jpeg' }
    res.end filedata, 'binary'
    #fs.writeFile './tmp/'+imagename_mongod,filedata,'binary',(err)->
      #console.log "writeLocalImageFile ok~"


###

       _  _  _  _  _  _  _  _  _  _  _  _  _  _           _    
      (_)(_)(_)(_)(_)(_)(_)(_)(_)(_)(_)(_)(_)(_) _     _ (_)   
         (_)         (_)      (_)            (_)(_)   (_)(_)   
         (_)         (_)      (_) _  _       (_) (_)_(_) (_)   
         (_)         (_)      (_)(_)(_)      (_)   (_)   (_)   
         (_)         (_)      (_)            (_)         (_)   
       _ (_) _       (_)      (_) _  _  _  _ (_)         (_)   
      (_)(_)(_)      (_)      (_)(_)(_)(_)(_)(_)         (_)   
                                                               
                                                               
###

#list
app.get "/items", loadUser, (req, res) ->
  Item.find {},[],sort: [ "created_at", "descending" ],(err, items) ->
    items = items.map (d) ->
      title: d.title
      id: d._id
      image:d.image_url
    res.render "items/index.jade",{locals:{items: items,currentUser:req.currentUser}}

#list in json
app.get "/items.:format?", loadUser, (req, res) ->
  Item.find {}, [],sort: [ "created_at", "descending" ], (err, items) ->
    switch req.params.format
      when "json"
        res.send items.map (d) ->
          d.toObject()
      else
        res.send "Format not available", 400

#Read, we dont need read, so redirect to edit
app.get "/items/:id.:format?", loadUser, (req, res) ->
  Item.findOne {_id: req.params.id}, (err, d) ->
    if err
      req.flash "info", "没有这个商品"
      res.redirect "/items"      
    else
      Item.findOne({_id: req.params.id}).populate('category').run (err,one)->
        d.categoryname = one.category[0].title
        Item.findOne({_id: req.params.id}).populate('exhibitor').run (err,one)->
          d.exhibitorname = one.exhibitor[0].title
          d.exhibitorimage = one.exhibitor[0].image_url
          d.article = JSON.parse d.data[0]
          #d.data = (->"<div><img src=/img/#{el.image}_1.jpg /></div><div>#{el.word}</div>" for el in article)().join ''
          res.render "items/show.jade",{locals:{d: d,currentUser: req.currentUser}}
    #need some error and log process



###

    _            _    _  _  _  _    _  _  _  _  _  _  _  _  _       
   (_)          (_) _(_)(_)(_)(_)_ (_)(_)(_)(_)(_)(_)(_)(_)(_) _    
   (_)          (_)(_)          (_)(_)            (_)         (_)   
   (_)          (_)(_)_  _  _  _   (_) _  _       (_) _  _  _ (_)   
   (_)          (_)  (_)(_)(_)(_)_ (_)(_)(_)      (_)(_)(_)(_)      
   (_)          (_) _           (_)(_)            (_)   (_) _       
   (_)_  _  _  _(_)(_)_  _  _  _(_)(_) _  _  _  _ (_)      (_) _    
     (_)(_)(_)(_)    (_)(_)(_)(_)  (_)(_)(_)(_)(_)(_)         (_)   
                                                                    

###

app.get "/users/new", (req, res) ->
  res.render "users/new.jade",
    locals:
      user: new User()

app.post "/users.:format?", (req, res) ->
  userSaveFailed = ->
    req.flash "error", "Account creation failed"
    res.render "users/new.jade",
      locals:
        user: user
  user = new User(req.body.user)
  user.save (err) ->
    return userSaveFailed()  if err
    req.flash "info", "帐户创建成功。"
    emails.sendWelcome user
    switch req.params.format
      when "json"
        res.send user.toObject()
      else
        req.session.user_id = user.id
        res.redirect "/"

#sessions

app.get "/sessions/new", (req, res) ->
  res.render "sessions/new.jade",
    locals:
      user: new User()

app.post "/sessions", (req, res) ->
  User.findOne
    email: req.body.user.email
  , (err, user) ->
    if user and user.authenticate(req.body.user.password)
      req.session.user_id = user.id
      if req.body.remember_me
        loginToken = new LoginToken(email: user.email)
        loginToken.save ->
          res.cookie "logintoken", loginToken.cookieValue,
            expires: new Date(Date.now() + 2 * 604800000)
            path: "/"

          res.redirect "/"
      else
        res.redirect "/"
    else
      req.flash "error", "Incorrect credentials"
      res.redirect "/sessions/new"

app.del "/sessions", loadUser, (req, res) ->
  if req.session
    LoginToken.remove
      email: req.currentUser.email
    , ->

    res.clearCookie "logintoken"
    req.session.destroy ->
  res.redirect "/sessions/new"

###

    _(_)(_)(_)(_)_ (_)(_)(_)(_)(_)     _(_)_     (_)(_)(_)(_) _  _ (_)(_)(_) _ (_)         (_)   
   (_)          (_)(_)               _(_) (_)_   (_)         (_)(_)         (_)(_)         (_)   
   (_)_  _  _  _   (_) _  _        _(_)     (_)_ (_) _  _  _ (_)(_)            (_) _  _  _ (_)   
     (_)(_)(_)(_)_ (_)(_)(_)      (_) _  _  _ (_)(_)(_)(_)(_)   (_)            (_)(_)(_)(_)(_)   
    _           (_)(_)            (_)(_)(_)(_)(_)(_)   (_) _    (_)          _ (_)         (_)   
   (_)_  _  _  _(_)(_) _  _  _  _ (_)         (_)(_)      (_) _ (_) _  _  _ (_)(_)         (_)   
     (_)(_)(_)(_)  (_)(_)(_)(_)(_)(_)         (_)(_)         (_)   (_)(_)(_)   (_)         (_)   
                                                                                                 

###
app.post "/search.:format?", loadUser, (req, res) ->
  Item.find
    keywords: req.body.s
  , (err, items) ->
    console.log items
    console.log err
    switch req.params.format
      when "json"
        res.send items.map((d) ->
          title: d.title
          id: d._id
        )
      else
        res.send "Format not available", 400

#unless module.parent
app.listen 3000
console.log "Express server listening on port %d, environment: %s", app.address().port, app.settings.env
console.log "Using connect %s, Express %s, Jade %s", connect.version, express.version, jade.version