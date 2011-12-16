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

Image_exhibitor_size = [36,180]
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
  res.render "index.jade"

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


       _  _  _           _   _  _  _  _  _  _  _  _  _  _    _  _  _       _  _  _  _    _  _  _  _    _           _    
    _ (_)(_)(_) _      _(_)_(_)(_)(_)(_)(_)(_)(_)(_)(_)(_)_ (_)(_)(_) _  _(_)(_)(_)(_)_ (_)(_)(_)(_) _(_)_       _(_)   
   (_)         (_)   _(_) (_)_    (_)      (_)           (_)         (_)(_)          (_)(_)         (_) (_)_   _(_)     
   (_)             _(_)     (_)_  (_)      (_) _  _      (_)    _  _  _ (_)          (_)(_) _  _  _ (_)   (_)_(_)       
   (_)            (_) _  _  _ (_) (_)      (_)(_)(_)     (_)   (_)(_)(_)(_)          (_)(_)(_)(_)(_)        (_)         
   (_)          _ (_)(_)(_)(_)(_) (_)      (_)           (_)         (_)(_)          (_)(_)   (_) _         (_)         
   (_) _  _  _ (_)(_)         (_) (_)      (_) _  _  _  _(_) _  _  _ (_)(_)_  _  _  _(_)(_)      (_) _      (_)         
      (_)(_)(_)   (_)         (_) (_)      (_)(_)(_)(_)(_)  (_)(_)(_)(_)  (_)(_)(_)(_)  (_)         (_)     (_)         
                                                                                                                        
                                                                                                                        
###

#list
app.get "/categorys", loadUser, (req, res) ->
  Category.find {},[],sort: [ "created_at", "descending" ],(err, categorys) ->
    categorys = categorys.map (d) ->
      title: d.title
      id: d._id
    res.render "categorys/index.jade",{locals:{categorys: categorys,currentUser:req.currentUser}}

#list in json
app.get "/categorys.:format?", loadUser, (req, res) ->
  Category.find {}, [],sort: [ "created_at", "descending" ], (err, categorys) ->
    switch req.params.format
      when "json"
        res.send categorys.map (d) ->
          d.toObject()
      else
        res.send "Format not available", 400

#the page for creating
app.get "/categorys/new", loadUser, (req, res) ->
  res.render "categorys/new.jade",{locals:{d: new Category(),currentUser:req.currentUser}}

#create 
app.post "/categorys", loadUser, (req, res) ->
  d = new Category req.body
  d.created_at = new Date()
  d.administrator = req.currentUser
  d.save ->
    req.flash "info", "创建分类成功"
    res.redirect "/categorys"

#the page for editing
app.get "/categorys/:id.:format?/edit", loadUser, (req, res, next) ->
  Category.findOne {_id: req.params.id}, (err, d) ->
    if err
      req.flash "info", "没有这个分类"
      res.redirect "/categorys"      
    else
      res.render "categorys/edit.jade",{locals:{d: d,currentUser: req.currentUser}}

#Edit
app.put "/categorys/:id.:format?", loadUser, (req, res) ->
  Category.findOne
    _id: req.params.id
  , (err, d) ->
    return next(new NotFound("Category not found"))  unless d
    d_update    = req.body
    Object.keys(d_update).forEach (key) -> d[key] = d_update[key]
    d.created_at= new Date()
    d.administrator = req.currentUser
    d.save (err) ->
      switch req.params.format
        when "json"
          res.send d.toObject()
        else
          req.flash "info", "分类编辑成功"
          res.redirect "/categorys"

#Del
app.del "/categorys/:id.:format?", loadUser, (req, res) ->
  Category.findOne {_id: req.params.id}, (err, d) ->
    return next(new NotFound("Category not found"))  unless d
    d.remove ->
      switch req.params.format
        when "json"
          res.send "true"
        else
          req.flash "info", "分类被删除"
          res.redirect "/categorys"

###

    _  _  _  _  _  _           _  _           _  _  _  _  _  _  _  _    _  _  _  _  _  _  _  _   _  _  _  _    _  _  _  _       
   (_)(_)(_)(_)(_)(_)_       _(_)(_)         (_)(_)(_)(_)(_)(_)(_)(_) _(_)(_)(_)(_)(_)(_)(_)(_)_(_)(_)(_)(_)_ (_)(_)(_)(_) _    
   (_)              (_)_   _(_)  (_)         (_)   (_)    (_)        (_)  (_)         (_)     (_)          (_)(_)         (_)   
   (_) _  _           (_)_(_)    (_) _  _  _ (_)   (_)    (_) _  _  _(_)  (_)         (_)     (_)          (_)(_) _  _  _ (_)   
   (_)(_)(_)           _(_)_     (_)(_)(_)(_)(_)   (_)    (_)(_)(_)(_)_   (_)         (_)     (_)          (_)(_)(_)(_)(_)      
   (_)               _(_) (_)_   (_)         (_)   (_)    (_)        (_)  (_)         (_)     (_)          (_)(_)   (_) _       
   (_) _  _  _  _  _(_)     (_)_ (_)         (_) _ (_) _  (_)_  _  _ (_)_ (_) _       (_)     (_)_  _  _  _(_)(_)      (_) _    
   (_)(_)(_)(_)(_)(_)         (_)(_)         (_)(_)(_)(_)(_)(_)(_)(_)  (_)(_)(_)      (_)       (_)(_)(_)(_)  (_)         (_)   
                                                                                                                                
                                                                                                                              
###

#list
app.get "/exhibitors", loadUser, (req, res) ->
  Exhibitor.find {},[],sort: [ "created_at", "descending" ],(err, exhibitors) ->
    exhibitors = exhibitors.map (d) ->
      title: d.title
      id: d._id
    res.render "exhibitors/index.jade",{locals:{exhibitors: exhibitors,currentUser:req.currentUser}}

#list in json
app.get "/exhibitors.:format?", loadUser, (req, res) ->
  Exhibitor.find {}, [],sort: [ "pinyin", "descending" ], (err, exhibitors) ->
    switch req.params.format
      when "json"
        res.send exhibitors.map (d) ->
          d.toObject()
      else
        res.send "Format not available", 400


#the page for exhibitor creating
app.get "/exhibitors/new", loadUser, (req, res) ->
  res.render "exhibitors/new.jade",{locals:{d: new Exhibitor(),currentUser:req.currentUser}}     


#Create
app.post "/exhibitors", loadUser, (req, res) ->
  d = new Exhibitor req.body
  d.created_at = new Date()
  d.administrator = req.currentUser
  d.pinyin = pinyin.full d.title
  d.pinyin_short = pinyin.short d.title
  d.save ->
    req.flash "info", "创建展出人成功"
    res.redirect "/exhibitors"

  
#the page for editing
app.get "/exhibitors/:id.:format?/edit", loadUser, (req, res) ->
  Exhibitor.findOne {_id: req.params.id}, (err, d) ->
    if err
      req.flash "info", "没有这个展出人"
      res.redirect "/exhibitors"      
    else
      res.render "exhibitors/edit.jade",{locals:{d: d,currentUser: req.currentUser}}


#Edit
app.put "/exhibitors/:id.:format?", loadUser, (req, res, next) ->
  Exhibitor.findOne
    _id: req.params.id
  , (err, d) ->
    return next(new NotFound("Exhibitor not found"))  unless d
    d_update    = req.body
    Object.keys(d_update).forEach (key) -> d[key] = d_update[key]
    d.created_at= new Date()
    d.administrator = req.currentUser
    d.save (err) ->
      switch req.params.format
        when "json"
          res.send d.toObject()
        else
          req.flash "info", "展出人编辑成功"
          res.redirect "/exhibitors"


#Del
app.del "/exhibitors/:id.:format?", loadUser, (req, res, next) ->
  Exhibitor.findOne {_id: req.params.id}, (err, d) ->
    return next(new NotFound("exhibitor not found"))  unless d
    d.remove ->
      switch req.params.format
        when "json"
          res.send "true"
        else
          req.flash "info", "展出人被删除"
          res.redirect "/exhibitors"


#create new exhibitor avatar
app.post "/exhibitors/image", (req, res) ->
  file = req.body.image.path
  imagename_mongod = file.replace('/tmp/','e_')+parseInt(Math.random()*10000)
  saveAvatar file,imagename_mongod, ->
    res.redirect "/exhibitors/image/#{imagename_mongod}"



#the page for exhibitor avatar creating and editing
app.get "/exhibitors/image/:id", (req, res)->
  d = {action:"/exhibitors/image"}
  d.image = req.params.id if parseInt(req.params.id)!=0
  res.render 'image/edit.jade',
    locals:{d:d}
    layout:false 

#Read, we dont need read, so redirect to edit
app.get "/exhibitors/:id.:format?", loadUser, (req, res) ->
  res.redirect "/exhibitors/#{req.params.id}/edit"


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

#the page for creating
app.get "/items/new", loadUser, (req, res) ->
  res.render "items/new.jade",{locals:{d: new Item(),currentUser:req.currentUser}}

#create 
app.post "/items", loadUser, (req, res) ->
  d = new Item req.body
  d.created_at = new Date()
  d.administrator = req.currentUser
  d.data = d.data[0]
  tmp_data = JSON.parse(d.data)[0]
  d.summary = tmp_data.word
  d.image_url = tmp_data.image
  #res.send "ok:"+JSON.stringify(d), 200
  d.save ->
    req.flash "info", "创建商品成功"
    res.redirect "/items"

#the page for editing
app.get "/items/:id.:format?/edit", loadUser, (req, res, next) ->
  Item.findOne {_id: req.params.id}, (err, d) ->
    if err
      req.flash "info", "没有这个商品"
      res.redirect "/items"      
    else
      Item.findOne({_id: req.params.id}).populate('category').run (err,one)->
        d.categoryname = one.category[0].title if !err && one.category[0].title
        Item.findOne({_id: req.params.id}).populate('exhibitor').run (err,one)->
          d.exhibitorname = one.exhibitor[0].title if !err && one.exhibitor[0].title
          res.render "items/edit.jade",{locals:{d: d,currentUser: req.currentUser}}

#Edit
app.put "/items/:id.:format?", loadUser, (req, res) ->
  Item.findOne
    _id: req.params.id
  , (err, d) ->
    return next(new NotFound("Item not found"))  unless d
    d_update    = req.body
    Object.keys(d_update).forEach (key) -> d[key] = d_update[key]
    d.created_at= new Date()
    d.administrator = req.currentUser
    d.data = d.data[0]
    tmp_data = JSON.parse(d.data)[0]
    d.summary = tmp_data.word
    d.image_url = tmp_data.image
    d.save (err) ->
      switch req.params.format
        when "json"
          res.send d.toObject()
        else
          req.flash "info", "商品编辑成功"
          res.redirect "/items"

#Del
app.del "/items/:id.:format?", loadUser, (req, res) ->
  Item.findOne {_id: req.params.id}, (err, d) ->
    return next(new NotFound("Item not found"))  unless d
    d.remove ->
      switch req.params.format
        when "json"
          res.send "true"
        else
          req.flash "info", "商品被删除"
          res.redirect "/items"

#create new item photo
app.post "/items/image", (req, res) ->
  file = req.body.image.path
  imagename_mongod = file.replace('/tmp/','i_')+parseInt(Math.random()*10000)
  saveItemPicture file,imagename_mongod, ->
    res.redirect "/items/image/#{imagename_mongod}"

#the page for item photo creating and editing
app.get "/items/image/:id", (req, res)->
  d = {action:"/items/image"}
  d.image = req.params.id if parseInt(req.params.id)!=0
  res.render 'image/edit.jade',
    locals:{d:d}
    layout:false 


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