define puma::app (
    $app_name           = $title,
    $app_root           = sprintf($puma::app_root_spf, $title),
    $puma_user          = $puma::puma_user,
    $www_user           = $puma::www_user,
    $min_threads        = $puma::min_threads,
    $max_threads        = $puma::max_threads,
    $port               = $puma::port,
    $workers            = $puma::workers,
    $init_active_record = $puma::init_active_record,
    $preload_app        = $puma::preload_app,
    $env                = $puma::env,
    $rvm_ruby           = $puma::rvm_ruby,
    $restart_command    = $puma::restart_command,
) {
	$puma_pid_path		= sprintf($puma::puma_pid_path_spf, $app_name)
	$puma_socket_path	= sprintf($puma::puma_socket_path_spf, $app_name)
	$puma_config_path	= sprintf($puma::puma_config_path_spf, $app_name)
	$puma_stdout_log_path = sprintf($puma::puma_stdout_log_path_spf, $app_name)
	$puma_stderr_log_path = sprintf($puma::puma_stderr_log_path_spf, $app_name)

	if $rvm_ruby {
		puma::rvm {$app_name:
			rvm_ruby => $rvm_ruby,
		}
		$ruby_exec_prefix = "/usr/local/rvm/bin/rvm $rvm_ruby@$app_name do "
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
		owner => $puma_user,
		group => $www_user,
		mode => 'ug=rwxs,o-o',
	}
	
	# For the rest, just ensure reachable
	ensure_resource('file', $other_conf_dirs, {
		ensure => directory,
		mode => 'a+x',
	})

	case $puma::service_type {
		'upstart': {
			# Fancy upstart job - can respawn dead ruby procs
			ensure_resource('class', 'upstart')
			upstart::job { $app_name:
				description    	=> "$app_name - puma application",
				respawn        	=> true,
				respawn_limit  	=> '5 10',
				user           	=> $puma_user,
				group          	=> $puma_user,
				chdir          	=> $app_root,
				env 		=> $env,
				exec            => "$ruby_exec_prefix bundle exec puma -C $puma_config_path",
				require		=> File[$puma_config_path],
                                pre_start       => "sudo mkdir -p $puma_pid_path\nsudo chown -R $puma_user:$puma_user $puma_pid_path"
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
				content		=> template("puma/app_init_script.erb"),
				owner		=> "root",
				group 		=> "root",
				mode		=> "0755",
			}
			service { $app_name:
				ensure => running,
				enable => true,
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
		default: {
			fail("${puma::service_type} is an unknown service type. Only know sysv and upstart.")
		}
	}

	file { $puma_config_path:
		content		=> template("puma/puma.rb.erb"),
		owner 		=> $puma_user,
		mode		=> '0555',
	}

	file { $puma_stdout_log_path:
		ensure 	=> present,
		owner	=> $puma_user,
		mode 	=> "0666",
	}

	file { $puma_stderr_log_path:
		ensure 	=> present,
		owner	=> $puma_user,
		mode 	=> '0666'
	}
	
	


}
