# puma

## Overview

Configure puma servers for Ruby-on-Rails apps.

Installs the application as a system service (using `upstart` or good old `sysv` - `upstart` has the benefit of not requiring a supervisor for restarting rails).

Configurations for Debian-family systems included, patches welcome for other OSes.

For a more comprehensive Rails deployment recipe which makes use of this module, see [`deversus-rails`](https://forge.puppetlabs.com/deversus/rails).

## Optional Dependencies

* RVM support requires `maestrodev-rvm (~> v1.5.5)` .
* NGINX support requires `jfryman-nginx (~> v0.0.9)`.

Patches welcome for servers other than NGINX.

## Usage


```puppet
# Debian default values shown (except rvm, which defaults to false)
puma::app {'myapp':
    app_name           => 'myapp',
    app_root           => '/var/www/myapp/current',
    puma_user          => 'puma',
    www_user           => 'www-data',
    min_threads        => 1,
    max_threads        => 16,
    port               => 9292,
    workers            => 1,
    init_active_record => false,
    preload_app        => true,
    rails_env          => 'production',
    rvm_ruby           => 'ruby-2.0.0-p0',
    restart_command    => 'puma',
}

```

This would install a service called `myapp` (in `/etc/init` if `upstart` is used,  `/etc/init.d` otherwise). Socket and PID files will be put in `/var/run/myapp/`. Log files will be put in `/var/log/myapp.puma.stdout.log` etc.

An RVM ruby environment for `ruby-2.0.0-p0` will be installed if needed and used to launch puma. (with `rvm_ruby => false`, system ruby will be used)


### Configuring NGINX

A convenience resource for configuring NGINX for the above setup is provided:

```puppet
# Debian default values shown
puma::nginxconfig {'myapp':
    server_name     => ['www.myapp.com'],
    public_root     => '/var/www/myapp/current/public',
}
```

This will create the necessary NGINX vhost and location configurations to serve a puma rails app.
