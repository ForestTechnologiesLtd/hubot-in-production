# Description:
#   Hubot auth example

module.exports = (robot) ->
  robot.respond /am [iI] authed/i, (res) ->
    user = res.envelope.user
    if robot.auth.hasRole(user, "a-role")
      res.reply "You sure are #{res.message.user.name}!"
    else if robot.auth.hasRole(user, "admin")
      res.reply "Nope, but you are an admin. Add yourself!"
    else
      res.reply "NO! Get outta here"
