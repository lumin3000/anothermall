Item = app.Item

exports.show = (req,res)->
  Item.findOne {_id: req.params.id}, (err, d) ->
    if err
      req.flash "info", "没有这个商品"
      res.redirect "/mall/items"      
    else
      Item.findOne({_id: req.params.id}).populate('category').run (err,one)->
        d.categoryname = one.category.title
        Item.findOne({_id: req.params.id}).populate('exhibitor').run (err,one)->
          d.exhibitorname = one.exhibitor.title
          d.exhibitorimage = one.exhibitor.image_url
          d.article = JSON.parse d.data[0]
          d.id = d._id
          #d.data = (->"<div><img src=/img/#{el.image}_1.jpg /></div><div>#{el.word}</div>" for el in article)().join ''
          res.render "items/show.jade",{locals:{d: d,currentUser: req.currentUser}}
    #need some error and log process

exports.index = (req, res)->
  Item.find {},[],sort: [ "created_at", "descending" ],(err, items) ->
    items = items.map (d) ->
      title: d.title
      id: d._id
      image:d.image_url
    res.render "items/index.jade",{locals:{items: items,currentUser:req.currentUser}}
