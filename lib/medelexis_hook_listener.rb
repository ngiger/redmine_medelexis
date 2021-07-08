# lib/polls_hook_listener.rb
# see http://www.redmine.org/projects/redmine/wiki/Hooks_List
require 'pp'

class MedelexisHookListener < Redmine::Hook::ViewListener
 #  def view_contacts_sidebar_after_attributes(context={})
  def view_contacts_show_details_bottom(context={})
    userId = context[:contact].id
    return "" unless User.find_by_id(userId)
    apiKey = User.find(userId).api_key
    return content_tag(:a, "myLink")
  end

  def view_users_form(context={})
    return nil unless User.current.admin
    userId = context[:user].id
    return nil unless User.find_by_id(userId)
    apiKey = User.find(userId).api_key
    return content_tag(:a, l("gen_license_jar"), :href => "/my/#{context[:user].login}/license") + content_tag("div", "#{l(:setting_mail_handler_api_key)} #{apiKey}")
  end

  def log_issue(action, context)
    issue = context[:issue]
    params = context[:params]
  end

  # :controller_issues_edit_after_save    :params, :issue, :time_entry, :journal
  def controller_issues_new_after_save(context={})
    log_issue('after_save', context)
  end

  def controller_issues_edit_after_save(context={})
    log_issue('after_edit', context)
  end

end
