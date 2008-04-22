# frankie - a plugin for sinatra that integrates with the facebooker gem
#
# written by Ron Evans (http://www.deadprogrammersociety.com)
#
# based on merb_facebooker (http://github.com/vanpelt/merb_facebooker) 
# and the Rails classes in Facebooker (http://facebooker.rubyforge.org/) from Mike Mangino, Shane Vitarana, & Chad Fowler
#

require 'sinatra'

module Frankie

  module Loader
    
    require 'yaml'
    require 'uri'
    
    def load_facebook_config(file, env=:development)
      if File.exist?(file)
        yaml = YAML.load_file(file)[env.to_s]
        ENV['FACEBOOK_API_KEY'] = yaml['api_key']
        ENV['FACEBOOK_SECRET_KEY'] = yaml['secret_key']
        ENV['FACEBOOKER_RELATIVE_URL_ROOT'] = yaml['canvas_page_name']
      end
    end
       
  end
  
  module EventContext

    require "facebooker"
    
    def facebook_session
      @facebook_session
    end
    
    def facebook_session_parameters
      {:fb_sig_session_key=>params["fb_sig_session_key"]}
    end
    
    def set_facebook_session
      session_set = session_already_secured? || secure_with_token! || secure_with_facebook_params!
      if session_set
        capture_facebook_friends_if_available! 
        Facebooker::Session.current = facebook_session
      end
      session_set
    end
    
    def facebook_params
      @facebook_params ||= verified_facebook_params
    end      
    
    private
    
    def session_already_secured?    
      (@facebook_session = session[:facebook_session]) && session[:facebook_session].secured?
    end
    
    def secure_with_token!
      if params['auth_token']
        @facebook_session = new_facebook_session
        @facebook_session.auth_token = params['auth_token']
        @facebook_session.secure!
        session[:facebook_session] = @facebook_session
      end
    end
    
    def secure_with_facebook_params!
      return unless request_is_for_a_facebook_canvas?
      
      if ['user', 'session_key'].all? {|element| facebook_params[element]}
        @facebook_session = new_facebook_session
        @facebook_session.secure_with!(facebook_params['session_key'], facebook_params['user'], facebook_params['expires'])
        session[:facebook_session] = @facebook_session
      end
    end
    
    def create_new_facebook_session_and_redirect!
      session[:facebook_session] = new_facebook_session  
      throw :halt, do_redirect(session[:facebook_session].login_url) unless @installation_required 
    end
    
    def new_facebook_session
      Facebooker::Session.create(Facebooker::Session.api_key, Facebooker::Session.secret_key)
    end
    
    def capture_facebook_friends_if_available!
      return unless request_is_for_a_facebook_canvas?
      if friends = facebook_params['friends']
        facebook_session.user.friends = friends.map do |friend_uid|
          Facebooker::User.new(friend_uid, facebook_session)
        end
      end
    end
          
    def blank?(value)
      (value == '0' || value.nil? || value == '')        
    end

    def verified_facebook_params
      facebook_sig_params = params.inject({}) do |collection, pair|        
        collection[pair.first.sub(/^fb_sig_/, '')] = pair.last if pair.first[0,7] == 'fb_sig_'
        collection
      end
      verify_signature(facebook_sig_params, params['fb_sig'])
      facebook_sig_params.inject(Hash.new) do |collection, pair| 
        collection[pair.first] = facebook_parameter_conversions[pair.first].call(pair.last)
        collection
      end
    end
    
    # 48.hours.ago in sinatra
    def earliest_valid_session
      now = Time.now
      now -= (60 * 60 * 48)
      now
    end
    
    def verify_signature(facebook_sig_params,expected_signature)
      raw_string = facebook_sig_params.map{ |*args| args.join('=') }.sort.join
      actual_sig = Digest::MD5.hexdigest([raw_string, Facebooker::Session.secret_key].join)
      raise Facebooker::Session::IncorrectSignature if actual_sig != expected_signature
      raise Facebooker::Session::SignatureTooOld if Time.at(facebook_sig_params['time'].to_f) < earliest_valid_session
      true
    end
    
    def facebook_parameter_conversions
      @facebook_parameter_conversions ||= Hash.new do |hash, key| 
        lambda{|value| value}
      end.merge(
        'time' => lambda{|value| Time.at(value.to_f)},
        'in_canvas' => lambda{|value| !blank?(value)},
        'added' => lambda{|value| !blank?(value)},
        'expires' => lambda{|value| blank?(value) ? nil : Time.at(value.to_f)},
        'friends' => lambda{|value| value.split(/,/)}
      )
    end
    
    def do_redirect(*args)
      if request_is_for_a_facebook_canvas?
        fbml_redirect_tag(args)
      else
        redirect args[0]
      end
    end
    
    def fbml_redirect_tag(url)
      "<fb:redirect url=\"#{url}\" />"
    end
    
    def request_is_for_a_facebook_canvas?
      return false if params["fb_sig_in_canvas"].nil?
      params["fb_sig_in_canvas"] == "1"
    end
    
    def application_is_installed?
      facebook_params['added']
    end
    
    def ensure_authenticated_to_facebook
      set_facebook_session || create_new_facebook_session_and_redirect!
    end
    
    def ensure_application_is_installed_by_facebook_user
      @installation_required = true
      authenticated_and_installed = ensure_authenticated_to_facebook && application_is_installed? 
      application_is_not_installed_by_facebook_user unless authenticated_and_installed
      authenticated_and_installed
    end
    
    def application_is_not_installed_by_facebook_user
      throw :halt, do_redirect(session[:facebook_session].install_url)
    end
    
    def set_fbml_format
      params['format']="fbml" if request_is_for_a_facebook_canvas?
    end

    def fb_url_for(url)
      return URI.escape(url) if request_is_for_a_facebook_canvas?
      "http://apps.facebook.com/#{ENV['FACEBOOKER_RELATIVE_URL_ROOT']}/#{URI.escape(url)}"
    end
    
  end
  
end
  
# extend sinatra with frankie methods
Sinatra::EventContext.send(:include, Frankie::EventContext)
include Frankie::Loader
