User = app.User
Address = app.Address

#edit
exports.index = (req, res)->
  Address.findOne {user:req.currentUser},(err,address)->
    console.log "address:"+address
    address = new Address() if !address
    res.render "users/edit.jade",
      locals:
        user: req.currentUser
        address:address


exports.new = (req, res)->
  res.render "users/new.jade",
    locals:
      user: new User()


exports.create = (req, res)->
  userSaveFailed = ->
    req.flash "error", "Account creation failed"
    res.render "users/new.jade",
      locals:
        user: user
  user = new User(req.body.user)
  user.save (err) ->
    return userSaveFailed()  if err
    req.flash "info", "帐户创建成功。"
    #emails.sendWelcome user
    req.session.user_id = user.id
    res.redirect "/"


exports.update = (req, res)->
  accoutUserEdit = (next)->next()
  accountAddressEdit = (next)->next()
  address = ''
  ['email','password','name'].forEach (el)->
    if req.body.user[el]!='' && req.currentUser[el] != req.body.user[el]
      req.currentUser[el] = req.body.user[el]
      accoutUserEdit = (next)->req.currentUser.save next
  Address.findOne {user:req.currentUser},(err,address)->
    address = new Address() if !address
    ['name','area','street','phone','zipcode'].forEach (el)->
      if req.body.address[el]!='' && address[el] != req.body.address[el]
        address[el] = req.body.address[el]
        accountAddressEdit = (next)->
          address.user = req.currentUser
          address.save next
    app.async.series [
      accoutUserEdit,
      accountAddressEdit,
      ()->
        req.flash "info", "帐户信息修改成功。"
        res.render "users/edit.jade",{locals:{user: req.currentUser,address:req.body.address}}
    ]


