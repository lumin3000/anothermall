crypto = require "crypto"
User = undefined

defineModels = (mongoose, fn) ->
  validatePresenceOf = (value) ->
    value and value.length
  Schema = mongoose.Schema
  ObjectId = Schema.ObjectId
    
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
    exhibitor:{ type: ObjectId, ref: 'Exhibitor' }
    ticket:[{ type: ObjectId, ref: 'Ticket' }]
    Log_reference:{ type: ObjectId, ref: 'LogReference' }
    address:{ type: ObjectId, ref: 'Address' }
    ShoppingCart:{type: ObjectId, ref: 'ShoppingCart' }


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

  mongoose.model "User", User

  fn()
