# == Class: readline
#
# This installs the readline library from source.
#
class readline(
  $autotools_environment = {},
  $file_cache_dir = params_lookup('file_cache_dir', 'global'),
  $make_notify = undef,
  $prefix = params_lookup('prefix'),
) {
  require build_essential

  $source_filename  = "readline-6.3.tar.gz"
  $source_url = "http://ftpmirror.gnu.org/readline/${source_filename}"
  $source_file_path = "${file_cache_dir}/${source_filename}"
  $source_dir_name  = regsubst($source_filename, '^(.+?)\.tar\.gz$', '\1')
  $source_dir_path  = "${file_cache_dir}/${source_dir_name}"

  $lib_version = "6"

  # Determine if we have an extra environmental variables we need to set
  # based on the operating system.
  if $operatingsystem == 'Darwin' {
    $extra_autotools_environment = {
      "CFLAGS"  => "-arch x86_64",
      "LDFLAGS" => "-arch x86_64",
    }
  } else {
    $extra_autotools_environment = {}
  }

  # Merge our environments.
  $real_autotools_environment = autotools_merge_environments(
    $autotools_environment, $extra_autotools_environment)

  #------------------------------------------------------------------
  # Compile
  #------------------------------------------------------------------
  wget::fetch { "readline":
    source      => $source_url,
    destination => $source_file_path,
  }

  exec { "untar-readline":
    command => "tar xvzf ${source_file_path}",
    creates => $source_dir_path,
    cwd     => $file_cache_dir,
    require => Wget::Fetch["readline"],
  }

  if $operatingsystem == 'Darwin' {
    patch { "patch-readline":
      content     => template('readline/patch.mac.diff'),
      prefixlevel => "1",
      cwd         => $source_dir_path,
      require     => Exec["untar-readline"],
      before      => Autotools["readline"],
    }
  }

  autotools { "readline":
    configure_flags  => "--prefix=${prefix}",
    cwd              => $source_dir_path,
    environment      => $real_autotools_environment,
    install_sentinel => "${prefix}/lib/libreadline.a",
    make_notify      => $make_notify,
    make_sentinel    => "${source_dir_path}/libreadline.a",
    require          => Exec["untar-readline"],
  }

  if $kernel == 'Darwin' {
    $libreadline_paths = [
      "${prefix}/lib/libreadline.dylib",
      "${prefix}/lib/libreadline.${lib_version}.dylib",
    ]
    $lib_path = "@rpath/libreadline.${lib_version}.dylib"
    $embedded_dir = "${prefix}/lib"

    vagrant_substrate::staging::darwin_rpath { $libreadline_paths:
      new_lib_path => $lib_path,
      remove_rpath => $embedded_dir,
      require => Autotools["readline"],
      subscribe => Autotools["readline"],
    }
  }

  if $kernel == 'Linux' {
    $libreadline_paths = [
      "${prefix}/lib/libreadline.so",
    ]

    vagrant_substrate::staging::linux_chrpath{ $libreadline_paths:
      require => Autotools["readline"],
      subscribe => Autotools["readline"],
    }
  }
}
