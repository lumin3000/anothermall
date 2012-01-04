User = app.User
LoginToken = app.LoginToken

#auth
authenticateFromLoginToken = (req, res, next) ->
  cookie = JSON.parse(req.cookies.userlogintoken)
  LoginToken.findOne
    email: cookie.email
    series: cookie.series
    token: cookie.token
  , (err, token) ->
    unless token
      res.redirect "/account/sessions/new"
      return
    User.findOne
      email: token.email
    , (err, user) ->
      if user
        req.session.user_id = user.id
        req.currentUser = user
        token.token = token.randomToken()
        token.save ->
          res.cookie "userlogintoken", token.cookieValue,
            expires: new Date(Date.now() + 2 * 604800000)
            path: "/"

          next()
      else
        res.redirect "/account/sessions/new"

exports.auth = auth = (req, res, next) ->
  if req.session.user_id
    User.findById req.session.user_id, (err, user) ->
      if user
        req.currentUser = user
        process.nextTick next
      else
        res.redirect "/account/sessions/new"
  else if req.cookies.userlogintoken
    authenticateFromLoginToken req, res, next
  else
    res.redirect "/account/sessions/new"

exports.loadUser = loadUser =(req, res, next) ->
  nexted = false
  if req.session.user_id
    User.findById req.session.user_id, (err, user) ->
      if user
        console.log "User.findById:"+nexted
        req.currentUser = user
      next()
  else if req.cookies.userlogintoken
    cookie = JSON.parse(req.cookies.userlogintoken)
    LoginToken.findOne
      email: cookie.email
      series: cookie.series
      token: cookie.token
    , (err, token) ->
      if token
        User.findOne {email: token.email}, (err, user) ->
          if user
            req.session.user_id = user.id
            req.currentUser = user
            token.token = token.randomToken()
            token.save ->
              res.cookie "userlogintoken", token.cookieValue,
                expires: new Date(Date.now() + 2 * 604800000)
                path: "/"
              console.log "token.save:"+nexted
              next()
          else
            next()
      else
        next()

    
     


exports.loadPost = loadPost = (req, res, next) ->
  console.log "Loading post"
  req.post = title: "Hello world"
  process.nextTick next