require 'sinatra/base'

module Sinatra
  module Api
    def self.registered(app)
      app.helpers Api::Helpers
      # list of publicly available badges for the current user
      app.get "/api/v1/badges/public/:user_id/:host.json" do
        domain = Domain.first(:host => params['host'])
        return "bad domain: #{params['host']}" unless domain
        user = UserConfig.first(:domain_id => domain.id, :user_id => params['user_id'])
        badge_list = []
        if domain
          if user && user.global_user_id
            badges = Badge.all(:global_user_id => user.global_user_id, :public => true)
          else
            badges = Badge.all(:user_id => params['user_id'], :domain_id => domain.id, :public => true)
          end
          badges.each do |badge|
            badge_list << badge_hash(badge.user_id, badge.user_name, badge)
          end
        end
        result = {
          :objects => badge_list
        }
        api_response(result)
      end
      
      # list of students who have been awarded this badge, whether or not
      # they are currently active in the course
      # requires admin permissions
      app.get "/api/v1/badges/awarded/:domain_id/:placement_id.json" do
        api_response(badge_list(true, params, session))
      end
      
      # list of students currently active in the course, showing whether
      # or not they have been awarded the badge
      # requires admin permissions
      app.get "/api/v1/badges/current/:domain_id/:placement_id.json" do
        api_response(badge_list(false, params, session))
      end
      
      # open badge details permalink
      app.head "/api/v1/badges/data/:placement_id/:user_id/:code.json" do
        api_response(badge_data(params, request.host_with_port))
      end
      
      # open badge details permalink
      app.get "/api/v1/badges/data/:placement_id/:user_id/:code.json" do
        api_response(badge_data(params, request.host_with_port))
      end
    end
    
    module Helpers
      def api_response(hash)
        if params['callback'] 
          "#{params['callback']}(#{hash.to_json});"
        else
          hash.to_json
        end
      end 
          
      def badge_data(params, host_with_port)
        badge = Badge.first(:placement_id => params[:placement_id], :user_id => params[:user_id], :nonce => params[:code])
        headers 'Content-Type' => 'application/json'
        if badge
          badge.badge_url = "#{BadgeHelpers.protocol}://#{host_with_port}" + badge.badge_url if badge.badge_url.match(/^\//)
          return badge.open_badge_json(host_with_port)
        else
          return {:error => "Not found"}
        end
      end
      
      def badge_list(awarded, params, session)
        @api_request = true
        load_badge_config(params['domain_id'], params['placement_id'], 'edit')

        badges = Badge.all(:domain_id => @domain_id, :placement_id => @placement_id)
        result = []
        next_url = nil
        params['page'] = '1' if params['page'].to_i == 0
        if awarded
          if badges.length > (params['page'].to_i * 50)
            next_url = "/api/v1/badges/awarded/#{@domain_id}/#{@placement_id}.json?page=#{params['page'].to_i + 1}"
          end
          badges = badges[((params['page'].to_i - 1) * 50), 50]
          badges.each do |badge|
            result << badge_hash(badge.user_id, badge.user_name, badge, @badge_config && @badge_config.root_nonce)
          end
        else
          json = BadgeHelpers.api_call("/api/v1/courses/#{@course_id}/users?enrollment_type=student&per_page=50&page=#{params['page'].to_i}", @user_config)
          json.each do |student|
            badge = badges.detect{|b| b.user_id.to_i == student['id'] }
            result << badge_hash(student['id'], student['name'], badge, @badge_config && @badge_config.root_nonce)
          end
          if json.instance_variable_get('@has_more')
            next_url = "/api/v1/badges/current/#{@domain_id}/#{@placement_id}.json?page=#{params['page'].to_i + 1}"
          end
        end
        return {
          :meta => {:next => next_url},
          :objects => result
        }
      end
      def badge_hash(user_id, user_name, badge, root_nonce=nil)
        if badge
          abs_url = badge.badge_url || "/badges/default.png"
          abs_url = "#{BadgeHelpers.protocol}://#{request.host_with_port}" + abs_url unless abs_url.match(/\:\/\//)
          {
            :id => user_id,
            :name => user_name,
            :manual => badge.manual_approval,
            :public => badge.public,
            :image_url => abs_url,
            :issued => badge && badge.issued && badge.issued.strftime('%b %e, %Y'),
            :nonce => badge && badge.nonce,
            :state => badge.state,
            :config_nonce => root_nonce || badge.config_nonce
          }
        else
          {
            :id => user_id,
            :name => user_name,
            :manual => nil,
            :public => nil,
            :image_url => nil,
            :issued => nil,
            :nonce => nil,
            :state => 'unissued',
            :config_nonce => root_nonce
          }
        end
      end
    end
  end
  
  register Api
end