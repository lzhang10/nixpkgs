{ stdenv, fetchgit, fetchpatch, cups, libssh, libXpm, nx-libs, openldap, openssh
, mkDerivation, qtbase, qtsvg, qtx11extras, qttools, phonon, pkgconfig }:

mkDerivation {
  pname = "x2goclient";
  version = "unstable-2019-07-24";

  src = fetchgit {
   url = "git://code.x2go.org/x2goclient.git";
   rev = "704c4ab92d20070dd160824c9b66a6d1c56dcc49";
   sha256 = "1pndp3lfzwifyxqq0gps3p1bwakw06clbk6n8viv020l4bsfmq5f";
  };

  patches = [
    (fetchpatch {
      sha256 = "1ljsryswqvd27fvhwyg3sw3qm2xi0nhz6lrp3q7sb3imi9rjwh2m";
      name = "x2goclient-resume-after-suspending.patch";
      url = "https://gist.githubusercontent.com/lzhang10/59f12e5df1ae78e4d3a6ddda75f5ab32/raw/66d9fcc60327bae5d7fd6e9b62e2a0a2f9df8588/x2goclient-resume-after-suspending.patch";
    })
  ];

  buildInputs = [ cups libssh libXpm nx-libs openldap openssh
                  qtbase qtsvg qtx11extras qttools phonon pkgconfig ];

  postPatch = ''
     substituteInPlace Makefile \
       --replace "SHELL=/bin/bash" "SHELL=$SHELL" \
       --replace "lrelease-qt4" "${qttools.dev}/bin/lrelease" \
       --replace "qmake-qt4" "${qtbase.dev}/bin/qmake" \
       --replace "-o root -g root" ""
  '';

  makeFlags = [ "PREFIX=$(out)" "ETCDIR=$(out)/etc" "build_client" "build_man" ];

  enableParallelBuilding = true;

  installTargets = [ "install_client" "install_man" ];

  qtWrapperArgs = [ ''--suffix PATH : ${nx-libs}/bin:${openssh}/libexec'' ];

  meta = with stdenv.lib; {
    description = "Graphical NoMachine NX3 remote desktop client";
    homepage = http://x2go.org/;
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
