util           = require 'util'
{EventEmitter} = require 'events'
_              = require 'lodash'
TwitterStream  = require './twitter-stream.coffee'
TwitterRequest = require './twitter-request.coffee'
debug          = require('debug')('meshblu-twitter-stream:index')

MESSAGE_SCHEMA =
  type: 'object'
  properties:
    command:
      type: 'string'
      title: 'Command'
      required: true
      enum: ['start', 'stop', 'post', 'get']
    request:
      type: 'object'
      title: 'Request (for "get" and "post")'
      properties:
        endpoints:
          type: 'string'
          title: 'Endpoint'
          default: 'statuses/user_timeline'
        params:
          type: 'object'
          title: 'Params for Request'
          default: {}

OPTIONS_SCHEMA =
  type: 'object'
  properties:
    searchQuery:
      type: 'string'
      required: true
    consumerKey:
      type: 'string'
      required: true
    consumerSecret:
      type: 'string'
      required: true
    accessTokenKey:
      type: 'string'
      required: true
    accessTokenSecret:
      type: 'string'
      required: true

COMMANDS =
  start: 'startStreaming'
  stop:  'stopStreaming'
  get:   'getRequest'
  post:  'postRequest'

class Plugin extends EventEmitter
  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  onMessage: (message) =>
    return unless message?
    return unless message.payload?
    { request, command } = message.payload
    action = COMMANDS[command]
    return unless action?
    debug 'running command', command
    @[action](request)

  onConfig: (device) =>
    @setOptions device.options

  setOptions: (options={}) =>
    @options = _.mapValues options, (value) =>
      return value.trim()
    debug 'set options', @options

  emitTweet: (tweet={}) =>
    debug 'emitting tweet', tweet.id_str
    data =
      devices: ['*']
      topic: 'tweet'
      tweet: tweet
    @emit 'message', data

  emitError: (error) =>
    debug 'error', error
    data =
      devices: ['*']
      topic: 'error'
      error: error
    @emit 'error', data

  startStreaming: =>
    debug 'starting twitter streamer'
    twitterCreds =
      consumer_key: @options.consumerKey
      consumer_secret: @options.consumerSecret
      access_token_key: @options.accessTokenKey
      access_token_secret: @options.accessTokenSecret
    @twitterStream = new TwitterStream twitterCreds
    throttleTweet = _.throttle @emitTweet, 100
    @twitterStream.start @options.searchQuery, throttleTweet, @emitError

  stopStreaming: =>
    debug 'stopping stream'
    return unless @twitterStream?
    @twitterStream.stop()
    @twitterStream = null

  postRequest: (request={}) ->
    return @emitError 'Missing endpoints' unless request.endpoints?
    return @emitError 'Missing params' unless request.params?
    debug 'posting request'
    @twitterReq = new TwitterRequest @options unless @twitterReq?
    @twitterReq.post request, (error, tweet) =>
      return @emitError(error?.message ? error) if error?
      debug 'response is', tweet
      @emitTweet tweet

  getRequest: (request={}) =>
    debug 'geting request'
    return @emitError 'Missing endpoints' unless request.endpoints?
    return @emitError 'Missing params' unless request.params?
    @twitterReq = new TwitterRequest @options unless @twitterReq?
    @twitterReq.get request, (error, tweet) =>
      return @emitError(error?.message ? error) if error?
      debug 'response is', tweet
      @emitTweet tweet

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
