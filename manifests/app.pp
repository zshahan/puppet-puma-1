# puma::app
define puma::app (
  $app_name           = $title,
  $app_root           = sprintf($puma::app_root_spf, $title),
  $puma_user          = $puma::puma_user,
  $www_user           = $puma::www_user,
  $min_threads        = $puma::min_threads,
  $max_threads        = $puma::max_threads,
  $port               = $puma::port,
  $bind_ip            = $puma::bind_ip,
  $workers            = $puma::workers,
  $init_active_record = $puma::init_active_record,
  $preload_app        = $puma::preload_app,
  $env                = $puma::env,
  $rvm_ruby           = $puma::rvm_ruby,
  $restart_command    = $puma::restart_command,
  $on_restart         = false,
  $puma_log_append    = false
) {
  $puma_pid_path        = sprintf($puma::puma_pid_path_spf, $app_name)
  $puma_pid_dir         = dirname($puma_pid_path)
  $puma_socket_path     = sprintf($puma::puma_socket_path_spf, $app_name)
  $puma_config_path     = sprintf($puma::puma_config_path_spf, $app_name)
  $puma_stdout_log_path = sprintf($puma::puma_stdout_log_path_spf, $app_name)
  $puma_stderr_log_path = sprintf($puma::puma_stderr_log_path_spf, $app_name)

  if $rvm_ruby {
    puma::rvm {$app_name:
      rvm_ruby => $rvm_ruby,
    }
    $ruby_exec_prefix = "/usr/local/rvm/bin/rvm ${rvm_ruby}@${app_name} do "
  } else {
    $ruby_exec_prefix = ''
  }

  ensure_resource('user',  $puma_user, {
    ensure => present
  })

  # Ensure all this crap is reachable
  $all_conf_dirs = unique([
    dirname($puma_pid_path),
    dirname($puma_socket_path),
    dirname($puma_config_path),
    dirname($puma_stdout_log_path),
    dirname($puma_stderr_log_path),
  ])

  $pid_dirs = unique([
    dirname($puma_pid_path),
    dirname($puma_socket_path),
  ])

  $other_conf_dirs = difference($all_conf_dirs, $pid_dirs)

  # These MUST be owned by $puma_user as well
  file { $pid_dirs:
    ensure => directory,
    owner  => $puma_user,
    group  => $www_user,
    mode   => 'ug=rwxs,o-o',
  }

  # For the rest, just ensure reachable
  ensure_resource('file', $other_conf_dirs, {
    ensure => directory,
    owner  => $puma_user,
    group  => $www_user,
    mode => 'a+x',
  })

  case $puma::service_type {
    'upstart': {
      # Fancy upstart job - can respawn dead ruby procs
      ensure_resource('class', 'upstart')
      upstart::job { $app_name:
        description   => "${app_name} - puma application",
        respawn       => true,
        respawn_limit => '5 10',
        user          => $puma_user,
        group         => $puma_user,
        chdir         => $app_root,
        env           => $env,
        exec          => "${ruby_exec_prefix} bundle exec puma \
                         -C ${puma_config_path}",
        require       => File[$puma_config_path],
        pre_start     => "sudo mkdir -p ${puma_pid_dir}\nsudo chown -R \
                         ${puma_user}:${puma_user} ${puma_pid_dir}\n"
      }
      $puma_daemonize = false # this is important
                  #  - upstart does NOT play well with doing your own
                  # daemonization - best to just give it a regular process
                  # ps: expect deamon is not nearly as smart/reliable as it
                  # claims to be
    }
    'sysv': {
      # Old-school init.d - no supervision
      $init_script = sprintf($puma::init_script_spf, $app_name)
      file { $init_script:
        content => template('puma/app_init_script.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
      }
      service { $app_name:
        ensure  => running,
        enable  => true,
        require => [
          File[$init_script],
          User[$puma_user],
          File[$puma_stdout_log_path],
          File[$puma_stderr_log_path],
          File[$puma_config_path],
        ]
      }
      $puma_daemonize = true
    }
    'systemd': {
      file { 'systemd_config':
        content => template('puma/systemd.erb'),
        path    => "/etc/systemd/system/${app_name}.service",
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
      }
      service { $app_name:
        ensure  => running,
        enable  => true,
        require => [
          User[$puma_user],
          File['systemd_config'],
          File[$puma_stdout_log_path],
          File[$puma_stderr_log_path],
          File[$puma_config_path],
        ]
      }
      $puma_daemonize = false

      file { "${app_root}/shared/bin/start.sh":
        content => "#!/bin/sh\n\n${app_root}/shared/bin/pumacmd.sh start",
        owner   => $puma_user,
        group   => $puma_user,
        mode    => '0755',
        require => File["${app_root}/shared/bin"]
      }
      file { "${app_root}/shared/bin/stop.sh":
        content => "#!/bin/sh\n\n${app_root}/shared/bin/pumacmd.sh stop",
        owner   => $puma_user,
        group   => $puma_user,
        mode    => '0755',
        require => File["${app_root}/shared/bin"]
      }
      file { "${app_root}/shared/bin/restart.sh":
        content => "#!/bin/sh\n\n${app_root}/shared/bin/pumacmd.sh restart",
        owner   => $puma_user,
        group   => $puma_user,
        mode    => '0755',
        require => File["${app_root}/shared/bin"]
      }
      file { "${app_root}/shared/bin/reload.sh":
        content => "#!/bin/sh\n\n${app_root}/shared/bin/pumacmd.sh phased-restart",
        owner   => $puma_user,
        group   => $puma_user,
        mode    => '0755',
        require => File["${app_root}/shared/bin"]
      }
      file { "${app_root}/shared/bin/pumacmd.sh":
        content => template('puma/pumacmd.sh.erb'),
        owner   => $puma_user,
        group   => $puma_user,
        mode    => '0755',
        require => File["${app_root}/shared/bin"]
      }
      file { ["${app_root}/shared/bin"]:
        ensure  => directory,
        owner   => $puma_user,
        group   => $puma_user,
        mode    => '0755',
        require => File["${app_root}/shared"]
      }
    }
    default: {
      fail("${puma::service_type} is an unknown service type. \
           Only know sysv, upstart, and systemd.")
    }
  }

  file { $puma_config_path:
    content => template('puma/puma.rb.erb'),
    owner   => $puma_user,
    mode    => '0555',
  }

  file { $puma_stdout_log_path:
    ensure => present,
    owner  => $puma_user,
    mode   => '0666',
  }

  file { $puma_stderr_log_path:
    ensure => present,
    owner  => $puma_user,
    mode   => '0666'
  }

  file { "/usr/local/rvm/rubies/${rvm_ruby}/bin/executable-hooks-uninstaller":
    ensure => link,
    target => "/usr/local/rvm/gems/${rvm_ruby}@${app_name}/wrappers/executable-hooks-uninstaller",
    owner  => $puma_user,
    group  => $puma_user,
  }

  file { "/usr/local/rvm/rubies/${rvm_ruby}/bin/ruby_executable_hooks":
    ensure => link,
    target => "/usr/local/rvm/gems/${rvm_ruby}@${app_name}/bin/ruby_executable_hooks",
    owner  => $puma_user,
    group  => $puma_user,
  }

}
