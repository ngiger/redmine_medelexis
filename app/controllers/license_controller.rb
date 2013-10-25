class LicenseController < ApplicationController
  unloadable
  layout 'base'
  before_filter :find_user
  def say_hello
    @value = "Hello from #{__FILE__} #{__LINE__}"
  end

  def say_goodbye
    @value = "goodby from #{__FILE__} #{__LINE__}"
  end

private
  def find_user
    @myUser = User.find_by_login(params[:login])
    return @myUser.login
  end

end
