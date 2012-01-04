Item = app.Item
ShoppingCart = app.ShoppingCart
Address = app.Address

exports.index = (req,res)->
  currentUserId = {user:req.currentUser.id}
  ShoppingCart.findOne currentUserId, (err, cart) ->
    if !cart || cart.item.length==0
          req.flash "info", "购物车里没有任何商品"
          res.render "tickets/new.jade",{locals:{items:false}}
    else
      Item.find {_id:{$in:cart.item}},(err, items) ->
        Address.findOne {user:req.currentUser},(err,address)->
          address = new Address() if !address
          res.render "tickets/new.jade",locals:
            currentUser:req.currentUser
            items:items
            address:address

#new
exports.edit = (req, res)->
  Item.findOne {_id: req.params.id}, (err, item) ->
    if err
      req.flash "info", "没有这个商品"
      res.redirect "/mall/items"
    else
      currentUserId = {user:req.currentUser.id}
      ShoppingCart.findOne currentUserId, (err, cart) ->
        cart = new ShoppingCart currentUserId  if !cart
        cart.created_at = new Date()
        cart.item.push item._id if cart.item.indexOf(item._id)<0
        cart.save (err)->
          Item.find {_id:{$in:cart.item}},(err, items) ->
            Address.findOne {user:req.currentUser},(err,address)->
              address = new Address() if !address
              res.render "tickets/new.jade",locals:
                currentUser:req.currentUser
                items:items
                address:address

#del
exports.show = (req,res)->
  ShoppingCart.findOne {user:req.currentUser.id}, (err, cart) ->
    if !cart
      res.redirect "/mall/carts"
    else
      itemIndex = cart.item.indexOf req.params.id
      if itemIndex>=0
        cart.item.splice itemIndex,1
        cart.save (err)->res.redirect "/mall/carts"
      else
        res.redirect "/mall/carts"

