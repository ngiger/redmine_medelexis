# lib/polls_hook_listener.rb
# see http://www.redmine.org/projects/redmine/wiki/Hooks_List
# require 'pp'
#    require 'pry'; binding.pry

class MedelexisHookListener < Redmine::Hook::ViewListener
 #  def view_contacts_sidebar_after_attributes(context={})
  def view_contacts_show_details_bottom(context={})
    userId = context[:contact].id
    apiKey = User.find(userId).api_key
    return content_tag(:div, content_tag(:p, "view_contacts_show_details_bottom") +content_tag(:b, "Context #{context[:contact].first_name} API-Key #{apiKey}"), :class => "name")
  end
  
  def view_users_form(context={})
    return nil unless User.current.admin
    userId = context[:user].id
    apiKey = User.find(userId).api_key
    return content_tag("p", "api_key #{apiKey}")
  end
  
  def log_issue(action, context)
    issue = context[:issue]
    params = context[:params]
    system("logger redmine:#{action} issue '#{issue.inspect}' params '#{params.inspect}'")
  end
  
  # :controller_issues_edit_after_save    :params, :issue, :time_entry, :journal
  def controller_issues_new_after_save(context={})
    log_issue('after_save', context)
  end
  
  def controller_issues_edit_after_save(context={})
    log_issue('after_edit', context)
  end
  
end
