crypto = require("crypto")
Ticket = undefined
Item = undefined
Administrator = undefined
LoginToken = undefined
Category = undefined
Address = undefined
LogReference = undefined

extractKeywords = (text) ->
  return []  unless text
  #text.join('/r/n')+'' if text.push
  if text.push
    trry = []
    for i in text
      trry.push(i) if typeof(i)=='string'
    trry=trry.join('/r/n')
  else
    trry = text

  trry.split(/\s+/).filter((v) ->
    v.length > 2
  ).filter (v, i, a) ->
    a.lastIndexOf(v) is i

defineModels = (mongoose, fn) ->
  validatePresenceOf = (value) ->
    value and value.length
  Schema = mongoose.Schema
  ObjectId = Schema.ObjectId

  Ticket = new Schema
    user:[{ type: ObjectId, ref: 'User' }]
    created_at:
      type:Date
      index:true
    delivery_processing:
      type:Boolean
      default:true
      index:true
    pay_ref_url:String
    item: [{ type: ObjectId, ref: 'Item' }]
    exhibitor:[{ type: ObjectId, ref: 'Exhibitor' }]
    delivery_at:Date

  Ticket.pre "save", (next) ->
    #auto change delivery status by delivery_at
    @delivery_processing = false if @delivery_at
    next()

  Ticket.virtual("id").get ->
    @_id.toHexString()



  Category = new Schema
    title:String
    created_at:Date
    administrator: [{ type: ObjectId, ref: 'Administrator' }]

  Category.virtual("id").get ->
    @_id.toHexString()
  
  Category.pre "save", (next) ->
    @title = @title.trim()
    next()

  Exhibitor = new Schema
    created_at:
      type:Date
      index:true
    title:
      type:String
      index:true
    pinyin_short:
      type:String
      index:true
    pinyin:String
    summary:String
    image_url:String
    web_url:String
    administrator: [{ type: ObjectId, ref: 'Administrator' }]
    user:[{ type: ObjectId, ref: 'User' }]

  Exhibitor.virtual("id").get ->
    @_id.toHexString()
  
  Exhibitor.pre "save", (next) ->
    @title = @title.trim()
    @summary = @summary.trim()
    @web_url = @web_url.trim() if @web_url
    next()

  Item = new Schema
    created_at:
      type:Date
      index:true
    sold:
      type:Boolean
      default:false
      index:true 
    category:
      type:[{ type: ObjectId, ref: 'Category' }]
      index:true
    exhibitor:
      type:[{ type: ObjectId, ref: 'Exhibitor' }]
      index:true
    price: 
      type:Number
      min:0
    title:String
    image_url:String
    summary:String
    data: [ String ]
    size:String
    delivery:String
    update_at:Date
    sold_at:Date
    keywords: [ String ]
    administrator: [{ type: ObjectId, ref: 'Administrator' }]
    pay_url:String
    pay_processing:
      type:Boolean
      default:false
    pay_at:Date
    ticket:ObjectId

  Item.virtual("id").get ->
    @_id.toHexString()

  Item.pre "save", (next) ->
    #auto make a keywords for search
    #@keywords = extractKeywords(@data)
    #auto change sold status by pay_processing
    @sold = true if (@pay_processing == true || @pay_at)
    @sold = false if (@pay_processing == false && !@pay_at)
    #trim
    @title = @title.trim()
    @summary = @summary.trim() if @summary
    #@data = @data.trim()
    @size = @size.trim() if @size
    @delivery = @delivery.trim() if @delivery
    next()

  Administrator = new Schema
    email:
      type: String
      validate: [ validatePresenceOf, "an email is required" ]
      index:
        unique: true
    hashed_password: String
    salt: String

  Administrator.virtual("id").get ->
    @_id.toHexString()

  Administrator.virtual("password").set((password) ->
    @_password = password
    @salt = @makeSalt()
    @hashed_password = @encryptPassword(password)
  ).get ->
    @_password

  Administrator.method "authenticate", (plainText) ->
    @encryptPassword(plainText) is @hashed_password

  Administrator.method "makeSalt", ->
    Math.round((new Date().valueOf() * Math.random())) + ""

  Administrator.method "encryptPassword", (password) ->
    crypto.createHmac("sha1", @salt).update(password).digest "hex"

  Administrator.pre "save", (next) ->
    unless validatePresenceOf(@password)
      next new Error("Invalid password")
    else
      next()

  Address = new Schema
    user:[{ type: ObjectId, ref: 'User' }]
    name:String
    area:String
    street:String
    zipcode: Number
    phone: Number

  Address.virtual("id").get ->
    @_id.toHexString()

  Invoice = new Schema
    user:[{ type: ObjectId, ref: 'User' }]
    title:String
    content:String
    name:String
    area:String
    street:String
    zipcode: Number
    phone: Number

  Invoice.virtual("id").get ->
    @_id.toHexString()


  LogReference = new Schema
    user:[{ type: ObjectId, ref: 'User' }]
    ip:String
    created_at:Date


  User = new Schema
    name: String
    email:
      type: String
      validate: [ validatePresenceOf, "an email is required" ]
      index:{unique: true}
    forbidden:
      type:Boolean
      default:false
    hashed_password: String
    salt: String
    created_at:Date
    exhibitor:[{ type: ObjectId, ref: 'Exhibitor' }]
    ticket:[{ type: ObjectId, ref: 'Ticket' }]
    Log_reference:{ type: ObjectId, ref: 'LogReference' }]
    address:[{ type: ObjectId, ref: 'Address' }]


  User.virtual("id").get ->
    @_id.toHexString()

  User.virtual("password").set((password) ->
    @_password = password
    @salt = @makeSalt()
    @hashed_password = @encryptPassword(password)
  ).get ->
    @_password

  User.method "authenticate", (plainText) ->
    @encryptPassword(plainText) is @hashed_password

  User.method "makeSalt", ->
    Math.round((new Date().valueOf() * Math.random())) + ""

  User.method "encryptPassword", (password) ->
    crypto.createHmac("sha1", @salt).update(password).digest "hex"

  User.pre "save", (next) ->
    unless validatePresenceOf(@password)
      next new Error("Invalid password")
    else
      next()



  LoginToken = new Schema
    email:
      type: String
      index: true
    series:
      type: String
      index: true
    token:
      type: String
      index: true

  LoginToken.method "randomToken", ->
    Math.round((new Date().valueOf() * Math.random())) + ""

  LoginToken.pre "save", (next) ->
    @token = @randomToken()
    @series = @randomToken()  if @isNew
    next()

  LoginToken.virtual("id").get ->
    @_id.toHexString()

  LoginToken.virtual("cookieValue").get ->
    JSON.stringify
      email: @email
      token: @token
      series: @series
  
  mongoose.model "Category", Category
  mongoose.model "Ticket", Ticket
  mongoose.model "Exhibitor", Exhibitor
  mongoose.model "Item", Item
  mongoose.model "Address", Address
  mongoose.model "LogReference", LogReference
  mongoose.model "User", User
  mongoose.model "LoginToken", LoginToken
  fn()

exports.defineModels = defineModels