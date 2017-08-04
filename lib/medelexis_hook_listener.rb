# lib/polls_hook_listener.rb
# see http://www.redmine.org/projects/redmine/wiki/Hooks_List
require 'pp'

class MedelexisHookListener < Redmine::Hook::ViewListener
 #  def view_contacts_sidebar_after_attributes(context={})
  def view_contacts_show_details_bottom(context={})
    userId = context[:contact].id
    apiKey = User.find(userId).api_key
    return content_tag(:a, "myLink")
  end

  def view_users_form(context={})
    RedmineMedelexis.log_to_system("logger redmine:#{view_users_form} User.current.admin '#{User.current.admin.inspect}'")
    return nil unless User.current.admin
    userId = context[:user].id
    apiKey = User.find(userId).api_key
    RedmineMedelexis.log_to_system("logger redmine:#{view_users_form} userId '#{userId.inspect}' apiKey '#{apiKey.inspect}'")
    return content_tag(:a, l("gen_license_jar"), :href => "/my/#{context[:user].login}/license") + content_tag("div", "#{l(:setting_mail_handler_api_key)} #{apiKey}")
  end

  def log_issue(action, context)
    issue = context[:issue]
    params = context[:params]
    RedmineMedelexis.log_to_system("logger redmine:#{action} issue '#{issue.id}'")
  end

  # :controller_issues_edit_after_save    :params, :issue, :time_entry, :journal
  def controller_issues_new_after_save(context={})
    log_issue('after_save', context)
  end

  def controller_issues_edit_after_save(context={})
    log_issue('after_edit', context)
  end

end
