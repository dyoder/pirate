{type} = require "fairmont"

MongoDB = require "mongodb"

class Adapter
  
  @make: (configuration) ->
    new @ configuration
  
  constructor: (@configuration) ->
    {@events} = @configuration
    {host, port, options, database} = @configuration

    # Make sure we convert exceptions into error events
    @events.safely =>
      
      # Create the server object
      server = new MongoDB.Server(host, port, options)
      
      # Create the database
      @database = new MongoDB.Db database, server, w: 1
      
      # Open the database
      @database.open (error,database) =>
        unless error?
          @events.emit "ready", @
        else
          @events.emit "error", error
              
  collection: (name) ->
    @events.source (events) =>
      @database.collection name, (error,collection) =>
        unless error?
          events.emit "success", 
            Collection.make 
              collection: collection
              events: @events
              adapter: @
        else
          events.emit "error", error

  
  close: ->
    @database.close()
    
class Collection
  
  @make: (options) ->
    new @ options
  
  constructor: ({@events,@collection,@adapter}) ->
        
  get: (key) ->
    @events.source (events) =>
      events.safely =>
        @collection.findOne {_id: key}, (error,result) ->
          unless error?
            events.emit "success", result
          else
            events.emit "error", error

  put: (key,object) ->
    @events.source (events) =>
      # you can't update the _id field
      delete object._id
      @collection.update {_id: key}, object, 
        {upsert: true, safe: true}, 
        (error,results) =>
          unless error?
            events.emit "success", object
          else
            events.emit "error", error

  # by a quirk in MongoDB's DML you can implement
  # ::patch in terms of ::put
  patch: (key,patch) ->
    # you can't update the _id field
    delete patch._id
    @put key, {$set: patch}

  delete: (key) ->
    @events.source (events) =>
      @collection.remove {_id: key}, (error,results) =>
        unless error?
          events.emit "success"
        else
          events.emit "error", error
          
  all: ->
    @events.source (events) =>
      @collection.find {}, (error,results) =>
        unless error?
          results.toArray (error,results) =>
            unless error?
              events.emit "success", results
            else
              events.emit "error", error
        else
          events.emit "error", error
    
  count: ->
    @events.source (events) => 
      @collection.count (error,count) =>
        unless error?
          events.emit "success", count
        else
          events.emit "error", error

module.exports = 
  Adapter: Adapter
  Collection: Collection