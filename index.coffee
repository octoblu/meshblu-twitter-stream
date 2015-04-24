'use strict';
util           = require 'util'
{EventEmitter} = require 'events'
debug          = require('debug')('meshblu-twitter-stream')
_              = require 'lodash'
TwitterStream  = require './twitter-stream'

MESSAGE_SCHEMA =
  type: 'object'
  properties:
    command:
      type: 'string'
      required: true
      default: 'start'

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
  stop: 'stopStreaming'

class Plugin extends EventEmitter
  constructor: ->
    @options = {}
    @messageSchema = MESSAGE_SCHEMA
    @optionsSchema = OPTIONS_SCHEMA

  onMessage: (message) =>
    command = COMMANDS[message.payload?.command];
    return unless command
    @[command]()

  onConfig: (device) =>
    @setOptions device.options

  setOptions: (options={}) =>
    @options = options

  emitTweet: (tweet) =>
    data =
      devices: '*'
      topic: 'tweet'
      tweet: tweet
    @emit 'message', data

  startStreaming: =>
    debug 'Starting twitter streamer'
    twitterCreds =
      consumer_key: @options.consumerKey
      consumer_secret: @options.consumerSecret
      access_token_key: @options.accessTokenKey
      access_token_secret: @options.accessTokenSecret
    @twitterStream = new TwitterStream twitterCreds
    throttleTweet = _.throttle @emitTweet, 100
    @twitterStream.start(@options.searchQuery, throttleTweet)

  stopStreaming: =>
    debug 'stopping stream'
    return unless @twitterStream?
    @twitterStream.stop()
    @twitterStream = null

module.exports =
  messageSchema: MESSAGE_SCHEMA
  optionsSchema: OPTIONS_SCHEMA
  Plugin: Plugin
