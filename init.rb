require File.dirname(__FILE__) + '/lib/frankie'

Sinatra::EventContext.send(:include, Sinatra::Frankie::EventContext)
include Sinatra::Frankie::Dsl