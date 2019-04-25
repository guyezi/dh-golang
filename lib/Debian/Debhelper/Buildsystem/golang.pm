package Debian::Debhelper::Buildsystem::golang;

=head1 NAME

dh-golang -- debhelper build system class for Go packages

=head1 DESCRIPTION

The dh-golang package provides a build system for debhelper which can be used in
the following way:

 %:
 	dh $@ --buildsystem=golang --with=golang

=head1 IMPLEMENTATION

Here is a brief description of how the golang build system implements each
debhelper build system stage:

=over

=item B<configure>

Creates a Go workspace (see https://golang.org/doc/code.html#Workspaces) in the
build directory. Copies the source code into that workspace and symlinks all
available libraries from /usr/share/gocode/src into the workspace because the
go(1) tool requires write access to the workspace. See also
C<DH_GOLANG_INSTALL_EXTRA> and C<DH_GOLANG_INSTALL_ALL>.

=item B<build>

Determines build targets (see also C<DH_GOLANG_BUILDPKG> and
C<DH_GOLANG_EXCLUDES>), possibly calls C<go generate> (see also
C<DH_GOLANG_GO_GENERATE>), then calls C<go install>.

=item B<test>

Calls C<go test -v> on all build targets.

=item B<install>

Installs binaries and sources from the build directory into the Debian package
destdir. See also C<--no-source> and C<--no-binaries>.

=item B<clean>

Removes the build directory.

=back

=head1 OPTIONS

=over

=item B<dh_auto_install>

=over

=item B<--no-source>

By default, all files within the src/ subdirectory of the build directory will
be copied to /usr/share/gocode/src/ of the Debian package destdir. Specifying
the C<--no-source> option disables this behavior, which is useful if you are
packaging a program (as opposed to a library).

Example (in C<debian/rules>):

 override_dh_auto_install:
 	dh_auto_install -- --no-source

=item B<--no-binaries>

By default, all files within the bin/ subdirectory of the build directory will
be copied to /usr/bin/ of the Debian package destdir. Specifying the
C<--no-binaries> option disables this behavior.

Example (in C<debian/rules>):

 override_dh_auto_install:
 	dh_auto_install -- --no-binaries

Note: instead of using this option (which was added for symmetry with
C<--no-source>), consider not building unwanted binaries in the first place to
save CPU time on our build daemons; see C<DH_GOLANG_EXCLUDES>.

=back

=back

=head1 ENVIRONMENT VARIABLES

=over

=item C<DH_GOPKG>

C<DH_GOPKG> (string) contains the Go package name which this Debian package is
building.

C<DH_GOPKG> is automatically set to the value of the first import path of the
C<XS-Go-Import-Path> C<debian/control> field, which can contain several
comma-separated import paths.

Example (in C<debian/control>):

 XS-Go-Import-Path: github.com/go-mgo/mgo,
                    gopkg.in/mgo.v2,
                    labix.org/v2/mgo,
                    launchpad.net/mgo

C<DH_GOPKG> is set by dh-golang, and as a consequence it is not present in the
C<debian/rules> environment. If you need to use the Go package name in the
C<debian/rules> file, you must define it yourself.

Example (in C<debian/rules>):

 export DH_GOPKG := github.com/go-mgo/mgo

Historical note: before the C<XS-Go-Import-Path> field was introduced, we used
to set C<DH_GOPKG> in C<debian/rules>. When you encounter such a package, please
convert it by moving the value from C<debian/rules> to C<debian/control>. It is
preferable to use the C<debian/control> field because it is machine-readable and
picked up/used by various Debian infrastructure tools, whereas C<debian/rules> is
very hard to parse.

=item DH_GOLANG_INSTALL_EXTRA

C<DH_GOLANG_INSTALL_EXTRA> (list of strings, whitespace-separated, default
empty) enumerates files and directories which are additionally installed into
the build directory. By default, only files with the following extension are
installed: .go, .c, .cc, .cpp, .h, .hh, hpp, .proto, .s. Starting with dh-golang
1.31, testdata directory contents are installed by default.
Starting with dh-golang 1.39, go.mod and go.sum are installed by default
to support Go 1.11 modules.

Example (in C<debian/rules>):

 export DH_GOLANG_INSTALL_EXTRA := example.toml marshal_test.toml

=item DH_GOLANG_INSTALL_ALL

C<DH_GOLANG_INSTALL_ALL> (bool, default false) controls whether all files are
installed into the build directory. By default, only files with the following
extension are installed: .go, .c, .cc, .cpp, .h, .hh, .hpp, .proto, .s. Starting
with dh-golang 1.31, testdata directory contents are installed by default.
Starting with dh-golang 1.39, go.mod and go.sum are installed by default
to support Go 1.11 modules.

Example (in C<debian/rules>):

 export DH_GOLANG_INSTALL_ALL := 1

Note: prefer the C<DH_GOLANG_INSTALL_EXTRA> environment variable because it is
self-documenting and future-proof: when using C<DH_GOLANG_INSTALL_ALL>, readers
of your package cannot easily tell which extra files in particular need to be
installed, and newer upstream versions might result in unexpected extra files.

=item DH_GOLANG_BUILDPKG

C<DH_GOLANG_BUILDPKG> (list of strings, whitespace-separated, default
C<${DH_GOPKG}/...>) defines the build targets for compiling this Go package. In
other words, this is what will be passed to C<go install>.

The default value matches all Go packages within the source, which is usually
desired, but you might need to exclude example programs, for which you should
use the C<DH_GOLANG_EXCLUDES> environment variable.

Example (in C<debian/rules>):

 # Install only programs for end users, the also-included Go packages are not
 # yet mature enough to be shipped for other packages to consume (despite what
 # upstream claims).
 export DH_GOLANG_BUILDPKG := github.com/debian/ratt/cmd/...

=item DH_GOLANG_EXCLUDES

C<DH_GOLANG_EXCLUDES> (list of Perl regular expressions, whitespace-separated,
default empty) defines regular expression patterns to exclude from the build
targets expanded from C<DH_GOLANG_BUILDPKG>.

Please note that with DH_COMPAT level inferior or equal to 11, the default is
to only exclude pattern from the build target.  (see C<DH_GOLANG_EXCLUDES_ALL>
below)

Example (in C<debian/rules>):

 # We want to build only the library packages themselves, not the accompanying
 # example binaries.
 export DH_GOLANG_EXCLUDES := examples/

=item DH_GOLANG_EXCLUDES_ALL

C<DH_GOLANG_EXCLUDES_ALL> (boolean, default to true starting from DH_COMPAT
level 12) makes C<DH_GOLANG_EXCLUDE> excludes files not only during the
building process but also for install.  This is useful, if, for instance,
examples are installed with C<dh_installexamples>. If you only want to
exclude files from the building process but keep them in the source, set this
to false.
Example (in C<debian/rules>):

 # We want to ship only the library packages themselves in the go source, not
 # the accompanying example binaries.
 export DH_GOLANG_EXCLUDES := examples/
 export DH_GOLANG_EXCLUDES_ALL := 1

=item DH_GOLANG_GO_GENERATE

C<DH_GOLANG_GO_GENERATE> (bool, default false) controls whether C<go generate>
is called on all build targets (see C<DH_GOLANG_BUILDPKG>).

It is convention in the Go community to commit all C<go generate> artifacts to
version control, so re-generating these artifacts is usually not required.

Depending on what the Go package in question uses C<go generate> for, you may
want to enable C<DH_GOLANG_GO_GENERATE>:

=over

=item *

If the Go package uses C<go generate> to generate artifacts purely from inputs
within its own source (e.g. creating a perfect hash table), there usually is no
need to re-generate that output. It does not necessarily hurt, either, but some
C<go generate> commands might be poorly tested and break the build.

=item *

If the Go package uses C<go generate> to (e.g.) bundle a JavaScript library into
a template file which is then compiled into a Go program, it is advisable to
re-generate that output so that the Debian version of the JavaScript library is
picked up, as opposed to the pre-generated version.

=back

Example (in C<debian/rules>):

 export DH_GOLANG_GO_GENERATE := 1

Note: this option should default to true, but it was introduced after dh-golang
was already widely used, and nobody made the transition happen yet (i.e. inspect
and possibly fix any resulting breakages).

=back

=cut

use strict;
use base 'Debian::Debhelper::Buildsystem';
use Debian::Debhelper::Dh_Lib;
use Dpkg::Control::Info;
use File::Copy "cp"; # in core since 5.002
use File::Path qw(make_path); # in core since 5.001
use File::Find; # in core since 5
use File::Spec; # in core since 5.00405

sub DESCRIPTION {
    "Go"
}

sub check_auto_buildable {
    return 0
}

sub new {
    my $class = shift;
    my $this = $class->SUPER::new(@_);
    $this->prefer_out_of_source_building();
    _set_dh_gopkg();
    return $this;
}

sub _set_dh_gopkg {
    # If DH_GOPKG is missing, try to set it from the XS-Go-Import-Path field
    # from debian/control. If this approach works well, we will only use this
    # method in the future.
    return if defined($ENV{DH_GOPKG}) && $ENV{DH_GOPKG} ne '';

    my $control = Dpkg::Control::Info->new();
    my $source = $control->get_source();
    # XS-Go-Import-Path can contain several paths. We use the first one.
    # Example: XS-Go-Import-Path: github.com/go-mgo/mgo,
    #                             gopkg.in/mgo.v2,
    #                             labix.org/v2/mgo,
    #                             launchpad.net/mgo
    $ENV{DH_GOPKG} = (split ",", $source->{"XS-Go-Import-Path"})[0];
}

sub _set_gopath {
    my $this = shift;
    $ENV{GOPATH} = $this->{cwd} . '/' . $this->get_builddir();
}

sub _set_gocache {
    # Honor the user’s wishes if GOCACHE was explicitly set, e.g. for speeding
    # up builds/tests during local package development.
    return if defined($ENV{GOCACHE}) && $ENV{GOCACHE} ne '';

    # Explicitly setting the cache to off suppresses an error message when
    # building with sbuild, where the default cache location is not writeable.
    $ENV{GOCACHE} = "off";
}

sub _set_go111module {
    # Honor the user’s wishes if GO111MODULE was explicitly set.
    return if defined($ENV{GO111MODULE}) && $ENV{GO111MODULE} ne '';

    # Operate in "GOPATH mode" by default for "minimal module compatibility",
    # otherwise Go >= 1.11 would attempt to check module information on-line.
    # See https://github.com/golang/go/wiki/Modules
    $ENV{GO111MODULE} = "off";
}

sub _link_contents {
    my ($src, $dst) = @_;

    my @contents = glob "$src/*";
    # Safety-Check: We are already _in_ a Go library. Don’t copy its
    # subfolders, this has no use and potentially only screws things up.
    # This situation should never happen, unless some package ships files that
    # are already shipped in another package.
    my @gosrc = grep { /\.go$/ } @contents;
    return if @gosrc > 0;
    my @dirs = grep { -d } @contents;
    for my $dir (@dirs) {
        my $base = basename($dir);
        if (-d "$dst/$base") {
            if ( 0 <= index($dir, q{/usr/share/gocode/src/}.$ENV{DH_GOPKG}) ){
                warning( qq{"$ENV{DH_GOPKG}" is already installed. Please check for circular dependencies.\n} );
            }else{
                _link_contents("$src/$base", "$dst/$base");
            }
        } else {
            verbose_print("Symlink $src/$base -> $dst/$base");
            symlink("$src/$base", "$dst/$base");
        }
    }
}

sub configure {
    my $this = shift;

    $this->mkdir_builddir();

    my $builddir = $this->get_builddir();

    ############################################################################
    # Copy all source files into the build directory $builddir/src/$go_package
    ############################################################################

    my $install_all = (exists($ENV{DH_GOLANG_INSTALL_ALL}) &&
                       $ENV{DH_GOLANG_INSTALL_ALL} == 1);

    # By default, only files with the following extensions are installed:
    my %whitelisted_exts = (
        '.go' => 1,
        '.c' => 1,
        '.cc' => 1,
        '.cpp' => 1,
        '.h' => 1,
        '.hh' => 1,
        '.hpp' => 1,
        '.proto' => 1,
        '.s' => 1,
    );

    my @sourcefiles;
    find({
        # Ignores ./debian entirely, but not e.g. foo/debian/debian.go
        # Ignores ./.pc (quilt) entirely.
        # Also ignores the build directory to avoid recursive copies.
        preprocess => sub {
            return @_ if $File::Find::dir ne '.';
            return grep {
                $_ ne 'debian' &&
                $_ ne '.pc' &&
                $_ ne '.git' &&
                $_ ne $builddir
            } @_;
        },
        wanted => sub {
            # Strip “./” in the beginning of the path.
            my $name = substr($File::Find::name, 2);
            if ($install_all) {
                # All files will be installed
            } elsif ((grep { $_ eq "testdata" } File::Spec->splitdir($File::Find::dir)) > 0) {
                # The go tool treats testdata directories as special,
                # so install their contents by default.
            } elsif ($name eq 'go.mod' or $name eq 'go.sum') {
                # The go.mod file is mandatory for Go programs which require
                # v2+ modules.  See https://github.com/golang/go/wiki/Modules
            } else {
                my $dot = rindex($name, ".");
                return if $dot == -1;
                return unless $whitelisted_exts{substr($name, $dot)};
            }
            return unless -e $name;
            push @sourcefiles, $name;
        },
        no_chdir => 1,
    }, '.');

    # Extra files/directories to install.
    my @install_extra = (exists($ENV{DH_GOLANG_INSTALL_EXTRA}) ?
                         split(/ /, $ENV{DH_GOLANG_INSTALL_EXTRA}) : ());

    find({
        wanted => sub {
            return unless -f $File::Find::name;
            push @sourcefiles, $File::Find::name;
        },
        no_chdir => 1,
    }, @install_extra) if(@install_extra);

    for my $source (@sourcefiles) {
        my $dest = "$builddir/src/$ENV{DH_GOPKG}/$source";
        # Avoid re-copying the files, this would update their timestamp and
        # make go(1) recompile them.
        next if -e $dest;

        if (-l $source) {
            make_path(dirname($dest));
            verbose_print("Symlink $dest");
            symlink(readlink($source), $dest) or error("Could not symlink $dest: $!");
            next;
        }

        if (-d $source) {
            make_path($dest);
            next;
        }

        make_path(dirname($dest));
        verbose_print("Copy $source -> $dest");
        cp($source, $dest) or error("Could not copy $source to $dest: $!");
    }

    ############################################################################
    # Symlink all available libraries from /usr/share/gocode/src into our
    # buildroot.
    ############################################################################

    # NB: The naïve idea of just setting GOPATH=$builddir:/usr/share/godoc does
    # not work. Let’s call the two paths in $GOPATH components. go(1), when
    # installing a package, such as github.com/Debian/dcs/cmd/..., will also
    # install the compiled dependencies, e.g. github.com/mstap/godebiancontrol.
    # When such a dependency is found in a component’s src/ directory, the
    # resulting files will be stored in the same component’s pkg/ directory.
    # That is, in this example, go(1) wants to modify
    # /usr/share/gocode/pkg/linux_amd64/github.com/mstap/godebiancontrol, which
    # will obviously not succeed due to permission errors.
    #
    # Therefore, we just work with a single component that is under our control
    # and symlink all the sources into that component ($builddir).

    _link_contents('/usr/share/gocode/src', "$builddir/src");
}

sub get_targets {
    my $buildpkg = $ENV{DH_GOLANG_BUILDPKG} || "$ENV{DH_GOPKG}/...";
    my $output = qx(go list $buildpkg);
    my @excludes = (exists($ENV{DH_GOLANG_EXCLUDES}) ?
                    split(/ /, $ENV{DH_GOLANG_EXCLUDES}) : ());
    my @targets = split(/\n/, $output);

    # Remove all targets that are matched by one of the regular expressions in DH_GOLANG_EXCLUDES.
    for my $pattern (@excludes) {
        @targets = grep { !/$pattern/ } @targets;
    }

    return @targets;
}

sub build {
    my $this = shift;

    $this->_set_gopath();
    $this->_set_gocache();
    $this->_set_go111module();
    if (exists($ENV{DH_GOLANG_GO_GENERATE}) && $ENV{DH_GOLANG_GO_GENERATE} == 1) {
        $this->doit_in_builddir("go", "generate", "-v", @_, get_targets());
    }
    unshift @_, ('-p', $this->get_parallel());
    # Go 1.10 changed flag behaviour, -{gc,asm}flags=all= only works for Go >= 1.10.
    my $trimpath = "all=\"-trimpath=" . $ENV{GOPATH} . "/src\"";
    $this->doit_in_builddir("go", "install", "-gcflags=$trimpath", "-asmflags=$trimpath", "-v", @_, get_targets());
}

sub test {
    my $this = shift;

    $this->_set_gopath();
    $this->_set_gocache();
    $this->_set_go111module();
    unshift @_, ('-p', $this->get_parallel());
    # Go 1.10 started calling “go vet” when running “go test”. This breaks tests
    # of many not-yet-fixed upstream packages, so we disable it for the time
    # being.
    my ($minor) = (qx(go version) =~ /go version go1\.([0-9]+)/);
    if ($minor >= 10) {
        $this->doit_in_builddir("go", "test", "-vet=off", "-v", @_, get_targets());
    } else {
        # For backwards-compatibility with Go < 1.10, which incorrectly
        # interprets the -vet=off flag as a target:
        $this->doit_in_builddir("go", "test", "-v", @_, get_targets());
    }
}

sub install {
    my $this = shift;
    my $destdir = shift;
    my $builddir = $this->get_builddir();
    my $install_source = 1;
    my $install_binaries = 1;

    while(@_) {
        if($_[0] eq '--no-source') {
            $install_source = 0;
            shift;
        } elsif($_[0] eq '--no-binaries') {
            $install_binaries = 0;
            shift;
        } else {
            error("Unknown option $_[0]");
        }
    }

    my @binaries = glob "$builddir/bin/*";
    if ($install_binaries and @binaries > 0) {
        $this->doit_in_builddir('mkdir', '-p', "$destdir/usr");
        $this->doit_in_builddir('cp', '-r', 'bin', "$destdir/usr");
    }

    if ($install_source) {
        # Path to the src/ directory within $destdir
        my $dest_src = "$destdir/usr/share/gocode/src/$ENV{DH_GOPKG}";

        # starting from compat level 12, exclude_all defaults to True
        my $exclude_all_default = (compat(11) ?
                                0 : 1);

        my $exclude_all = (exists($ENV{DH_GOLANG_EXCLUDES_ALL}) ?
                            $ENV{DH_GOLANG_EXCLUDES_ALL} : $exclude_all_default);

        my @excludes = (exists($ENV{DH_GOLANG_EXCLUDES}) && $exclude_all ?
                        split(/ /, $ENV{DH_GOLANG_EXCLUDES}) : ());

        find({
            wanted => sub {
                my $source = $File::Find::name;
                my $source_rel = File::Spec-> abs2rel($source, "$builddir/src/$ENV{DH_GOPKG}");

                for my $pattern (@excludes) {
                    if ($source_rel =~ /$pattern/) {
                        verbose_print("$source_rel matches $pattern from DH_GOLANG_EXCLUDES, skipping\n");
                        return;
                    }
                }

                my $dest = "$dest_src/$source_rel";
                my $destdir = dirname($dest);

                return if (-e $dest);
                return if (-d $source);
                make_path($destdir) unless (-d $destdir);

                # it's very unlikely there are symlinks. But just in case...
                if (-l $source) {
                    my $link_target = readlink($source);
                    verbose_print("Create symlink $dest -> $link_target");
                    symlink($link_target, $dest) or error("Could not create symlink $dest -> $link_target: $!");
                    return
                }

                verbose_print("Copy $source -> $dest");
                cp($source, $dest) or error("Could not copy $source to $dest: $!");

                },
            no_chdir => 1,
            }, "$builddir/src/$ENV{DH_GOPKG}");
    }
}

sub clean {
    my $this = shift;

    $this->rmdir_builddir();
}

1
# vim:ts=4:sw=4:expandtab
