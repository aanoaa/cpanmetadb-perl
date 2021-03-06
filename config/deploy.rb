require 'capistrano/ext/multistage'

set :stages, %w(production vagrant)
set :default_stage, "production"

set :application, "cpanmetadb-perl"
set :repository,  "git://github.com/miyagawa/cpanmetadb-perl.git"

set :scm, :git
set :use_sudo, false
set :branch, ENV['BRANCH'] || "master"
set :deploy_via, :remote_cache

# http://stackoverflow.com/questions/3023857/capistrano-and-deployment-of-a-website-from-github
set :normalize_asset_timestamps, false

before "deploy:finalize_update", "carton:install"
after "deploy:setup", "deploy:permissions"

namespace :carton do
  task :install do
    run "cd #{latest_release} && carton install --deployment --path=#{shared_path}/local 2>&1"
  end
end

namespace :deploy do
  task :permissions do
    run "chown #{runner} /u/apps/#{application}/shared/log /u/apps/#{application}/shared/pids"
  end

  task :start, :roles => :app do
    run <<-EOC
      if ! supervisorctl status #{application} | grep RUNNING;
      then
        cp #{current_path}/config/supervisor/#{application}.#{stage}.conf /etc/supervisor/conf.d/#{application}.conf;
        supervisorctl reread;
        supervisorctl add #{application};
      fi;
      supervisorctl start #{application}
    EOC
  end

  task :stop, :roles => :app do
    run "supervisorctl stop #{application}"
  end

  task :restart, :roles => :app do
    run "kill -HUP `cat #{shared_path}/pids/start_server.pid`"
  end

  task :status, :roles => :app do
    run "supervisorctl status #{application}"
  end

  task :remove_crontab, :roles => :app do
    run "crontab -r; true"
  end

  task :install_crontab, :roles => :app do
    crontab = ERB.new(IO.read("config/crontab.erb")).result(binding)
    put crontab, "/tmp/crontab"
    run "crontab /tmp/crontab && rm -f /tmp/crontab"
  end
end
