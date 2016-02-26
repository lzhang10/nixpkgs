{ config, lib, pkgs, ... }:

with lib;

let

  inherit (pkgs) nntp-proxy;

  proxyUser = "nntp-proxy";

  cfg = config.services.nntp-proxy;

  configBool = b: if b then "TRUE" else "FALSE";

  confFile = pkgs.writeText "nntp-proxy.conf" ''
    nntp_server:
    {
      # NNTP Server host and port address
      server = "${cfg.upstreamServer}";
      port = ${toString cfg.upstreamPort};
      # NNTP username
      username = "${cfg.upstreamUser}";
      # NNTP password in clear text
      password = "${cfg.upstreamPassword}";
      # Maximum number of connections allowed by the NNTP
      max_connections = ${toString cfg.upstreamMaxConnections};
    };

    proxy:
    {
      # Local address and port to bind to
      bind_ip = "${cfg.listenAddress}";
      bind_port = ${toString cfg.port};

      # SSL key and cert file
      ssl_key = "${cfg.sslKey}";
      ssl_cert = "${cfg.sslCert}";

      # prohibit users from posting
      prohibit_posting = ${configBool cfg.prohibitPosting};
      # Verbose levels: ERROR, WARNING, NOTICE, INFO, DEBUG
      verbose = "${toUpper cfg.verbosity}";
      # Password is made with: 'mkpasswd -m sha-512 <password>'
      users = (${concatStringsSep ",\n" (mapAttrsToList (username: userConfig:
        ''
          {
              username = "${username}";
              password = "${userConfig.passwordHash}";
              max_connections = ${toString userConfig.maxConnections};
          }
        '') cfg.users)});
    };
  '';

in

{

  ###### interface

  options = {

    services.nntp-proxy = {
      enable = mkEnableOption "NNTP-Proxy";

      upstreamServer = mkOption {
        type = types.str;
        default = "";
        example = "ssl-eu.astraweb.com";
        description = ''
          Upstream server address
        '';
      };

      upstreamPort = mkOption {
        type = types.int;
        default = 563;
        description = ''
          Upstream server port
        '';
      };

      upstreamMaxConnections = mkOption {
        type = types.int;
        default = 20;
        description = ''
          Upstream server maximum allowed concurrent connections
        '';
      };

      upstreamUser = mkOption {
        type = types.str;
        default = "";
        description = ''
          Upstream server username
        '';
      };

      upstreamPassword = mkOption {
        type = types.str;
        default = "";
        description = ''
          Upstream server password
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "[::]";
        description = ''
          Proxy listen address (IPv6 literal addresses need to be enclosed in "[" and "]" characters)
        '';
      };

      port = mkOption {
        type = types.int;
        default = 5555;
        description = ''
          Proxy listen port
        '';
      };

      sslKey = mkOption {
        type = types.str;
        default = "key.pem";
        example = "/path/to/your/key.file";
        description = ''
          Proxy ssl key path
        '';
      };

      sslCert = mkOption {
        type = types.str;
        default = "cert.pem";
        example = "/path/to/your/cert.file";
        description = ''
          Proxy ssl certificate path
        '';
      };

      prohibitPosting = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to prohibit posting to the upstream server
        '';
      };

      verbosity = mkOption {
        type = types.str;
        default = "info";
        example = "error";
        description = ''
          Verbosity level (error, warning, notice, info, debug)
        '';
      };

      users = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            username = mkOption {
              type = types.str;
              default = null;
              description = ''
                Username
              '';
            };

            passwordHash = mkOption {
              type = types.str;
              default = null;
              example = "$6$GtzE7FrpE$wwuVgFYU.TZH4Rz.Snjxk9XGua89IeVwPQ/fEUD8eujr40q5Y021yhn0aNcsQ2Ifw.BLclyzvzgegopgKcneL0";
              description = ''
                SHA-512 password hash (can be generated by 'mkpasswd -m sha-512 <password>')
              '';
            };

            maxConnections = mkOption {
              type = types.int;
              default = 1;
              description = ''
                Maximum number of concurrent connections to the proxy for this user
              '';
            };
          };
        });
        description = ''
          NNTP-Proxy user configuration
        '';

        default = {};
        example = literalExample ''
          "user1" = {
            passwordHash = "$6$1l0t5Kn2Dk$appzivc./9l/kjq57eg5UCsBKlcfyCr0zNWYNerKoPsI1d7eAwiT0SVsOVx/CTgaBNT/u4fi2vN.iGlPfv1ek0";
            maxConnections = 5;
          };
          "anotheruser" = {
            passwordHash = "$6$6lwEsWB.TmsS$W7m1riUx4QrA8pKJz8hvff0dnF1NwtZXgdjmGqA1Dx2MDPj07tI9GNcb0SWlMglE.2/hBgynDdAd/XqqtRqVQ0";
            maxConnections = 7;
          };
        '';
      };
    };

  };

  ###### implementation

  config = mkIf cfg.enable {

    users.extraUsers = singleton
      { name = proxyUser;
        uid = config.ids.uids.nntp-proxy;
        description = "NNTP-Proxy daemon user";
      };

    systemd.services.nntp-proxy = {
      description = "NNTP proxy";
      after = [ "network.target" "nss-lookup.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { User="${proxyUser}"; };
      serviceConfig.ExecStart = "${nntp-proxy}/bin/nntp-proxy ${confFile}";
      preStart = ''
        if [ ! \( -f ${cfg.sslCert} -a -f ${cfg.sslKey} \) ]; then
          ${pkgs.openssl}/bin/openssl req -subj '/CN=AutoGeneratedCert/O=NixOS Service/C=US' \
          -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout ${cfg.sslKey} -out ${cfg.sslCert};
        fi
      '';
    };

  };

}
