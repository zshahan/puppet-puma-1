# puma::rvm
define puma::rvm(
  $rvm_ruby,
  $app_name = $title,
) {
  ensure_resource('class', 'rvm')
  ensure_resource('rvm::system_user', $puma::puma_user)
  ensure_resource('rvm_system_ruby', $rvm_ruby, {'ensure'=>'present'})

  Rvm::System_user[$puma::puma_user]
  -> Rvm_system_ruby[$rvm_ruby]
  -> rvm_gemset {"${rvm_ruby}@${app_name}":
    ensure  => present,
    require => Rvm_system_ruby[$rvm_ruby],
  }
  -> rvm_gem {"${rvm_ruby}@${app_name}/bundler":
    ensure  => present,
  }
}
