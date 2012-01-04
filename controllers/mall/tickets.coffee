User = app.User
Ticket = app.Ticket
ShoppingCart = app.ShoppingCart


exports.index = (req, res)->
  Ticket.find {user:new User({_id:req.currentUser.id})},[],sort: [ "created_at", "descending" ],(err, tickets) ->
      tickets = tickets.map (d) ->
        title: d.title.join('<br />')
        id: d._id
        image:d.image_url[0]
      res.render "tickets/index.jade",{locals:{tickets: tickets,currentUser:req.currentUser}}

exports.create = (req, res)->
  itemEmpty = false
  d = new Ticket()
  d.created_at = new Date()
  d.user = req.currentUser.id
  ['item','title','image_url','price','totalprice'
  ,'address_name','address_area','address_street','address_phone'].forEach (el)->
    if !req.body[el] || req.body[el].length==0
      itemEmpty = true
    else
      d[el] = req.body[el]
  if itemEmpty
    req.flash "info", "err"
    res.redirect "back" 
  else
    d.address_zipcode = req.body.address_zipcode || ''
    d.save ->
      ShoppingCart.remove req.currentUser.id, (err, cart) ->
        req.flash "info", "恭喜你，订单已经提交。"
        res.redirect "/mall/tickets"

exports.show = (req, res)->
  Ticket.findOne {_id: req.params.id}, (err, d) ->
    if err
      req.flash "info", "没有这个商品"
      res.redirect "/mall/tickets"      
    else
      res.render "tickets/show.jade",{locals:{d: d,currentUser: req.currentUser}}


