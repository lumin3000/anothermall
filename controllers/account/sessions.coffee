User = app.User
LoginToken = app.LoginToken

#destroy
exports.index = (req, res)->
  console.log req.currentUser
  if req.session
    LoginToken.remove
      email: req.currentUser.email
    , ->
    res.clearCookie "userlogintoken"
    req.session.destroy ->
  res.redirect "/account/sessions/new"


exports.new = (req, res)->
  res.render "sessions/new.jade",{locals:{user: new User()}}


exports.create = (req, res)->
  User.findOne
    email: req.body.user.email
  , (err, user) ->
    if user and user.authenticate(req.body.user.password)
      req.session.user_id = user.id
      if req.body.remember_me
        loginToken = new LoginToken(email: user.email)
        loginToken.save ->
          res.cookie "userlogintoken", loginToken.cookieValue,
            expires: new Date(Date.now() + 2 * 604800000)
            path: "/"
          res.redirect "/"
      else
        res.redirect "/"
    else
      req.flash "error", "Incorrect credentials"
      res.redirect "/account/sessions/new"