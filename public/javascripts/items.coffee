#helper
$ = jQuery
request = superagent
Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) >= 0

modelSelector = (model)->
  dom = $ ".#{model}"
  button = $ "##{model}_selecter"
  popup = $ "##{model}_dialog"
  data = false

  render = ()->
    html=[]
    for i in [0..data.length-1]
      e = data[i]
      img = if e.image_url then "<img src=/img/#{e.image_url}_0.jpg><br />" else ""
      html.push ["<li class=ui-state-default _id=#{e._id} title=\"#{e.title}\">"
      ,"#{img}#{e.title}"
      ,"</li>"].join ''
    html = ["<div id=selected class=hidden><span id=selected_title></span> <span id=selected_closed>确定为#{model}？</span></div>"
    ,"<ol id=selectable>#{html.join('')}</ol>"].join ''
    #render html
    popup.dialog('widget').find('.ui-widget-content').html html
    $('#selected_closed').click ()->popup.dialog 'close'
    #selectable render & config
    selector = $ '#selectable'
    selector.selectable()
    selector.bind "selectableselected", (event,ui)->
      selected = $ ui.selected
      dom.val selected.attr '_id'
      $('#selected_title').html selected.attr 'title'
      $('#selected').removeClass 'hidden'
      button.html selected.attr 'title'
      #hidden dialog's close button when selectableselected
      $('.ui-icon-closethick').addClass 'hidden'

  next =  
    init:()->
      # load data from template(server)
      $("##{model}_selecter").html $(".#{model}name").val() if $(".#{model}name").val()!=''
      button.click ()->
        #render dialog
        popup.dialog { modal: true,width:800,closeText:'取消',position:'top'}
        popup.bind "dialogclose",()->
          popup.dialog('widget').find('.ui-widget-content').html ''
          popup.dialog 'destroy'
        #getdata
        if data #Is data loaded from server
          render()
        else
          request.get "/#{model}s.json", {},(res)->
            data = res.body
            if data.length && data.length>0 #Is data from server empty?
              render()
            else
              popup.dialog('widget').find('.ui-widget-content').html "<h2>没有#{model}信息？</h2>"


(new modelSelector(modelName)).init() for modelName in ['exhibitor','category']


class Item extends Spine.Model
  @configure "Item", "title", "category","exhibitor","price","size","delivery"
  #@hasMany 'descriptions', 'models/description'

class Description extends Spine.Model
  @configure "Description", "image", "word"
  #@belongsTo 'item', 'Item'

class Descriptions extends Spine.Controller
  events:
    "click span": "remove"
    "blur  textarea":     "edit"

  elements:
    "textarea": "input"

  constructor: ->
    super
    @item.bind("destroy", @release)
  
  edit: ->
    @item.updateAttributes {word: @input.val()}

  render: =>
    codey = ->
      li '.data_input_dom', title:@image, ->
        img src:"/img/#{@image}_1.jpg"
        textarea '#data_words', -> @word
        span -> "移除这条描述"
    @html(CoffeeKup.render(codey,@item))
    @
  
  remove: ->
    @item.destroy()

class App extends Spine.Controller
  sortableRunning:false
  elements:
    "#data_input_area":     "descriptions"
    ".data":     "descriptionJson"
  
  constructor: ->
    super
    Description.bind("create",  @addOne)
    Description.bind("refresh", @addAll)
    @checkDataServer()

  addOne: (description) =>
    view = new Descriptions {item: description}
    @descriptions.append view.render().el
    if !@sortableRunning
      @sortable()
    else
      @descriptions.sortable "refresh"
    
  addAll: =>
    Description.each @addOne

  createDescription: (imageid) ->
    Description.create {image:imageid,word:''}

  sortable: ->
    @sortableRunning = true
    @descriptions.sortable 
      revert: true
      snap:true
      axis:'y'
      grid:[50,50]
      containment:'parent'
      iframeFix: true
    @descriptions.bind 'sortupdate',()->
    $( "ul, li" ).disableSelection()

  renderDataHIdden: ->
    #correct the description order as sorted
    json = []
    for i in $('.data_input_dom')
      json.push Description.findByAttribute 'image',i.title
    @descriptionJson.val JSON.stringify json
  
  checkDataServer: ->
    #get data from template(server)
    dataServer = @descriptionJson.val()
    Description.refresh dataServer if dataServer!=''





top.app = new App {el: $("form")}
top.imageSrcholder= (img)->app.createDescription(img)

top.beforeSubmit = (form)->
  top.form = form
  app.renderDataHIdden()
  if form.data.value==''
    flashError "描述不可以是空的哦"
    return false
  if form.title.value==''
    flashError "名称不可以是空的哦"
    return false

  if form.price.value==''
    flashError "价格不可以是空的哦"
    return false

  if form.exhibitor.value ==''
    flashError "展出人不可以是空的哦"
    return false
  
  return true






