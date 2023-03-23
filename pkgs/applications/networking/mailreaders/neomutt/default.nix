{ lib, stdenv, fetchFromGitHub, gettext, makeWrapper, tcl, which
, ncurses, perl , cyrus_sasl, gss, gpgme, libkrb5, libidn, libxml2, notmuch, openssl
, lua, lmdb, libxslt, docbook_xsl, docbook_xml_dtd_42, w3m, mailcap, sqlite, zlib
, pkg-config, zstd, enableZstd ? true, enableMixmaster ? false, enableLua ? false
}:

stdenv.mkDerivation rec {
  version = "20230322";
  pname = "neomutt";

  src = fetchFromGitHub {
    owner  = "neomutt";
    repo   = "neomutt";
    rev    = version;
    sha256 = "sha256-dVNnxfclrwKVVNlblFGb6HysBlMSQc2k8NSlrcn3oug=";
  };

  buildInputs = [
    cyrus_sasl gss gpgme libkrb5 libidn ncurses
    notmuch openssl perl lmdb
    mailcap sqlite
  ]
  ++ lib.optional enableZstd zstd
  ++ lib.optional enableLua lua;

  nativeBuildInputs = [
    docbook_xsl docbook_xml_dtd_42 gettext libxml2 libxslt.bin makeWrapper tcl which zlib w3m
    pkg-config
  ];

  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace auto.def --replace /usr/sbin/sendmail sendmail
    substituteInPlace contrib/smime_keys \
      --replace /usr/bin/openssl ${openssl}/bin/openssl

    for f in doc/*.{xml,xsl}*  ; do
      substituteInPlace $f \
        --replace http://docbook.sourceforge.net/release/xsl/current     ${docbook_xsl}/share/xml/docbook-xsl \
        --replace http://www.oasis-open.org/docbook/xml/4.2/docbookx.dtd ${docbook_xml_dtd_42}/xml/dtd/docbook/docbookx.dtd
    done


    # allow neomutt to map attachments to their proper mime.types if specified wrongly
    # and use a far more comprehensive list than the one shipped with neomutt
    substituteInPlace send/sendlib.c \
      --replace /etc/mime.types ${mailcap}/etc/mime.types
  '';

  configureFlags = [
    "--enable-autocrypt"
    "--gpgme"
    "--gss"
    "--lmdb"
    "--notmuch"
    "--ssl"
    "--sasl"
    "--with-homespool=mailbox"
    "--with-mailpath="
    # To make it not reference .dev outputs. See:
    # https://github.com/neomutt/neomutt/pull/2367
    "--disable-include-path-in-cflags"
    "--zlib"
  ]
  ++ lib.optional enableZstd "--zstd"
  ++ lib.optional enableLua "--lua"
  ++ lib.optional enableMixmaster "--mixmaster";

  postInstall = ''
    wrapProgram "$out/bin/neomutt" --prefix PATH : "$out/libexec/neomutt"
  '';

  doCheck = true;

  preCheck = ''
    cp -r ${fetchFromGitHub {
      owner = "neomutt";
      repo = "neomutt-test-files";
      rev = "1569b826a56c39fd09f7c6dd5fc1163ff5a356a2";
      sha256 = "sha256-MaH2zEH1Wq3C0lFxpEJ+b/A+k2aKY/sr1EtSPAuRPp8=";
    }} $(pwd)/test-files
    chmod -R +w test-files
    (cd test-files && ./setup.sh)

    export NEOMUTT_TEST_DIR=$(pwd)/test-files
  '';

  checkTarget = "test";
  postCheck = "unset NEOMUTT_TEST_DIR";

  meta = with lib; {
    description = "A small but very powerful text-based mail client";
    homepage    = "http://www.neomutt.org";
    license     = licenses.gpl2Plus;
    maintainers = with maintainers; [ cstrahan erikryb jfrankenau vrthra ma27 raitobezarius ];
    platforms   = platforms.unix;
  };
}
