;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016, 2017, 2018, 2019 Ricardo Wurmus <ricardo.wurmus@mdc-berlin.de>
;;;
;;; This file is NOT part of GNU Guix, but is supposed to be used with GNU
;;; Guix and thus has the same license.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (bimsb packages variants)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (gnu packages)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages bioinformatics)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages icu4c)
  #:use-module (gnu packages image)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages sdl)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages statistics)
  #:use-module (gnu packages shells)
  #:use-module (gnu packages wxwidgets)
  #:use-module (bimsb packages staging))

;; An older version of Perl is required for Bcl2Fastq version 1.x
(define-public perl-5.14
  (package (inherit perl)
    (name "perl")
    (version "5.14.4")
    (source (origin
             (method url-fetch)
             (uri (string-append "mirror://cpan/src/5.0/perl-"
                                 version ".tar.gz"))
             (sha256
              (base32
               "1js47zzna3v38fjnirf2vq6y0rjp8m86ysj5vagzgkig956d8gw0"))
             (patches (map search-patch
                           '("perl-5.14-no-sys-dirs.patch"
                             "perl-5.14-autosplit-default-time.patch"
                             "perl-5.14-module-pluggable-search.patch")))))
    (arguments
     '(#:tests? #f
       #:phases
       (modify-phases %standard-phases
         (replace 'configure
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out  (assoc-ref outputs "out"))
                   (libc (assoc-ref inputs "libc")))
               ;; Use the right path for `pwd'.
               (substitute* "dist/Cwd/Cwd.pm"
                 (("/bin/pwd")
                  (which "pwd")))

               (zero?
                (system* "./Configure"
                         (string-append "-Dprefix=" out)
                         (string-append "-Dman1dir=" out "/share/man/man1")
                         (string-append "-Dman3dir=" out "/share/man/man3")
                         "-de" "-Dcc=gcc"
                         "-Uinstallusrbinperl"
                         "-Dinstallstyle=lib/perl5"
                         "-Duseshrplib"
                         (string-append "-Dlocincpth=" libc "/include")
                         (string-append "-Dloclibpth=" libc "/lib")

                         ;; Force the library search path to contain only libc
                         ;; because it is recorded in Config.pm and
                         ;; Config_heavy.pl; we don't want to keep a reference
                         ;; to everything that's in $LIBRARY_PATH at build
                         ;; time (Binutils, bzip2, file, etc.)
                         (string-append "-Dlibpth=" libc "/lib")
                         (string-append "-Dplibpth=" libc "/lib"))))))

         (add-before 'strip 'make-shared-objects-writable
           (lambda* (#:key outputs #:allow-other-keys)
             ;; The 'lib/perl5' directory contains ~50 MiB of .so.  Make them
             ;; writable so that 'strip' actually strips them.
             (let* ((out (assoc-ref outputs "out"))
                    (lib (string-append out "/lib")))
               (for-each (lambda (dso)
                           (chmod dso #o755))
                         (find-files lib "\\.so$"))))))))))

;; For Harm.
(define-public perl-5.24
  (package
    (name "perl")
    (version "5.24.0")
    (source (origin
             (method url-fetch)
             (uri (string-append "mirror://cpan/src/5.0/perl-"
                                 version ".tar.gz"))
             (sha256
              (base32
               "00jj8zr8fnihrxxhl8h936ssczv5x86qb618yz1ig40d1rp0qhvy"))
             (patches (search-patches
                       "perl-5.24-no-sys-dirs.patch"
                       "perl-autosplit-default-time.patch"
                       "perl-deterministic-ordering.patch"
                       "perl-reproducible-build-date.patch"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f
       #:configure-flags
       (let ((out  (assoc-ref %outputs "out"))
             (libc (assoc-ref %build-inputs "libc")))
         (list
          (string-append "-Dprefix=" out)
          (string-append "-Dman1dir=" out "/share/man/man1")
          (string-append "-Dman3dir=" out "/share/man/man3")
          "-de" "-Dcc=gcc"
          "-Uinstallusrbinperl"
          "-Dinstallstyle=lib/perl5"
          "-Duseshrplib"
          (string-append "-Dlocincpth=" libc "/include")
          (string-append "-Dloclibpth=" libc "/lib")
          "-Dusethreads"))
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'setup-configure
           (lambda _
             ;; Use the right path for `pwd'.
             (substitute* "dist/PathTools/Cwd.pm"
               (("/bin/pwd")
                (which "pwd")))

             ;; Build in GNU89 mode to tolerate C++-style comment in libc's
             ;; <bits/string3.h>.
             (substitute* "cflags.SH"
               (("-std=c89")
                "-std=gnu89"))
             #t))
         (replace 'configure
           (lambda* (#:key configure-flags #:allow-other-keys)
             (format #t "Perl configure flags: ~s~%" configure-flags)
             (zero? (apply system* "./Configure" configure-flags))))
         (add-before
          'strip 'make-shared-objects-writable
          (lambda* (#:key outputs #:allow-other-keys)
            ;; The 'lib/perl5' directory contains ~50 MiB of .so.  Make them
            ;; writable so that 'strip' actually strips them.
            (let* ((out (assoc-ref outputs "out"))
                   (lib (string-append out "/lib")))
              (for-each (lambda (dso)
                          (chmod dso #o755))
                        (find-files lib "\\.so$")))))

         (add-after 'install 'remove-extra-references
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out     (assoc-ref outputs "out"))
                    (libc    (assoc-ref inputs "libc"))
                    (config1 (car (find-files (string-append out "/lib/perl5")
                                              "^Config_heavy\\.pl$")))
                    (config2 (find-files (string-append out "/lib/perl5")
                                         "^Config\\.pm$")))
               ;; Force the library search path to contain only libc because
               ;; it is recorded in Config.pm and Config_heavy.pl; we don't
               ;; want to keep a reference to everything that's in
               ;; $LIBRARY_PATH at build time (GCC, Binutils, bzip2, file,
               ;; etc.)
               (substitute* config1
                 (("^incpth=.*$")
                  (string-append "incpth='" libc "/include'\n"))
                 (("^(libpth|plibpth|libspath)=.*$" _ variable)
                  (string-append variable "='" libc "/lib'\n")))

               (for-each (lambda (file)
                           (substitute* config2
                             (("libpth => .*$")
                              (string-append "libpth => '" libc
                                             "/lib',\n"))))
                         config2)
               #t))))))
    (native-search-paths (list (search-path-specification
                                (variable "PERL5LIB")
                                (files '("lib/perl5/site_perl")))))
    (synopsis "Implementation of the Perl programming language")
    (description
     "Perl 5 is a highly capable, feature-rich programming language with over
24 years of development.")
    (home-page "http://www.perl.org/")
    (license license:gpl1+)))

(define (other-perl-package-name other-perl)
  "Return a procedure that returns NAME with a new prefix for
OTHER-PERL instead of \"perl-\", when applicable."
  (let ((other-perl-version (version-major+minor
                             (package-version other-perl))))
    (lambda (name)
      (if (string-prefix? "perl-" name)
          (string-append "perl" other-perl-version "-"
                         (string-drop name
                                      (string-length "perl-")))
          name))))

(define (perl-5.14-package-name name)
  (other-perl-package-name perl-5.14))

(define-public (package-for-other-perl other-perl pkg)
  ;; This is a procedure to replace PERL by OTHER-PERL, recursively.
  ;; It also ensures that rewritten packages are built with OTHER-PERL.
  (let* ((rewriter (package-input-rewriting `((,perl . ,other-perl))
                                            (other-perl-package-name other-perl)))
         (new (rewriter pkg)))
    (package (inherit new)
      (arguments `(#:perl ,other-perl
                   #:tests? #f ; oh well...
                   ,@(package-arguments new))))))

(define-public (package-for-perl-5.14 pkg)
  ;; This is a procedure to replace PERL by PERL-5.14, recursively.
  ;; It also ensures that rewritten packages are built with PERL-5.14.
  (let* ((rewriter (package-input-rewriting `((,perl . ,perl-5.14))
                                            perl-5.14-package-name))
         (new (rewriter pkg)))
    (package (inherit new)
      (arguments `(#:perl ,perl-5.14
                   #:tests? #f
                   ,@(package-arguments new))))))

(define-public boost-1.58
  (package (inherit boost)
    (name "boost")
    (version "1.58.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://sourceforge/boost/boost/" version "/boost_"
                    (string-map (lambda (x) (if (eq? x #\.) #\_ x)) version)
                    ".tar.bz2"))
              (sha256
               (base32
                "1rfkqxns60171q62cppiyzj8pmsbwp1l8jd7p6crriryqd7j1z7x"))))
    (native-inputs
     `(("perl" ,perl)
       ("python" ,python-2)
       ("tcsh" ,tcsh)))
    (arguments
     `(#:tests? #f ; TODO
       #:make-flags
       (list "threading=multi" "link=shared"

             ;; Set the RUNPATH to $libdir so that the libs find each other.
             (string-append "linkflags=-Wl,-rpath="
                            (assoc-ref %outputs "out") "/lib")

             ;; Boost's 'context' library is not yet supported on mips64, so
             ;; we disable it.  The 'coroutine' library depends on 'context',
             ;; so we disable that too.
             ,@(if (string-prefix? "mips64" (or (%current-target-system)
                                                (%current-system)))
                   '("--without-context"
                     "--without-coroutine" "--without-coroutine2")
                   '()))
       #:phases
       (modify-phases %standard-phases
         (delete 'bootstrap)
         (replace 'configure
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (substitute* '("libs/config/configure"
                              "libs/spirit/classic/phoenix/test/runtest.sh"
                              "tools/build/doc/bjam.qbk"
                              "tools/build/src/engine/execunix.c"
                              "tools/build/src/engine/Jambase"
                              "tools/build/src/engine/jambase.c")
                 (("/bin/sh") (which "sh")))

               (setenv "SHELL" (which "sh"))
               (setenv "CONFIG_SHELL" (which "sh"))

               (zero? (system* "./bootstrap.sh"
                               (string-append "--prefix=" out)
                               "--with-toolset=gcc")))))
         (replace 'build
           (lambda* (#:key outputs make-flags #:allow-other-keys)
             (zero? (apply system* "./b2"
                           (format #f "-j~a" (parallel-job-count))
                           make-flags))))
         (replace 'install
           (lambda* (#:key outputs make-flags #:allow-other-keys)
             (zero? (apply system* "./b2" "install" make-flags)))))))))

(define-public boost-1.55
  (package (inherit boost-1.58)
    (name "boost")
    (version "1.55.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://sourceforge/boost/boost/" version "/boost_"
                    (string-map (lambda (x) (if (eq? x #\.) #\_ x)) version)
                    ".tar.bz2"))
              (sha256
               (base32
                "0lkv5dzssbl5fmh2nkaszi8x9qbj80pr4acf9i26sj3rvlih1w7z"))))
    (arguments
     `(#:tests? #f ; TODO
       #:make-flags
       (list "threading=multi" "link=shared"

             ;; Set the RUNPATH to $libdir so that the libs find each other.
             (string-append "linkflags=-Wl,-rpath="
                            (assoc-ref %outputs "out") "/lib")

             ;; Boost's 'context' library is not yet supported on mips64, so
             ;; we disable it.  The 'coroutine' library depends on 'context',
             ;; so we disable that too.
             ,@(if (string-prefix? "mips64" (or (%current-target-system)
                                                (%current-system)))
                   '("--without-context"
                     "--without-coroutine" "--without-coroutine2")
                   '()))
       #:phases
       (modify-phases %standard-phases
         (delete 'bootstrap)
         (replace 'configure
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (substitute* '("libs/config/configure"
                              "libs/spirit/classic/phoenix/test/runtest.sh"
                              "tools/build/v2/doc/bjam.qbk"
                              "tools/build/v2/engine/execunix.c"
                              "tools/build/v2/engine/Jambase"
                              "tools/build/v2/engine/jambase.c")
                 (("/bin/sh") (which "sh")))

               (setenv "SHELL" (which "sh"))
               (setenv "CONFIG_SHELL" (which "sh"))

               (zero? (system* "./bootstrap.sh"
                               (string-append "--prefix=" out)
                               "--with-toolset=gcc")))))
         (replace 'build
           (lambda* (#:key outputs make-flags #:allow-other-keys)
             (zero? (apply system* "./b2"
                           (format #f "-j~a" (parallel-job-count))
                           make-flags))))
         (replace 'install
           (lambda* (#:key outputs make-flags #:allow-other-keys)
             (zero? (apply system* "./b2" "install" make-flags)))))))
    (native-inputs
     `(("gcc-4" ,gcc-4.9)))))

(define-public boost-1.44
  (package (inherit boost-1.55)
    (name "boost")
    (version "1.44.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://sourceforge/boost/boost/" version "/boost_"
                    (string-map (lambda (x) (if (eq? x #\.) #\_ x)) version)
                    ".tar.bz2"))
              (sha256
               (base32
                "1nvq36mvzr1fr85q0jh86rk3bk65s1y55jgqgzfg3lcpkl12ihs5"))))
    (arguments
     `(#:tests? #f
       #:make-flags
       (list "threading=multi" "link=shared"
	     (string-append "-sICU_PATH=" (assoc-ref %build-inputs "icu4c"))
             "-sHAVE_ICU=1"
             ;; Set the RUNPATH to $libdir so that the libs find each other.
             (string-append "linkflags=-Wl,-rpath="
                            (assoc-ref %outputs "out") "/lib"))
       #:phases
       (modify-phases %standard-phases
         (delete 'bootstrap)
         ;; See https://svn.boost.org/trac/boost/ticket/6165
         (add-after 'unpack 'fix-threads-detection
           (lambda _
             (substitute* "boost/config/stdlib/libstdcpp3.hpp"
               (("_GLIBCXX_HAVE_GTHR_DEFAULT")
                "_GLIBCXX_HAS_GTHREADS"))
             #t))
         ;; See https://svn.boost.org/trac/boost/ticket/6940
         (add-after 'unpack 'fix-TIME_UTC
           (lambda _
             (substitute* '("libs/interprocess/test/util.hpp"
                            "libs/interprocess/test/condition_test_template.hpp"
                            "libs/spirit/classic/test/grammar_mt_tests.cpp"
                            "libs/spirit/classic/test/owi_mt_tests.cpp"
                            "libs/thread/src/pthread/thread.cpp"
                            "libs/thread/src/pthread/timeconv.inl"
                            "libs/thread/src/win32/timeconv.inl"
                            "libs/thread/test/util.inl"
                            "libs/thread/test/test_xtime.cpp"
                            "libs/thread/example/xtime.cpp"
                            "libs/thread/example/tennis.cpp"
                            "libs/thread/example/starvephil.cpp"
                            "libs/thread/example/thread.cpp"
                            "boost/thread/xtime.hpp")
               (("TIME_UTC") "TIME_UTC_"))
             #t))
         (replace 'configure
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (substitute* '("libs/config/configure"
                              "libs/spirit/classic/phoenix/test/runtest.sh"
                              "tools/jam/doc/bjam.qbk"
                              "tools/jam/src/execunix.c"
                              "tools/jam/src/Jambase"
                              "tools/jam/src/jambase.c")
                 (("/bin/sh") (which "sh")))

               (setenv "SHELL" (which "sh"))
               (setenv "CONFIG_SHELL" (which "sh"))

               (zero? (system* "./bootstrap.sh"
                               (string-append "--prefix=" out)
                               "--with-toolset=gcc")))))
         (replace 'build
           (lambda* (#:key outputs make-flags #:allow-other-keys)
             (zero? (apply system* "./bjam"
                           (format #f "-j~a" (parallel-job-count))
                           make-flags))))
         (replace 'install
           (lambda* (#:key outputs make-flags #:allow-other-keys)
	     (zero? (apply system* "./bjam" "install" make-flags)))))))
    (inputs
     `(("icu4c" ,icu4c)
       ,@(package-inputs boost-1.55)))
    (native-inputs
     `(("gcc" ,gcc-4.9)
       ,@(package-native-inputs boost-1.55)))))

(define-public rsem-latest
  (package (inherit rsem)
    (name "rsem")
    (version "1.3.0")
    (source
     (origin
       (method url-fetch)
       (uri
        (string-append "https://github.com/deweylab/RSEM/archive/v"
                       version ".tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32 "17y0496qar4hjs15pvrwp7d3svjdapl6akcp0iakg4564np6lxx6"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; Remove bundled copy of boost.  We cannot remove the
           ;; bundled version of samtools because rsem uses a modified
           ;; version of it.
           (delete-file-recursively "boost")
           #t))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f ;no "check" target
       #:make-flags
       (list (string-append "BOOST="
                            (assoc-ref %build-inputs "boost")
                            "/include/"))
       #:phases
       (modify-phases %standard-phases
         ;; No "configure" script.
         (replace 'configure
           (lambda _
             (substitute* '("samtools-1.3/configure"
                            "samtools-1.3/htslib-1.3/configure")
               (("/bin/sh") (which "sh")))
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (string-append (assoc-ref outputs "out")))
                    (bin (string-append out "/bin/"))
                    (perl (string-append out "/lib/perl5/site_perl")))
               (mkdir-p bin)
               (mkdir-p perl)
               (for-each (lambda (file)
                           (copy-file file
                                      (string-append bin (basename file))))
                         (find-files "." "rsem-.*"))
               (copy-file "rsem_perl_utils.pm"
                          (string-append perl "/rsem_perl_utils.pm")))
             #t))
         (add-after 'install 'wrap-program
          (lambda* (#:key outputs #:allow-other-keys)
            (let ((out (assoc-ref outputs "out")))
              (for-each (lambda (prog)
                          (wrap-program (string-append out "/bin/" prog)
                            `("PERL5LIB" ":" prefix
                              (,(string-append out "/lib/perl5/site_perl")))))
                        '("rsem-plot-transcript-wiggles"
                          "rsem-calculate-expression"
                          "rsem-generate-ngvector"
                          "rsem-run-ebseq"
                          "rsem-prepare-reference")))
            #t)))))
    (inputs
     `(("boost" ,boost)
       ("ncurses" ,ncurses)
       ("r" ,r)
       ("perl" ,perl)
       ("zlib" ,zlib)))))

;; For Benedikt
(define-public python-pysam-0.9
  (package (inherit python-pysam)
    (name "python-pysam")
    (version "0.9.1.4")
    (source (origin
              (method url-fetch)
              ;; Test data is missing on PyPi.
              (uri (string-append
                    "https://github.com/pysam-developers/pysam/archive/v"
                    version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "0y41ssbg6nvn2jgcbnrvkzblpjcwszaiv1rgyd8dwzjkrbfsgsmc"))
              (modules '((guix build utils)))
              (snippet
               ;; Drop bundled htslib. TODO: Also remove samtools and bcftools.
               '(delete-file-recursively "htslib"))))
    (arguments
     `(#:phases
       (modify-phases %standard-phases
          (add-before 'build 'set-flags
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "HTSLIB_MODE" "external")
              (setenv "HTSLIB_LIBRARY_DIR"
                      (string-append (assoc-ref inputs "htslib") "/lib"))
              (setenv "HTSLIB_INCLUDE_DIR"
                      (string-append (assoc-ref inputs "htslib") "/include"))
              (setenv "LDFLAGS" "-lncurses")
              (setenv "CFLAGS" "-D_CURSES_LIB=1")
              #t))
          (delete 'check))))))

(define-public python2-pysam-0.9
  (package-with-python2 python-pysam-0.9))

(define-public htslib-1.0
  (package (inherit htslib)
    (name "htslib")
    (version "1.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/samtools/htslib/"
                                  "archive/" version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "1a483cqlhs9k8gjdyb78jkrpilhz2qyyvgrgr8bhy11mpki8vflk"))))
    (arguments
     `(#:make-flags
       (list (string-append "prefix=" (assoc-ref %outputs "out")))
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (add-after 'unpack 'patch-tests
           (lambda _
             (substitute* "test/test.pl"
               (("/bin/bash") (which "bash")))
             #t)))))))

;; Needed for pacbio-htslib
(define-public htslib-1.1
  (package (inherit htslib-1.0)
    (name "htslib")
    (version "1.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/samtools/htslib/"
                                  "archive/" version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "0gwj4mzrys5bs7r8h3fl7w2qfzwbvbby6qmgzj552di3hqc7j2pb"))))))

(define-public htslib-1.2.1
  (package (inherit htslib)
    (name "htslib")
    (version "1.2.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/samtools/htslib/"
                                  "releases/download/"
                                  version "/htslib-"
                                  version ".tar.bz2"))
              (sha256
               (base32
                "1c32ssscbnjwfw3dra140fq7riarp2x990qxybh34nr1p5r17nxx"))))))

(define-public guix-for-big-servers
  (package (inherit guile2.0-guix)
    (name "guix-for-big-servers")
    (arguments '(#:tests? #f))))

;; A different version of MACS2 for Rebecca
(define-public macs/rebecca
  (package (inherit macs)
    (version "2.1.0.20150420.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "MACS2" version))
       (sha256
        (base32
         "1zpxn9nxmfwj8zr8b4gjrx8j81mijgjmagl4prpkghphfbziwraw"))))))

(define-public bedtools-2.23.0
  (package
    (inherit bedtools)
    (version "2.23.0")
    (name "bedtools")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/arq5x/bedtools2/archive/v"
                           version ".tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32
         "0mk0lg3bl6k7kbn675hinwby3jrb17mml7nms4srikhi3mbamb4x"))))
    (arguments
     '(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((bin (string-append (assoc-ref outputs "out") "/bin/")))
               (for-each (lambda (file)
                           (install-file file bin))
                         (find-files "bin" ".*")))
             #t)))))))

;; Patched version of bedtools 2.25.0, which segfaults on some
;; RCAS/dorina test datasets in Bed6+ format.
(define-public bedtools/patched
  (package
    (inherit bedtools)
    (name "bedtools")
    (version "2.25.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/arq5x/bedtools2/archive/v"
                           version ".tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32
         "1ywcy3yfwzhl905b51l0ffjia55h75vv3mw5xkvib04pp6pj548m"))
       (patches (list (search-patch "bedtools-fix-null-segfault.patch")))))
    (arguments
     '(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((bin (string-append (assoc-ref outputs "out") "/bin/")))
               (for-each (lambda (file)
                           (install-file file bin))
                         (find-files "bin" ".*")))
             #t)))))))

(define-public samtools-1.1
  (package
    (inherit samtools-0.1)
    (version "1.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://sourceforge/samtools/samtools/"
                           version "/samtools-" version ".tar.bz2"))
       (sha256
        (base32
         "1y5p2hs4gif891b4ik20275a8xf3qrr1zh9wpysp4g8m0g1jckf2"))))))

(define-public htslib-1.3
  (package
    (inherit htslib)
    (version "1.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/samtools/htslib/releases/download/"
                    version "/htslib-" version ".tar.bz2"))
              (sha256
               (base32
                "1rja282fwdc25ql6izkhdyh8ppw8x2fs0w0js78zgkmqjlikmma9"))))))

(define-public htslib-1.4
  (package
    (inherit htslib)
    (version "1.4.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/samtools/htslib/releases/download/"
                    version "/htslib-" version ".tar.bz2"))
              (sha256
               (base32
                "1crkk79kgxcmrkmh5f58c4k93w4rz6lp97sfsq3s6556zxcxvll5"))))))

(define-public samtools-1.3
  (package
    (inherit samtools)
    (version "1.3.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://sourceforge/samtools/samtools/"
                           version "/samtools-" version ".tar.bz2"))
       (sha256
        (base32
         "0znnnxc467jbf1as2dpskrjhfh8mbll760j6w6rdkwlwbqsp8gbc"))))
    (inputs
     `(("htslib" ,htslib-1.3)
       ,@(package-inputs samtools)))))

(define-public samtools-1.4
  (package (inherit samtools)
    (version "1.4.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://sourceforge/samtools/samtools/"
                           version "/samtools-" version ".tar.bz2"))
       (sha256
        (base32
         "0vzxjm5vkgvzynl7cssm1l560rqs2amdaib1x8sp2ch9b7bxx9xx"))))
    (inputs
     `(("htslib" ,htslib-1.4)
       ,@(package-inputs samtools)))))

(define-public samtools-0
  (package (inherit samtools)
    (version "0.1.8")
    (source
     (origin
       (method url-fetch)
       (uri
        (string-append "mirror://sourceforge/samtools/samtools/"
                       version "/samtools-" version ".tar.bz2"))
       (sha256
        (base32
         "16js559vg13zz7rxsj4kz2l96gkly8kdk8wgj9jhrqwgdh7jq9iv"))))
    (arguments
     `(#:tests? #f ;no "check" target
       ,@(substitute-keyword-arguments `(#:modules ((guix build gnu-build-system)
                                                    (guix build utils)
                                                    (srfi srfi-1)
                                                    (srfi srfi-26))
                                         ,@(package-arguments samtools))
           ((#:make-flags flags)
            `(cons "LIBCURSES=-lncurses" ,flags))
           ((#:phases phases)
            `(modify-phases ,phases
               (delete 'patch-tests)
               (delete 'configure)
               (replace 'install
                 (lambda* (#:key outputs #:allow-other-keys)
                   (let ((bin (string-append
                               (assoc-ref outputs "out") "/bin")))
                     (mkdir-p bin)
                     (copy-file "samtools" (string-append bin "/samtools-" ,version)))
                   #t)))))))))

;; Fixed version of ParDRe for Harm.
(define-public pardre/fixed
  (package (inherit pardre)
    (name "pardre-fixed")
    (source (origin (inherit (package-source pardre))
                    (patches (search-patches "pardre-fix-utils.patch"))))))

;; This is needed for MEDICC
(define-public python2-biopython-1.62
  (package
    (inherit python2-biopython)
    (version "1.62")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "biopython" version))
              (sha256
               (base32
                "1gbq54l0nlqyjxxhq6nrqjfdx98x039akcxxrr5y3j7ccjw47wm2"))))))

(define-public infernal-1.0
  (package (inherit infernal)
    (version "1.0.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://eddylab.org/software/infernal/"
                                  "infernal-" version ".tar.gz"))
              (sha256
               (base32
                "1ba3av8xg4309dpy1ls73nxk2v7ri0yp0ix6ad5b1j35x319my64"))))
    (arguments
     ;; We need to disable tests because we don't seem to have
     ;; getopts.pl.
     `(#:tests? #f))))

(define-public bamtools-2.0
  (package (inherit bamtools)
    (version "2.0.5")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/pezmaster31/bamtools/"
                                  "archive/v" version ".tar.gz"))
              (sha256
               (base32
                "1s95gjhnlfd91mr692xp14gmirfwq55dsj1jir9fa06m1lk4iw1n"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  (delete-file-recursively "src/third_party/")
                  (substitute* "src/CMakeLists.txt"
                    (("add_subdirectory \\(third_party\\)") ""))
                  (substitute* "src/toolkit/bamtools_filter.cpp"
                    (("jsoncpp/json.h") "json/json.h"))
                  #t))))
    (arguments
     (substitute-keyword-arguments (package-arguments bamtools)
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after 'unpack 'add-install-target-for-utils-library
             (lambda* (#:key outputs #:allow-other-keys)
               (substitute* "src/utils/CMakeLists.txt"
                 (("target_link_libraries.*" line)
                  (string-append line "\ninstall(TARGETS BamTools-utils \
LIBRARY DESTINATION \"lib/bamtools\")")))
               #t))))))
    (inputs
     `(("jsoncpp" ,jsoncpp)
       ,@(package-inputs bamtools)))))

(define-public htslib-latest
  (package (inherit htslib)
    (version "1.5")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/samtools/htslib/releases/download/"
                    version "/htslib-" version ".tar.bz2"))
              (sha256
               (base32
                "0bcjmnbwp2bib1z1bkrp95w9v2syzdwdfqww10mkb1hxlmg52ax0"))))))

(define-public bcftools-latest
  (package (inherit bcftools)
    (version "1.5")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/samtools/bcftools/releases/download/"
                    version "/bcftools-" version ".tar.bz2"))
              (sha256
               (base32
                "0093hkkvxmbwfaa7905s6185jymynvg42kq6sxv7fili11l5mxwz"))
              (modules '((guix build utils)))
              (snippet
               ;; Delete bundled htslib.
               '(delete-file-recursively "htslib-1.5"))))
    (arguments
     `(#:test-target "test"
       #:configure-flags
       (list "--enable-libgsl"
             (string-append "--with-htslib="
                            (assoc-ref %build-inputs "htslib")))
       #:phases
       (modify-phases %standard-phases
         (add-before 'check 'patch-tests
           (lambda _
             (substitute* "test/test.pl"
               (("/bin/bash") (which "bash")))
             #t)))))
    (native-inputs
     `(("perl" ,perl)))
    (inputs
     `(("htslib" ,htslib-latest)
       ("gsl" ,gsl)
       ("zlib" ,zlib)))))

(define-public r-3.3.1
  (package (inherit r-minimal)
    (version "3.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://cran/src/base/R-"
                                  (version-prefix version 1) "/R-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "1qm9znh8akfy9fkzzi6f1vz2w1dd0chsr6qn7kw80lqzhgjrmi9x"))))))

(define-public r-3.3.2
  (package (inherit r-minimal)
    (version "3.3.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://cran/src/base/R-"
                                  (version-prefix version 1) "/R-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0k2i9qdd83g09fcpls2198q4ykxkii5skczb514gnx7mx4hsv56j"))))))

(define-public r-3.3.3
  (package (inherit r-minimal)
    (version "3.3.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://cran/src/base/R-"
                                  (version-prefix version 1) "/R-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0v7wpj89b0i3ad3fi1wak5c93hywmbxv8sdnixhq8l17782nidss"))))))

(define-public r-minimal-3.4.2
  (package (inherit r-minimal)
    (version "3.4.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://cran/src/base/R-"
                                  (version-prefix version 1) "/R-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0r0cv2kc3x5z9xycpnxx6fbvv22psw2m342jhpslbxkc8g1307lp"))))))

(define-public r-devel
  (package (inherit r-minimal)
    (name "r-devel")
    (version "2017-04-27_r72634")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://cran/src/base-prerelease/"
                                  "R-devel_" version ".tar.gz"))
              (sha256
               (base32
                "02x5dqps8v31djr38s4akq8q3hk6xf8x5knk5454awyvjipkry2j"))))))

(define-public r-methylkit-devel
  (let ((commit "46c8556f34eea9f068f2225e36adf11ba7ea6d07")
        (revision "1"))
    (package (inherit r-methylkit)
      (name "r-methylkit-devel")
      (version (string-append "1.3.3-" revision "." (string-take commit 9)))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/al2na/methylKit.git")
                      (commit commit)))
                (file-name (string-append name "-" version "-checkout"))
                (sha256
                 (base32
                  "061yx5lgm5c37v9asnvbl4wxay04791cbxs52ar16x0a0gd13p53")))))))

(define-public starlong
  (package (inherit star)
    (name "starlong")
    (arguments
     (substitute-keyword-arguments (package-arguments star)
       ((#:make-flags flags)
        `(list "STARlong"))
       ((#:phases phases)
        `(modify-phases ,phases
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((bin (string-append (assoc-ref outputs "out") "/bin/")))
                 (install-file "STARlong" bin))
               #t))))))))

(define-public starlong/ivano
  (package (inherit starlong)
    (name "starlong-ivano")
    (arguments
     (substitute-keyword-arguments (package-arguments starlong)
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after 'unpack 'make-extra-long
             (lambda _
               (substitute* "source/IncludeDefine.h"
                 (("(#define DEF_readNameLengthMax ).*" _ match)
                  (string-append match "900000\n")))))))))))

(define-public star-2.5.2
  (package (inherit star)
    (name "star")
    (version "2.5.2b")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/alexdobin/STAR.git")
                    (commit version)))
              (file-name (string-append name "-" version "-checkout"))
              (sha256
               (base32
                "0ipxr7mnc5ckanvis74ypfybd2ai0k12y6nai0mmmk4igfxd2zry"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  (substitute* "source/Makefile"
                    (("/bin/rm") "rm"))
                  ;; Remove pre-built binaries and bundled htslib sources.
                  (delete-file-recursively "bin/MacOSX_x86_64")
                  (delete-file-recursively "bin/Linux_x86_64")
                  (delete-file-recursively "bin/Linux_x86_64_static")
                  (delete-file-recursively "source/htslib")
                  #t))))))

(define-public jupyter-with-python2
  (package (inherit jupyter)
    (name "jupyter-python2")
    (build-system python-build-system)
    ;; FIXME: it's not clear how to run the tests.
    (arguments `(#:tests? #f
                 #:python ,python-2))
    (propagated-inputs
     `(("python-ipykernel" ,python2-ipykernel)
       ("python-ipywidgets" ,python2-ipywidgets)
       ("python-jupyter-console" ,python2-jupyter-console)
       ("python-nbconvert" ,python2-nbconvert)
       ("python-notebook" ,python2-notebook)
       ;; TODO: this should be propagated by tornado
       ("python-certifi" ,python2-certifi)))))

(define-public python2-cutadapt
  (package
    (name "python2-cutadapt")
    (version "1.12")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/marcelm/cutadapt/archive/v"
                    version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "19smhh6444ikn4jlmyhvffw4m5aw7yg07rqsk7arg8dkwyga1i4v"))))
    (build-system python-build-system)
    (arguments
     `(#:python ,python-2
       #:phases
       (modify-phases %standard-phases
         ;; The tests must be run after installation.
         (delete 'check)
         (add-after 'install 'check
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (setenv "PYTHONPATH"
                     (string-append
                      (getenv "PYTHONPATH")
                      ":" (assoc-ref outputs "out")
                      "/lib/python"
                      (string-take (string-take-right
                                    (assoc-ref inputs "python") 5) 3)
                      "/site-packages"))
             (zero? (system* "nosetests" "-P" "tests")))))))
    (propagated-inputs
     `(("python2-xopen" ,python2-xopen)))
    (native-inputs
     `(("python2-cython" ,python2-cython)
       ("python2-nose" ,python2-nose)))
    (home-page "https://cutadapt.readthedocs.io/en/stable/")
    (synopsis "Remove adapter sequences from nucleotide sequencing reads")
    (description
     "Cutadapt finds and removes adapter sequences, primers, poly-A tails and
other types of unwanted sequence from high-throughput sequencing reads.")
    (license license:expat)))

(define-public cmake-3.7.2
  (package (inherit cmake)
    (version "3.7.2")
    (source (origin
              (inherit (package-source cmake))
              (uri (string-append "https://www.cmake.org/files/v"
                                  (version-major+minor version)
                                  "/cmake-" version ".tar.gz"))
              (sha256
               (base32
                "1q6a60695prpzzsmczm2xrgxdb61fyjznb04dr6yls6iwv24c4nw"))))))
