use 5.008;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

# minimum required version of dependancies we need to build
our %build_reqs = ( 'libtiff' => '4.0.3', );

# minimum required version of dependancies we need to run
our %runtime_reqs = ( 'libtiff' => '4.0.3', );

# Can't assume ExtUtils::PkgConfig will return anything useful until
# the pkg-config files ship with libtiff.
my $lib = '-ltiff';
my $inc = '-I. ';
if (
    eval {
        %pkgcfg =
          ExtUtils::PkgConfig->find( 'libtiff >= ' . $build_reqs{libtiff} );
    }
  )
{
    $lib = $pkgcfg{libs};
    $inc .= $pkgcfg{cflags};
    $runtime_reqs{libtiff} = $pkgcfg{modversion};
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Graphics::TIFF',
    VERSION_FROM => 'lib/Graphics/TIFF.pm',    # finds $VERSION
    PREREQ_PM    => {},                        # e.g., Module::Name => 1.1
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM =>
              'lib/Graphics/TIFF.pm',    # retrieve abstract from module
            AUTHOR => 'Jeffrey Ratcliffe'
          )
        : ()
    ),
    LIBS   => [$lib],   # e.g., '-lm'
    DEFINE => '',       # e.g., '-DHAVE_SOMETHING'
    INC    => $inc,     # e.g., '-I. -I/usr/include/other'
                        # Un-comment this if you add C files to link with later:
         # OBJECT            => '$(O_FILES)', # link all the C files too
);

sub MY::postamble {
    my $postamble = <<'END';
SHELL = bash
DEB_BUILD_ROOT = /var/tmp/$(NAME)-$(VERSION)
MANIFEST = $(shell cat MANIFEST)
SOURCE = $(filter bin/% examples/% %.pm %.PL %.pl %.t,$(MANIFEST))
SOURCE_TIDY = $(foreach file,$(SOURCE),$(file).tdy)

debdist : tardist
	$(RM_RF) /tmp/$(NAME)
	$(MKPATH) /tmp/$(NAME)
	cp $(NAME)-$(VERSION).tar.xz /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.xz
	cd /tmp/$(NAME) && tar xvfJ $(NAME)_$(VERSION).orig.tar.xz
	cd /tmp/$(NAME)/$(NAME)-$(VERSION) && debuild
	$(CP) /tmp/$(NAME)/$(NAME)_$(VERSION)*_all.deb \
              /tmp/$(NAME)/$(NAME)_$(VERSION)*.dsc \
              /tmp/$(NAME)/$(NAME)_$(VERSION).orig.tar.xz .

MANIFEST : $(SOURCE)
	git ls-files | egrep -v '^\.(git|be)' > $@

tidy : MANIFEST $(SOURCE_TIDY)

%.tdy : %
	perltidy $* && if ! diff -q $@ $* > /dev/null; then cp $@ $*; fi
END
    $postamble;
}
