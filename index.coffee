'use strict';
util           = require 'util'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-twitter-stream:index')
_              = require 'lodash'
TwitterStream  = require './twitter-stream.coffee'
TwitterRequest  = require './twitter-request.coffee'

MESSAGE_SCHEMA =
  type: 'object'
  properties:
    command:
      type: 'string'
      required: true
      enum: ['start', 'stop', 'post', 'get']
    request:
      type: 'object'
      properties:
        params:
          type: 'string'
          default: {}
        endpoints:
          type: 'string'
          title: 'endpoint'
          default: 'some/endpoint'


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
  get:   'getReq'
  post:  'postReq'

class Plugin extends EventEmitter
  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  onMessage: (message) =>
    command = COMMANDS[message.payload?.command]
    return unless command?
    debug 'running command', command
    @[command](message.payload.request)



  onConfig: (device) =>
    @setOptions device.options

  setOptions: (options={}) =>
    debug 'setting options', options
    @options = _.extend {
      consumerKey: ''
      consumerSecret: ''
      accessTokenKey: ''
      accessTokenSecret: ''
      searchQuery: ''
    }, options
    @options.consumerKey.trim()
    @options.consumerSecret.trim()
    @options.accessTokenKey.trim()
    @options.accessTokenSecret.trim()
    @options.searchQuery.trim()
    debug 'set options', @options

  emitTweet: (tweet={}) =>
    debug 'emitting tweet', tweet.id_str
    data =
      devices: '*'
      topic: 'tweet'
      tweet: tweet
    @emit 'message', data

  onError: (error) =>
    debug 'error', error
    data =
      devices: '*'
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
    @twitterStream.start @options.searchQuery, throttleTweet, @onError

  stopStreaming: =>
    debug 'stopping stream'
    return unless @twitterStream?
    @twitterStream.stop()
    @twitterStream = null

  postReq: (request) ->
    self = @
    debug 'posting request'
    @twitterReq = new TwitterRequest @options unless @twitterReq?
    @twitterReq.post request, (data) ->
      debug 'response is', data
      self.emitTweet data

  getReq: (request) =>
    self = @
    debug 'geting request'
    @twitterReq = new TwitterRequest @options unless @twitterReq?
    @twitterReq.get request, (data) ->
      debug 'response is', data
      self.emitTweet data


module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
