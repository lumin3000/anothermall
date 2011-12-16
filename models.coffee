crypto = require("crypto")
Ticket = undefined
Item = undefined
Administrator = undefined
LoginToken = undefined
Category = undefined

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

  Exhibitor.virtual("id").get ->
    @_id.toHexString()
  
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



  User = new Schema
    email:
      type: String
      validate: [ validatePresenceOf, "an email is required" ]
      index:
        unique: true
    hashed_password: String
    salt: String
    exhibitor:[{ type: ObjectId, ref: 'Exhibitor' }]
    black:
      type:Boolean
      default:false
    

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

  ###
  mongoose.model "Administrator", Administrator
  ###
  mongoose.model "Category", Category
  mongoose.model "Exhibitor", Exhibitor
  mongoose.model "Ticket", Ticket
  mongoose.model "Item", Item
  mongoose.model "User", LoginToken
  mongoose.model "LoginToken", LoginToken
  fn()

exports.defineModels = defineModels