Twitter = require 'twitter'
debug   = require('debug')('meshblu-twitter-stream:twitter-stream')

class TwitterStream
  constructor: (@credentials={}) ->
    debug 'Twitter Creds', @credentials
    @stream = null

  onTweet: (data) =>
    debug 'on tweet', data.text
    @onMessage data

  onError: (error) =>
    console.error error

  startStream: (@stream) =>
    debug 'twitter streaming'
    @stream.on 'data', @onTweet
    @stream.on 'error', @onError

  start: (searchQuery, @onMessage=->)=>
    debug 'TwitterStream.start(). QUERY: ', searchQuery
    @client ?= new Twitter @credentials
    @client.stream 'statuses/filter', track: searchQuery, @startStream

  stop: =>
    return console.log 'no streamer' unless @stream?
    @stream.removeListener('data', @onTweet)
    @stream.removeListener('error', @onError)

module.exports = TwitterStream
