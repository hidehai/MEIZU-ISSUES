require 'redmine/access_control'
require 'redmine/menu_manager'
require 'redmine/activity'
require 'redmine/search'
require 'redmine/custom_field_format'
require 'redmine/mime_type'
require 'redmine/core_ext'
require 'redmine/hook'
require 'redmine/plugin'
require 'redmine/notifiable'
require 'redmine/wiki_formatting'
require 'redmine/scm/base'

begin
  require 'RMagick' unless Object.const_defined?(:Magick)
rescue LoadError
  # RMagick is not available
end

if RUBY_VERSION < '1.9'
  require 'fastercsv'
else
  require 'csv'
  FCSV = CSV
end

Redmine::Scm::Base.add "Subversion"
Redmine::Scm::Base.add "Darcs"
Redmine::Scm::Base.add "Mercurial"
Redmine::Scm::Base.add "Cvs"
Redmine::Scm::Base.add "Bazaar"
Redmine::Scm::Base.add "Git"
Redmine::Scm::Base.add "Filesystem"

Redmine::CustomFieldFormat.map do |fields|
  fields.register 'string'
  fields.register 'text'
  fields.register 'int', :label => :label_integer
  fields.register 'float'
  fields.register 'list'
  fields.register 'date'
  fields.register 'bool', :label => :label_boolean
  fields.register 'user', :only => %w(Issue TimeEntry Version Project), :edit_as => 'list'
  fields.register 'version', :only => %w(Issue TimeEntry Version Project), :edit_as => 'list'
end

# Permissions
Redmine::AccessControl.map do |map|
  map.permission :view_project, {:projects => [:show], :activities => [:index]}, :public => true, :read => true
  map.permission :search_project, {:search => :index}, :public => true, :read => true
  map.permission :add_project, {:projects => [:new, :create]}, :require => :loggedin
  map.permission :edit_project, {:projects => [:settings, :edit, :update], :'planners/projects' => [ :update]}, :require => :member
  map.permission :close_project, {:projects => [:close, :reopen]}, :require => :member, :read => true
  map.permission :select_project_modules, {:projects => :modules}, :require => :member
  map.permission :manage_members, {:projects => :settings, :members => [:index, :show, :create, :update, :destroy, :autocomplete]}, :require => :member
  map.permission :manage_versions, {:projects => :settings, :versions => [:new, :create, :edit, :update, :close_completed, :destroy]}, :require => :member
  map.permission :add_subprojects, {:projects => [:new, :create]}, :require => :member

  map.project_module :issue_tracking do |map|
    # Issue categories
    map.permission :manage_categories, {:projects => :settings, :issue_categories => [:index, :show, :new, :create, :edit, :update, :destroy]}, :require => :member
    # Issues
    map.permission :view_issues, {:issues => [:index, :show, :assigned_to_me, :reported, :watched, :closed],
                                  :auto_complete => [:issues],
                                  :context_menus => [:issues],
                                  :versions => [:index, :show, :status_by],
                                  :journals => [:index, :diff],
                                  :queries => :index,
                                  :reports => [:issue_report, :issue_report_details]},
                                  :read => true
    map.permission :add_issues, {:issues => [:new, :create, :update_form], :attachments => :upload}
    map.permission :edit_issues, {:issues => [:edit, :update, :bulk_edit, :bulk_update, :update_form], :journals => [:new], :attachments => :upload}
    map.permission :manage_issue_relations, {:issue_relations => [:index, :show, :create, :destroy]}
    map.permission :manage_subtasks, {}
    map.permission :set_issues_private, {}
    map.permission :set_own_issues_private, {}, :require => :loggedin
    map.permission :add_issue_notes, {:issues => [:edit, :update], :journals => [:new], :attachments => :upload}
    map.permission :edit_issue_notes, {:journals => :edit}, :require => :loggedin
    map.permission :edit_own_issue_notes, {:journals => :edit}, :require => :loggedin
    map.permission :move_issues, {:issues => [:bulk_edit, :bulk_update]}, :require => :loggedin
    map.permission :delete_issues, {:issues => :destroy}, :require => :member
    # Queries
    map.permission :manage_public_queries, {:queries => [:new, :create, :edit, :update, :destroy]}, :require => :member
    map.permission :save_queries, {:queries => [:new, :create, :edit, :update, :destroy]}, :require => :loggedin
    # Watchers
    map.permission :view_issue_watchers, {}, :read => true
    map.permission :add_issue_watchers, {:watchers => :new}
    map.permission :delete_issue_watchers, {:watchers => :destroy}
  end

  map.project_module :time_tracking do |map|
    map.permission :log_time, {:timelog => [:new, :create]}, :require => :loggedin
    map.permission :view_time_entries, {:timelog => [:index, :report, :show]}, :read => true
    map.permission :edit_time_entries, {:timelog => [:edit, :update, :destroy, :bulk_edit, :bulk_update]}, :require => :member
    map.permission :edit_own_time_entries, {:timelog => [:edit, :update, :destroy,:bulk_edit, :bulk_update]}, :require => :loggedin
    map.permission :manage_project_activities, {:project_enumerations => [:update, :destroy]}, :require => :member
  end

  map.project_module :news do |map|
    map.permission :manage_news, {:news => [:new, :create, :edit, :update, :destroy], :comments => [:destroy]}, :require => :member
    map.permission :view_news, {:news => [:index, :show]}, :public => true, :read => true
    map.permission :comment_news, {:comments => :create}
  end

  map.project_module :documents do |map|
    map.permission :manage_documents, {:documents => [:new, :create, :edit, :update, :destroy, :add_attachment]}, :require => :loggedin
    map.permission :view_documents, {:documents => [:index, :show, :download]}, :read => true
  end

  map.project_module :files do |map|
    map.permission :manage_files, {:files => [:create]}, :require => :loggedin
    map.permission :view_files, {:files => :index, :versions => :download}, :read => true
    map.permission :view_attachments, {:files => :index, :versions => :download}, :read => true
  end

  map.project_module :wiki do |map|
    map.permission :manage_wiki, {:wikis => [:edit, :destroy]}, :require => :member
    map.permission :rename_wiki_pages, {:wiki => :rename}, :require => :member
    map.permission :delete_wiki_pages, {:wiki => :destroy}, :require => :member
    map.permission :view_wiki_pages, {:wiki => [:index, :show, :special, :date_index]}, :read => true
    map.permission :export_wiki_pages, {:wiki => [:export]}, :read => true
    map.permission :view_wiki_edits, {:wiki => [:history, :diff, :annotate]}, :read => true
    map.permission :edit_wiki_pages, :wiki => [:new, :edit, :update, :preview, :add_attachment]
    map.permission :delete_wiki_pages_attachments, {}
    map.permission :protect_wiki_pages, {:wiki => :protect}, :require => :member
  end

  map.project_module :repository do |map|
    map.permission :manage_repository, {:repositories => [:new, :create, :edit, :update, :committers, :destroy]}, :require => :member
    map.permission :browse_repository, {:repositories => [:show, :browse, :entry, :raw, :annotate, :changes, :diff, :stats, :graph]}, :read => true
    map.permission :view_changesets, {:repositories => [:show, :revisions, :revision]}, :read => true
    map.permission :commit_access, {}
    map.permission :manage_related_issues, {:repositories => [:add_related_issue, :remove_related_issue]}
  end

  map.project_module :boards do |map|
    map.permission :manage_boards, {:boards => [:new, :create, :edit, :update, :destroy]}, :require => :member
    map.permission :view_messages, {:boards => [:index, :show], :messages => [:show]}, :public => true, :read => true
    map.permission :add_messages, {:messages => [:new, :reply, :quote]}
    map.permission :edit_messages, {:messages => :edit}, :require => :member
    map.permission :edit_own_messages, {:messages => :edit}, :require => :loggedin
    map.permission :delete_messages, {:messages => :destroy}, :require => :member
    map.permission :delete_own_messages, {:messages => :destroy}, :require => :loggedin
  end

  map.project_module :calendar do |map|
    map.permission :view_calendar, {:calendars => [:show, :update]}, :read => true
  end

  map.project_module :gantt do |map|
    map.permission :view_gantt, {:gantts => [:show, :update]}, :read => true
  end

  map.project_module :member_invitations do |map|
    map.permission :manage_member_invitations, {:member_invitations => [:new, :create, :accept, :reject, :destroy], :'planners/projects' => [:add_member,:new_member]}
  end
end

Redmine::MenuManager.map :top_menu do |menu|
  menu.push :home, :home_path
  menu.push :my_page, { :controller => 'my', :action => 'page' }, :if => Proc.new { User.current.logged? }
  menu.push :projects, { :controller => 'projects', :action => 'index' }, :caption => :label_project_plural
  menu.push :administration, { :controller => 'admin', :action => 'index' }, :if => Proc.new { User.current.admin? }, :last => true
  menu.push :help, Redmine::Info.help_url, :last => true
end

Redmine::MenuManager.map :account_menu do |menu|
  menu.push :login, :signin_path, :if => Proc.new { !User.current.logged? }
  menu.push :register, :register_path, :if => Proc.new { !User.current.logged? && Setting.self_registration? }
  menu.push :my_account, { :controller => 'my', :action => 'account' }, :if => Proc.new { User.current.logged? }
  menu.push :logout, :signout_path, :if => Proc.new { User.current.logged? }
end

Redmine::MenuManager.map :application_menu do |menu|
  # Empty
end

Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :projects, {:controller => 'admin', :action => 'projects'}, :caption => :label_project_plural
  menu.push :users, {:controller => 'users'}, :caption => :label_user_plural
  menu.push :index, {:controller => 'newfeatures', :action => 'index'}, :caption => :label_newfeatures_plural 
  menu.push :groups, {:controller => 'groups'}, :caption => :label_group_plural
  menu.push :roles, {:controller => 'roles'}, :caption => :label_role_and_permissions
  menu.push :trackers, {:controller => 'trackers'}, :caption => :label_tracker_plural
  menu.push :issue_statuses, {:controller => 'issue_statuses'}, :caption => :label_issue_status_plural,
            :html => {:class => 'issue_statuses'}
  menu.push :workflows, {:controller => 'workflows', :action => 'edit'}, :caption => :label_workflow
  menu.push :custom_fields, {:controller => 'custom_fields'},  :caption => :label_custom_field_plural,
            :html => {:class => 'custom_fields'}
  menu.push :enumerations, {:controller => 'enumerations'}
  menu.push :settings, {:controller => 'settings'}
  menu.push :ldap_authentication, {:controller => 'auth_sources', :action => 'index'},
            :html => {:class => 'server_authentication'}
  menu.push :plugins, {:controller => 'admin', :action => 'plugins'}, :last => true
  menu.push :info, {:controller => 'admin', :action => 'info'}, :caption => :label_information_plural, :last => true
end

Redmine::MenuManager.map :project_menu do |menu|
  # menu.push :overview, { :controller => 'projects', :action => 'show' }
  # menu.push :activity, { :controller => 'activities', :action => 'index' }
  # menu.push :roadmap, { :controller => 'versions', :action => 'index' }, :param => :project_id,
  #             :if => Proc.new { |p| p.shared_versions.any? }
  menu.push :issues, { :controller => 'issues', :action => 'index' }, :param => :project_id, :caption => :label_issue_plural
  # menu.push :new_issue, { :controller => 'issues', :action => 'new' }, :param => :project_id, :caption => :label_issue_new,
  #             :html => { :accesskey => Redmine::AccessKeys.key_for(:new_issue) }
  # menu.push :gantt, { :controller => 'gantts', :action => 'show' }, :param => :project_id, :caption => :label_gantt
  # menu.push :calendar, { :controller => 'calendars', :action => 'show' }, :param => :project_id, :caption => :label_calendar
  # menu.push :news, { :controller => 'news', :action => 'index' }, :param => :project_id, :caption => :label_news_plural
  # menu.push :documents, { :controller => 'documents', :action => 'index' }, :param => :project_id, :caption => :label_document_plural
  menu.push :wiki, { :controller => 'wiki', :action => 'index' }, :param => :project_id,
              :if => Proc.new { |p| p.wiki && !p.wiki.new_record? }
  # menu.push :boards, { :controller => 'boards', :action => 'index', :id => nil }, :param => :project_id,
  #             :if => Proc.new { |p| p.boards.any? }, :caption => :label_board_plural
  menu.push :files, { :controller => 'files', :action => 'index' }, :caption => :label_file_plural, :param => :project_id
  # menu.push :repository, { :controller => 'repositories', :action => 'show', :repository_id => nil, :path => nil, :rev => nil },
  #             :if => Proc.new { |p| p.repository && !p.repository.new_record? }
  # menu.push :settings, { :controller => 'projects', :action => 'settings' }, :last => true
end

Redmine::Activity.map do |activity|
  activity.register :issues, :class_name => %w(Issue Journal)
  activity.register :changesets, :default => false
  activity.register :news, :default => false
  activity.register :documents, :class_name => %w(Document Attachment), :default => false
  activity.register :files, :class_name => 'Attachment'
  activity.register :wiki_edits, :class_name => 'WikiContent::Version'
  activity.register :messages, :default => false
  activity.register :time_entries, :default => false
end

Redmine::Search.map do |search|
  search.register :issues
  # search.register :news
  # search.register :documents
  # search.register :changesets
  search.register :wiki_pages
  # search.register :messages
  # search.register :projects
  search.register :attachments
end

Redmine::WikiFormatting.map do |format|
  format.register :textile, Redmine::WikiFormatting::Textile::Formatter, Redmine::WikiFormatting::Textile::Helper
end

ActionView::Template.register_template_handler :rsb, Redmine::Views::ApiTemplateHandler
