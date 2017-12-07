use re

fn single-user-setup {
  # Set up single-user Nix (no daemon)
  if (not-eq $E:HOME "") {
    NIX_LINK = ~/.nix-profile
    if (not ?(test -L $NIX_LINK)) {
      echo (edit:styled "creating "$NIX_LINK green) >&2
      _NIX_DEF_LINK = /nix/var/nix/profiles/default
      ln -s $_NIX_DEF_LINK $NIX_LINK
    }
    paths = [
      $NIX_LINK"/bin"
      $NIX_LINK"/sbin"
      $@paths
    ]
    # Subscribe the user to the Nixpkgs channel by default.
    if (not ?(test -e ~/.nix-channels)) {
      echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > ~/.nix-channels
    }
    # Append ~/.nix-defexpr/channels/nixpkgs to $NIX_PATH so that
    # <nixpkgs> paths work when the user has fetched the Nixpkgs
    # channel.
    if (not-eq $E:NIX_PATH "") {
      E:NIX_PATH = $E:NIX_PATH":nixpkgs="$E:HOME"/.nix-defexpr/channels/nixpkgs"
    } else {
      E:NIX_PATH = "nixpkgs="$E:HOME"/.nix-defexpr/channels/nixpkgs"
    }

    # Set $NIX_SSL_CERT_FILE so that Nixpkgs applications like curl work.
    if ?(test -e  /etc/ssl/certs/ca-certificates.crt ) { # NixOS, Ubuntu, Debian, Gentoo, Arch
      E:NIX_SSL_CERT_FILE = /etc/ssl/certs/ca-certificates.crt
    } elif ?(test -e  /etc/ssl/ca-bundle.pem ) { # openSUSE Tumbleweed
      E:NIX_SSL_CERT_FILE = /etc/ssl/ca-bundle.pem
    } elif ?(test -e  /etc/ssl/certs/ca-bundle.crt ) { # Old NixOS
      E:NIX_SSL_CERT_FILE = /etc/ssl/certs/ca-bundle.crt
    } elif ?(test -e  /etc/pki/tls/certs/ca-bundle.crt ) { # Fedora, CentOS
      E:NIX_SSL_CERT_FILE = /etc/pki/tls/certs/ca-bundle.crt
    } elif ?(test -e  $NIX_LINK"/etc/ssl/certs/ca-bundle.crt" ) { # fall back to cacert in Nix profile
      E:NIX_SSL_CERT_FILE = $NIX_LINK"/etc/ssl/certs/ca-bundle.crt"
    } elif ?(test -e  $NIX_LINK"/etc/ca-bundle.crt" ) { # old cacert in Nix profile
      E:NIX_SSL_CERT_FILE = $NIX_LINK"/etc/ca-bundle.crt"
    }
  }
}

fn multi-user-setup {
  # Set up environment for Nix
  # Ported to Elvish from /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

  # Set up secure multi-user builds: non-root users build through the
  # Nix daemon.
  if (or (not-eq $E:USER root) (not ?(test -w /nix/var/nix/db))) {
    E:NIX_REMOTE = daemon
  }

  E:NIX_USER_PROFILE_DIR = "/nix/var/nix/profiles/per-user/"$E:USER
  nix_profiles = [
    "/nix/var/nix/profiles/default"
    $E:HOME"/.nix-profile"
  ]
  E:NIX_PROFILES = (joins " " $nix_profiles)

  # Set up the per-user profile.
  mkdir -m 0755 -p $E:NIX_USER_PROFILE_DIR
  if (not ?(test -O $E:NIX_USER_PROFILE_DIR)) {
    echo (edit:styled "WARNING: bad ownership on $NIX_USER_PROFILE_DIR" yellow) >&2
  }

  if ?(test -w $E:HOME) {
    if (not ?(test -L $E:HOME/.nix-profile)) {
      if (not-eq $E:USER root) {
        ln -s $E:NIX_USER_PROFILE_DIR/profile $E:HOME/.nix-profile
      } else {
        # Root installs in the system-wide profile by default.
        ln -s /nix/var/nix/profiles/default $E:HOME/.nix-profile
      }
    }

    # Subscribe the root user to the NixOS channel by default.
    if (and (eq $E:USER root) (not ?(test -e $E:HOME/.nix-channels))) {
      echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > $E:HOME/.nix-channels
    }

    # Create the per-user garbage collector roots directory.
    NIX_USER_GCROOTS_DIR = "/nix/var/nix/gcroots/per-user/"$E:USER
    mkdir -m 0755 -p $NIX_USER_GCROOTS_DIR
    if (not ?(test -O $NIX_USER_GCROOTS_DIR)) {
      echo (edit:styled "WARNING: bad ownership on $NIX_USER_GCROOTS_DIR" yellow) >&2
    }

    # Set up a default Nix expression from which to install stuff.
    if (or (not ?(test -e $E:HOME/.nix-defexpr)) ?(test -L $E:HOME/.nix-defexpr)) {
      rm -f $E:HOME/.nix-defexpr
      mkdir -p $E:HOME/.nix-defexpr
      if (not-eq $E:USER root) {
        ln -s /nix/var/nix/profiles/per-user/root/channels $E:HOME/.nix-defexpr/channels_root
      }
    }
  }

  E:NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
  E:NIX_PATH = "/nix/var/nix/profiles/per-user/root/channels"
  # E:MANPATH = ~/.nix-profile/share/man
  paths = [
    ~/.nix-profile/bin
    ~/.nix-profile/sbin
    ~/.nix-profile/lib/kde4/libexec
    /nix/var/nix/profiles/default/bin
    /nix/var/nix/profiles/default/sbin
    /nix/var/nix/profiles/default/lib/kde4/libexec
    $@paths
  ]

  #echo (edit:styled "Nix environment ready" green)
}

fn search [@pkgs]{
  pipecmd = cat
  opts = []
  if (eq $pkgs[0] "--json") {
    pipecmd = json_pp
  }
  nix-env -qa $@opts $@pkgs | $pipecmd
}

fn install [@pkgs]{
  nix-env -i $@pkgs
}

fn brew-to-nix {
  brew leaves | each [pkg]{
    echo (edit:styled "Package "$pkg green)
    brew info $pkg
    loop = $true
    while $loop {
      loop = $false
      print (edit:styled $pkg": [R]emove/[Q]uery nix/[K]eep/Remove and [I]nstall with nix? " yellow)
      resp = (head -n1 </dev/tty)
      if (eq $resp "r") {
        brew uninstall --force $pkg
      } elif (eq $resp "q") {
        _ = ?(nix:search --description '.*'$pkg'.*')
        loop = $true
      } elif (eq $resp "i") {
        nix:install $pkg
        brew uninstall --force $pkg
      }
    }
  }
}

fn info [pkg]{
  install-path = nil
  installed = ?(install-path = [(re:split '\s+' (nix-env -q --out-path $pkg 2>/dev/null))][1])
  flag = (if $installed { put "-q" } else { put "-qa" })
  data = (nix-env $flag --json $pkg | from-json)
  top-key = (keys $data | take 1)
  pkg = $data[$top-key]
  meta = $pkg[meta]
  echo-if = [obj key]{ if (has-key $obj $key) { echo $obj[$key] } }
  # Produce the output
  print (edit:styled $pkg[name] yellow)
  if (has-key $meta description) { echo ":" $meta[description] } else { echo "" }
  if (has-key $meta homepage)    { echo (edit:styled "Homepage: " blue) $meta[homepage] }
  if $installed { echo (edit:styled "Installed:" green) $install-path } else { echo (edit:styled "Not installed" red) }
  echo From: (re:replace ':\d+' "" $meta[position])
  if (has-key $meta longDescription) {
    echo ""
    echo $meta[longDescription] | fmt
  }
}
