# Description:
#   Holler whenever anything happens around a Bitbucket pull request
#
# Dependencies:
#   "url": ""
#   "querystring": ""
#
# Configuration:
#   Set up a Bitbucket Pull Request hook with the URL
#   {your_hubot_base_url}/hubot/bitbucket-pr?name={your_repo_name}. Check all boxes on prompt.
#   A default room can be set with HUBOT_BITBUCKET_PULLREQUEST_ROOM.
#   If this is not set, a room param is required:
#   ...bitbucket-pr?name={your_repo_name}&room={your_room_id}
#
# Author:
#   tshedor

url = require('url')
querystring = require('querystring')

module.exports = (robot) ->
  robot.router.post '/hubot/bitbucket-pr', (req, res) ->

    query = querystring.parse(url.parse(req.url).query)

    # Determine what actions to announce
    announce_options = []
    if process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE
      announce_options = process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE.replace(/[^a-z\,]+/, '').split(',')

    # default back to everything if no options set
    announce_options = ['created', 'updated', 'declined', 'merged', 'comment_created', 'approve', 'unapprove'] if announce_options.length == 0


    # Fallback to default Pull request room
    room = if query.room then query.room else process.env.HUBOT_BITBUCKET_PULLREQUEST_ROOM
    repo_name = query.name

    data = req.body
    msg = ''

    # Slack special formatting
    if robot.adapterName is 'slack'
      green = '#48CE78'
      blue = '#286EA6'
      red = '#E5283E'
      purple = '#AA82E5'
      orange = '#F1A56F'

      msg =
        message:
          reply_to: room
          room: room

      # Created
      if data.hasOwnProperty('pullrequest_created') && ('created' in announce_options)
        resp = data.pullrequest_created

        if resp.reviewers.length > 0
          reviewers = ''
          for reviewer in resp.reviewers
            reviewers += " #{reviewer.display_name}"
        else
          reviewers = ' no one in particular'

        content =
          text: "#{resp.author.display_name} created a new request"
          fallback: "Yo#{reviewers}, #{resp.author.display_name} just *created* the pull request \"#{resp.title}\" for `#{resp.destination.branch.name}` on `#{repo_name}`.\n#{resp.links.html.href}"
          pretext: reviewers
          color: blue
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: repo_name
              value: resp.title
              short: true
            }
            {
              title: "Merge to #{resp.destination.branch.name}"
              value: "#{resp.links.html.href}\nRequesting review from#{reviewers}"
              short: true
            }
          ]

      # Comment added
      if data.hasOwnProperty('pullrequest_comment_created') && ('comment_created' in announce_options)
        resp = data.pullrequest_comment_created

        content =
          text: ''
          fallback: "#{resp.user.display_name} *added a comment* on `#{repo_name}`:\n\"#{resp.content.raw}\" \n\n#{resp.links.html.href}"
          pretext: ''
          color: orange
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: "#{resp.user.display_name} commented"
              value: resp.content.raw
              short: true
            }
            {
              title: repo_name
              value: resp.links.html.href
              short: true
            }
          ]

      # Declined
      if data.hasOwnProperty('pullrequest_declined') && ('declined' in announce_options)
        resp = data.pullrequest_declined
        content = branch_action(resp, 'Declined', red, repo_name)

      # Merged
      if data.hasOwnProperty('pullrequest_merged') && ('merged' in announce_options)
        resp = data.pullrequest_merged
        content = branch_action(resp, 'Merged', green, repo_name)

      # Updated
      if data.hasOwnProperty('pullrequest_updated') && ('updated' in announce_options)
        resp = data.pullrequest_updated
        content = branch_action(resp, 'Updated', purple, repo_name)

      # Approved
      if data.hasOwnProperty('pullrequest_approve') && ('approve' in announce_options)
        resp = data.pullrequest_approve
        encourage_array = [':thumbsup:', 'That was a nice thing you did.', 'Boomtown', 'BOOM', 'Finally.', 'And another request bites the dust.']
        encourage_me = encourage_array[Math.floor(Math.random()*encourage_array.length)];
        content =
          text: ''
          fallback: "A pull request on `#{repo_name}` has been approved by #{resp.user.display_name}\n#{encourage_me}"
          pretext: encourage_me
          color: green
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: repo_name
              value: "Pull request approved by #{resp.user.display_name}"
              short: false
            }
          ]

      # Unapproved
      if data.hasOwnProperty('pullrequest_unapprove') && ('unapprove' in announce_options)
        resp = data.pullrequest_unapprove
        content =
          text: "Pull Request Unapproved"
          fallback: "A pull request on `#{repo_name}` has been unapproved by #{resp.user.display_name}"
          pretext: 'Darn it.'
          color: red
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: repo_name
              value: "Unapproved by #{resp.user.display_name}"
              short: false
            }
          ]

      msg.content = content
      robot.emit 'slack-attachment', msg

    # For hubot adapters that are not Slack
    else

      # PR created
      if data.hasOwnProperty('pullrequest_created') && ('created' in announce_options)
        resp = data.pullrequest_created
        if resp.reviewers.length > 0
          reviewers = ''
          for reviewer in resp.reviewers
            reviewers += " #{reviewer.display_name}"
        else
          reviewers = ' no one in particular'

      # Comment created
      if data.hasOwnProperty('pullrequest_comment_created') && ('comment_created' in announce_options)
        resp = data.pullrequest_comment_created
        msg = "#{resp.user.display_name} *added a comment* on `#{repo_name}`: \"#{resp.content.raw}\" "
        msg += "\n#{resp.links.html.href}"

        msg = "Yo#{reviewers}, #{resp.author.display_name} just *created* the pull request \"#{resp.title}\" for `#{resp.destination.branch.name}` on `#{repo_name}`.\n#{resp.links.html.href}"

      # Declined
      if data.hasOwnProperty('pullrequest_declined') && ('declined' in announce_options)
        resp = data.pullrequest_declined
        msg = branch_action(resp, 'declined', 'thwarting the attempted merge of',  repo_name)

      # Merged
      if data.hasOwnProperty('pullrequest_merged') && ('merged' in announce_options)
        resp = data.pullrequest_merged
        msg = branch_action(resp, 'merged', 'joining in sweet harmony', repo_name)

      # Updated
      if data.hasOwnProperty('pullrequest_updated') && ('updated' in announce_options)
        resp = data.pullrequest_updated
        msg = branch_action(resp, 'updated', 'clarifying why it is necessary to merge', repo_name)
        msg += "\n #{resp.destination.repository.links.html.href}"

      # Approved
      if data.hasOwnProperty('pullrequest_approve') && ('approve' in announce_options)
        resp = data.pullrequest_approve
        msg = "A pull request on `#{repo_name}` has been approved by #{resp.user.display_name}"
        encourage_array = [':thumbsup:', 'That was a nice thing you did.', 'Boomtown', 'BOOM', 'Finally.', 'And another request bites the dust.']
        encourage_me = encourage_array[Math.floor(Math.random()*encourage_array.length)];
        msg += "\n #{encourage_me}"

      # Unapproved
      if data.hasOwnProperty('pullrequest_unapprove') && ('unapprove' in announce_options)
        resp = data.pullrequest_unapprove
        msg = "A pull request on `#{repo_name}` has been unapproved by #{resp.user.display_name}"

      robot.messageRoom room, msg

    # Close response
    res.writeHead 204, { 'Content-Length': 0 }
    res.end()

  # Consolidate redundant formatting with branch_action func

  if robot.adapterName is 'slack'

    branch_action = (resp, action_name, color, repo_name) ->
      fields = []
      fields.push
        title: resp.author.display_name
        value: "#{action_name} \"#{resp.title}\" #{resp.reason}"
        short: true
      fields.push
        title: repo_name
        value: resp.source.branch.name
        short: true

      payload =
        text: ''
        fallback: "#{resp.author.display_name} *#{action_name}* pull request \"#{resp.title}\"."
        pretext: ''
        color: color
        mrkdwn_in: ["text", "title", "fallback", "fields"]
        fields: fields

      return payload

  else

    branch_action = (resp, action_name, action_desc, repo_name) ->
      msg = "#{resp.author.display_name} *#{action_name}* pull request \"#{resp.title},\" #{action_desc} `#{resp.source.branch.name}` and `#{resp.destination.branch.name}` into a `#{repo_name}` super branch"
      msg += if resp.reason isnt '' then ":\n\"#{resp.reason}\"" else "."

      return msg
