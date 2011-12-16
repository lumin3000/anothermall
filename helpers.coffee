exports.helpers =
  appName: 'Anothermall_Admin'
  version: '0.1'
  nameAndVersion: (name, version) ->
    name + " v" + version


FlashMessage = (type, messages) ->
  type:type
  messages:(if typeof messages is "string" then [ messages ] else messages)
  icon: ->
    switch @type
      when "info"
        "ui-icon-info"
      when "error"
        "ui-icon-alert"
  stateClass: ->
    switch @type
      when "info"
        "ui-state-highlight"
      when "error"
        "ui-state-error"
  toHTML: ->
    "<div class=\"ui-widget flash\">" + "<div class=\"" + @stateClass() + " ui-corner-all\">" + "<p><span class=\"ui-icon " + @icon() + "\"></span>" + @messages.join(", ") + "</p>" + "</div>" + "</div>"

exports.dynamicHelpers = flashMessages: (req, res) ->
  html = ""
  [ "error", "info" ].forEach (type) ->
    messages = req.flash(type)
    html += new FlashMessage(type, messages).toHTML()  if messages.length > 0

  html